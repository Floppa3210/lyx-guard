--[[
    LyxGuard - Anti-Aimbot Protection
    Detects players with unnatural aiming patterns
    Based on Icarus AimbotModule
]]

local Protection = {}
Protection.Name = "Anti-Aimbot"
Protection.Enabled = true

-- Local references
local PlayerPedId = PlayerPedId
local GetEntityCoords = GetEntityCoords
local GetEntityForwardVector = GetEntityForwardVector
local GetGameTimer = GetGameTimer
local IsPlayerFreeAiming = IsPlayerFreeAiming
local GetPlayerTargetEntity = GetPlayerTargetEntity
local PlayerId = PlayerId

-- Configuration
local OFFSET_DISTANCE = 7.0 -- Max angle offset tolerance
local CHECK_INTERVAL = 100 -- ms
local VIOLATION_THRESHOLD = 10 -- Consecutive violations before flag
local lastCheck = 0
local violations = 0
local aimHistory = {}
local HISTORY_SIZE = 20

-- Callback
Protection.OnDetection = nil

-- Calculate angle between two vectors
local function VectorAngle(v1, v2)
    local dot = v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
    local len1 = math.sqrt(v1.x^2 + v1.y^2 + v1.z^2)
    local len2 = math.sqrt(v2.x^2 + v2.y^2 + v2.z^2)
    
    if len1 == 0 or len2 == 0 then return 0 end
    
    local cosAngle = dot / (len1 * len2)
    cosAngle = math.max(-1, math.min(1, cosAngle))
    
    return math.deg(math.acos(cosAngle))
end

-- Calculate aim variance
local function CalculateAimVariance()
    if #aimHistory < 5 then return 100 end -- Not enough data
    
    local sum = 0
    local prevDir = aimHistory[1]
    
    for i = 2, #aimHistory do
        local angle = VectorAngle(prevDir, aimHistory[i])
        sum = sum + angle
        prevDir = aimHistory[i]
    end
    
    return sum / (#aimHistory - 1)
end

-- Check for aimbot patterns
local function CheckAimbot()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    
    local playerId = PlayerId()
    
    -- Only check when player is aiming
    if not IsPlayerFreeAiming(playerId) then
        -- Reset when not aiming
        aimHistory = {}
        violations = 0
        return false
    end
    
    -- Get current aim direction
    local forwardVector = GetEntityForwardVector(ped)
    
    -- Add to history
    table.insert(aimHistory, forwardVector)
    if #aimHistory > HISTORY_SIZE then
        table.remove(aimHistory, 1)
    end
    
    local hasTarget, targetEntity = GetPlayerTargetEntity(playerId)
    
    if hasTarget and targetEntity and targetEntity ~= 0 then
        local pedCoords = GetEntityCoords(ped)
        local targetCoords = GetEntityCoords(targetEntity)
        
        -- Direction to target
        local dirToTarget = {
            x = targetCoords.x - pedCoords.x,
            y = targetCoords.y - pedCoords.y,
            z = targetCoords.z - pedCoords.z
        }
        
        -- Angle between where player is looking and target
        local angle = VectorAngle(forwardVector, dirToTarget)
        
        -- Check if aiming with unnatural precision
        if angle < 1.0 then -- Almost perfect aim
            local variance = CalculateAimVariance()
            
            -- Very low variance + perfect aim = suspicious
            if variance < 2.0 then
                violations = violations + 1
                
                if violations >= VIOLATION_THRESHOLD then
                    if Protection.OnDetection then
                        Protection.OnDetection(
                            "Anti-Aimbot",
                            ("Suspicious aim pattern: variance=%.2f, angle=%.2f"):format(variance, angle),
                            "WARN"
                        )
                    end
                    violations = 0
                    aimHistory = {}
                    return true
                end
            end
        else
            violations = math.max(0, violations - 1)
        end
    end
    
    return false
end

-- Main loop
function Protection.Run()
    if not Protection.Enabled then return end
    
    local now = GetGameTimer()
    if now - lastCheck < CHECK_INTERVAL then return end
    lastCheck = now
    
    CheckAimbot()
end

-- Initialize
function Protection.Init(config)
    if config and config.AntiAimbot then
        Protection.Enabled = config.AntiAimbot.enabled ~= false
        if config.AntiAimbot.offsetDistance then
            OFFSET_DISTANCE = config.AntiAimbot.offsetDistance
        end
    end
    
    print('^2[LyxGuard]^7 Anti-Aimbot protection initialized')
end


-- Self-register
CreateThread(function()
    Wait(100)
    if exports['lyx-guard'] and exports['lyx-guard'].RegisterProtection then
        exports['lyx-guard']:RegisterProtection('anti_aimbot', Protection)
    end
end)

return Protection
