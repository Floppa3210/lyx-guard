--[[
    LyxGuard - Anti-Noclip Protection
    Detects players flying through walls/ground
    Based on SecureServe + FIREAC detection logic
]]

local Protection = {}
Protection.Name = "Anti-Noclip"
Protection.Enabled = true

-- Local references
local PlayerPedId = PlayerPedId
local GetEntityCoords = GetEntityCoords
local GetEntityHeightAboveGround = GetEntityHeightAboveGround
local IsPedInAnyVehicle = IsPedInAnyVehicle
local IsEntityDead = IsEntityDead
local GetGameTimer = GetGameTimer
local IsPedFalling = IsPedFalling
local IsPedRagdoll = IsPedRagdoll
local IsPedJumping = IsPedJumping
local IsPedClimbing = IsPedClimbing
local IsPedSwimming = IsPedSwimming
local IsPedSwimmingUnderWater = IsPedSwimmingUnderWater
local IsEntityInAir = IsEntityInAir
local GetVehiclePedIsIn = GetVehiclePedIsIn
local GetVehicleClass = GetVehicleClass
local HasEntityCollidedWithAnything = HasEntityCollidedWithAnything

-- Configuration
local CHECK_INTERVAL = 500 -- ms
local MAX_HEIGHT_ABOVE_GROUND = 10.0 -- Max height on foot without vehicle
local MAX_UNDERGROUND_DEPTH = -5.0 -- Min Z coord below ground
local VIOLATION_THRESHOLD = 5
local lastCheck = 0
local violations = 0
local lastCoords = nil
local lastViolationTime = 0

-- Callback
Protection.OnDetection = nil

-- Aircraft classes
local AIRCRAFT_CLASSES = {
    [15] = true, -- Helicopters
    [16] = true, -- Planes
}

-- Check for noclip behavior
local function CheckNoclip()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    
    if IsEntityDead(ped) then
        violations = 0
        return false
    end
    
    local coords = GetEntityCoords(ped)
    local heightAboveGround = GetEntityHeightAboveGround(ped)
    
    -- Skip if in valid flying state
    if IsPedFalling(ped) or IsPedRagdoll(ped) or IsPedJumping(ped) or 
       IsPedClimbing(ped) or IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) then
        return false
    end
    
    -- Skip if in aircraft
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        local vehicleClass = GetVehicleClass(vehicle)
        if AIRCRAFT_CLASSES[vehicleClass] then
            return false
        end
    end
    
    -- Check 1: Player floating in air on foot (not in vehicle)
    if not IsPedInAnyVehicle(ped, false) and not IsEntityInAir(ped) then
        if heightAboveGround > MAX_HEIGHT_ABOVE_GROUND then
            violations = violations + 1
            lastViolationTime = GetGameTimer()
            
            if violations >= VIOLATION_THRESHOLD then
                if Protection.OnDetection then
                    Protection.OnDetection(
                        "Anti-Noclip",
                        ("Floating in air: %.1f meters above ground"):format(heightAboveGround),
                        "KICK"
                    )
                end
                violations = 0
                return true
            end
        end
    end
    
    -- Check 2: Player underground
    if coords.z < MAX_UNDERGROUND_DEPTH and not IsPedSwimmingUnderWater(ped) then
        violations = violations + 1
        lastViolationTime = GetGameTimer()
        
        if violations >= VIOLATION_THRESHOLD then
            if Protection.OnDetection then
                Protection.OnDetection(
                    "Anti-Noclip",
                    ("Underground detected: Z=%.1f"):format(coords.z),
                    "KICK"
                )
            end
            violations = 0
            return true
        end
    end
    
    -- Check 3: Rapid position changes through solid objects
    if lastCoords then
        local dx = coords.x - lastCoords.x
        local dy = coords.y - lastCoords.y
        local dz = coords.z - lastCoords.z
        local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
        
        -- If moved significant distance and collided with something
        if distance > 5.0 and HasEntityCollidedWithAnything(ped) then
            violations = violations + 0.5
        end
    end
    
    -- Decrease violations if behaving normally
    if heightAboveGround < 2.0 and coords.z > 0 then
        violations = math.max(0, violations - 0.2)
    end
    
    lastCoords = coords
    return false
end

-- Main loop
function Protection.Run()
    if not Protection.Enabled then return end
    
    local now = GetGameTimer()
    if now - lastCheck < CHECK_INTERVAL then return end
    lastCheck = now
    
    -- Reset violations after 30 seconds
    if now - lastViolationTime > 30000 then
        violations = 0
    end
    
    CheckNoclip()
end

-- Initialize
function Protection.Init(config)
    if config and config.AntiNoclip then
        Protection.Enabled = config.AntiNoclip.enabled ~= false
        if config.AntiNoclip.maxHeight then
            MAX_HEIGHT_ABOVE_GROUND = config.AntiNoclip.maxHeight
        end
    end
    
    print('^2[LyxGuard]^7 Anti-Noclip protection initialized')
end

-- Self-register
CreateThread(function()
    Wait(100)
    if exports['lyx-guard'] and exports['lyx-guard'].RegisterProtection then
        exports['lyx-guard']:RegisterProtection('anti_noclip', Protection)
    end
end)

return Protection
