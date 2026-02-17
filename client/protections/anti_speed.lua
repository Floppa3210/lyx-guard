--[[
    LyxGuard - Anti-Speed Hack Protection
    Detects players moving faster than possible
    Based on FIREAC detection logic
]]

local Protection = {}
Protection.Name = "Anti-SpeedHack"
Protection.Enabled = true

-- Local references
local PlayerPedId = PlayerPedId
local GetEntitySpeed = GetEntitySpeed
local GetEntityCoords = GetEntityCoords
local IsPedInAnyVehicle = IsPedInAnyVehicle
local IsEntityDead = IsEntityDead
local GetGameTimer = GetGameTimer
local GetVehiclePedIsIn = GetVehiclePedIsIn
local GetVehicleClass = GetVehicleClass
local IsPedFalling = IsPedFalling
local IsPedRagdoll = IsPedRagdoll

-- Configuration (speeds in m/s, GTA uses m/s)
local MAX_FOOT_SPEED = 12.0 -- ~43 km/h (sprint speed is ~8 m/s)
local MAX_VEHICLE_SPEED = 100.0 -- ~360 km/h
local MAX_SUPER_SPEED = 140.0 -- ~504 km/h for supercars
local MAX_AIRCRAFT_SPEED = 200.0 -- ~720 km/h
local CHECK_INTERVAL = 200 -- ms
local VIOLATION_THRESHOLD = 5
local SPEED_HISTORY_SIZE = 10

local lastCheck = 0
local violations = 0
local speedHistory = {}
local lastViolationTime = 0

-- Callback
Protection.OnDetection = nil

-- Vehicle classes for speed limits
local SUPERCAR_CLASSES = {
    [7] = true, -- Super
    [6] = true, -- Sports
}

local AIRCRAFT_CLASSES = {
    [15] = true, -- Helicopters
    [16] = true, -- Planes
}

-- Get average speed from history
local function GetAverageSpeed()
    if #speedHistory == 0 then return 0 end
    local sum = 0
    for _, speed in ipairs(speedHistory) do
        sum = sum + speed
    end
    return sum / #speedHistory
end

-- Add speed to history
local function AddSpeedToHistory(speed)
    table.insert(speedHistory, speed)
    if #speedHistory > SPEED_HISTORY_SIZE then
        table.remove(speedHistory, 1)
    end
end

-- Check for speed hack
local function CheckSpeed()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    
    if IsEntityDead(ped) then
        violations = 0
        speedHistory = {}
        return false
    end
    
    -- Skip check if falling or ragdoll
    if IsPedFalling(ped) or IsPedRagdoll(ped) then
        return false
    end
    
    local speed = GetEntitySpeed(ped)
    AddSpeedToHistory(speed)
    
    local maxAllowed = MAX_FOOT_SPEED
    
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        local vehicleClass = GetVehicleClass(vehicle)
        
        if AIRCRAFT_CLASSES[vehicleClass] then
            maxAllowed = MAX_AIRCRAFT_SPEED
        elseif SUPERCAR_CLASSES[vehicleClass] then
            maxAllowed = MAX_SUPER_SPEED
        else
            maxAllowed = MAX_VEHICLE_SPEED
        end
    end
    
    -- Check if speed exceeds maximum
    if speed > maxAllowed then
        violations = violations + 1
        lastViolationTime = GetGameTimer()
        
        if violations >= VIOLATION_THRESHOLD then
            local avgSpeed = GetAverageSpeed()
            if Protection.OnDetection then
                Protection.OnDetection(
                    "Anti-SpeedHack",
                    ("Speed: %.1f m/s (%.1f km/h), max allowed: %.1f m/s, avg: %.1f"):format(
                        speed, speed * 3.6, maxAllowed, avgSpeed
                    ),
                    "KICK"
                )
            end
            violations = 0
            speedHistory = {}
            return true
        end
    else
        violations = math.max(0, violations - 1)
    end
    
    return false
end

-- Main loop
function Protection.Run()
    if not Protection.Enabled then return end
    
    local now = GetGameTimer()
    if now - lastCheck < CHECK_INTERVAL then return end
    lastCheck = now
    
    if now - lastViolationTime > 30000 then
        violations = 0
    end
    
    CheckSpeed()
end

-- Initialize
function Protection.Init(config)
    if config and config.AntiSpeedHack then
        Protection.Enabled = config.AntiSpeedHack.enabled ~= false
    end
    
    print('^2[LyxGuard]^7 Anti-SpeedHack protection initialized')
end

-- Self-register
CreateThread(function()
    Wait(100)
    if exports['lyx-guard'] and exports['lyx-guard'].RegisterProtection then
        exports['lyx-guard']:RegisterProtection('anti_speed', Protection)
    end
end)

return Protection
