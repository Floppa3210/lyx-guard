--[[
    LyxGuard - Anti-Teleport Protection
    Detects players teleporting abnormal distances
    Based on FIREAC detection logic
]]

local Protection = {}
Protection.Name = "Anti-Teleport"
Protection.Enabled = true

-- Local references
local PlayerPedId = PlayerPedId
local GetEntityCoords = GetEntityCoords
local IsPedInAnyVehicle = IsPedInAnyVehicle
local IsEntityDead = IsEntityDead
local GetGameTimer = GetGameTimer
local GetVehicleClass = GetVehicleClass
local GetVehiclePedIsIn = GetVehiclePedIsIn

-- Configuration
local MAX_FOOT_DISTANCE = 150.0 -- Max distance on foot per check
local MAX_VEHICLE_DISTANCE = 400.0 -- Max distance in vehicle per check
local MAX_AIRCRAFT_DISTANCE = 800.0 -- Max distance in aircraft
local CHECK_INTERVAL = 1000 -- ms
local VIOLATION_THRESHOLD = 2
local GRACE_PERIOD = 5000 -- Grace period after spawn/respawn

local lastCheck = 0
local lastCoords = nil
local violations = 0
local spawnTime = 0
local lastViolationTime = 0

-- Callback
Protection.OnDetection = nil

-- Aircraft vehicle classes
local AIRCRAFT_CLASSES = {
    [15] = true, -- Helicopters
    [16] = true, -- Planes
}

-- Calculate 3D distance
local function GetDistance(c1, c2)
    if not c1 or not c2 then return 0 end
    local dx = c1.x - c2.x
    local dy = c1.y - c2.y
    local dz = c1.z - c2.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- Check for teleport
local function CheckTeleport()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    
    if IsEntityDead(ped) then
        lastCoords = nil
        violations = 0
        return false
    end
    
    local currentCoords = GetEntityCoords(ped)
    local now = GetGameTimer()
    
    -- Grace period after spawn
    if now - spawnTime < GRACE_PERIOD then
        lastCoords = currentCoords
        return false
    end
    
    if not lastCoords then
        lastCoords = currentCoords
        return false
    end
    
    local distance = GetDistance(currentCoords, lastCoords)
    local maxAllowed = MAX_FOOT_DISTANCE
    
    -- Adjust for vehicle type
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        local vehicleClass = GetVehicleClass(vehicle)
        
        if AIRCRAFT_CLASSES[vehicleClass] then
            maxAllowed = MAX_AIRCRAFT_DISTANCE
        else
            maxAllowed = MAX_VEHICLE_DISTANCE
        end
    end
    
    -- Check if distance exceeds maximum
    if distance > maxAllowed then
        violations = violations + 1
        lastViolationTime = now
        
        if violations >= VIOLATION_THRESHOLD then
            if Protection.OnDetection then
                Protection.OnDetection(
                    "Anti-Teleport",
                    ("Teleported %.1f units (max allowed: %.1f)"):format(distance, maxAllowed),
                    "BAN"
                )
            end
            violations = 0
            return true
        end
    else
        -- Decrease violations over time if behaving normally
        if distance < maxAllowed / 4 then
            violations = math.max(0, violations - 0.5)
        end
    end
    
    lastCoords = currentCoords
    return false
end

-- Called on player spawn
function Protection.OnSpawn()
    spawnTime = GetGameTimer()
    lastCoords = nil
    violations = 0
end

-- Main loop
function Protection.Run()
    if not Protection.Enabled then return end
    
    local now = GetGameTimer()
    if now - lastCheck < CHECK_INTERVAL then return end
    lastCheck = now
    
    if now - lastViolationTime > 60000 then
        violations = 0
    end
    
    CheckTeleport()
end

-- Initialize
function Protection.Init(config)
    if config and config.AntiTeleport then
        Protection.Enabled = config.AntiTeleport.enabled ~= false
        if config.AntiTeleport.maxFootDistance then
            MAX_FOOT_DISTANCE = config.AntiTeleport.maxFootDistance
        end
        if config.AntiTeleport.maxVehicleDistance then
            MAX_VEHICLE_DISTANCE = config.AntiTeleport.maxVehicleDistance
        end
    end
    
    spawnTime = GetGameTimer()
    print('^2[LyxGuard]^7 Anti-Teleport protection initialized')
end

-- Self-register with protection system
CreateThread(function()
    Wait(100)
    
    if RegisterProtectionModule then
        RegisterProtectionModule('anti_teleport', Protection)
    elseif exports['lyx-guard'] and exports['lyx-guard'].RegisterProtection then
        exports['lyx-guard']:RegisterProtection('anti_teleport', Protection)
    end
end)

return Protection
