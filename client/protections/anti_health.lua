--[[
    LyxGuard - Anti-Health Hack Protection
    Detects players with abnormal health values
    Based on FIREAC detection logic
]]

local Protection = {}
Protection.Name = "Anti-HealthHack"
Protection.Enabled = true

-- Local references
local PlayerPedId = PlayerPedId
local GetEntityHealth = GetEntityHealth
local GetEntityMaxHealth = GetEntityMaxHealth
local SetEntityHealth = SetEntityHealth
local IsEntityDead = IsEntityDead
local GetGameTimer = GetGameTimer

-- Configuration
local MAX_ALLOWED_HEALTH = 200 -- Default GTA max health
local CHECK_INTERVAL = 500 -- ms
local VIOLATION_THRESHOLD = 3 -- Violations before action
local lastCheck = 0
local violations = 0
local lastViolationTime = 0

-- Callback
Protection.OnDetection = nil

-- Check for abnormal health
local function CheckHealth()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    
    -- Skip if dead
    if IsEntityDead(ped) then
        violations = 0
        return false
    end
    
    local currentHealth = GetEntityHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    
    -- Check if health exceeds maximum allowed
    if currentHealth > MAX_ALLOWED_HEALTH then
        violations = violations + 1
        lastViolationTime = GetGameTimer()
        
        -- Immediately correct the health
        SetEntityHealth(ped, MAX_ALLOWED_HEALTH)
        
        if violations >= VIOLATION_THRESHOLD then
            if Protection.OnDetection then
                Protection.OnDetection(
                    "Anti-HealthHack",
                    ("Health exceeded maximum: %d/%d (max allowed: %d)"):format(currentHealth, maxHealth, MAX_ALLOWED_HEALTH),
                    "BAN"
                )
            end
            violations = 0
            return true
        end
    end
    
    -- Check if max health was modified (should be 200)
    if maxHealth > MAX_ALLOWED_HEALTH then
        violations = violations + 1
        
        if violations >= VIOLATION_THRESHOLD then
            if Protection.OnDetection then
                Protection.OnDetection(
                    "Anti-HealthHack",
                    ("Max health modified to: %d"):format(maxHealth),
                    "BAN"
                )
            end
            violations = 0
            return true
        end
    end
    
    return false
end

-- Main check loop
function Protection.Run()
    if not Protection.Enabled then return end
    
    local now = GetGameTimer()
    if now - lastCheck < CHECK_INTERVAL then return end
    lastCheck = now
    
    -- Reset violations after 30 seconds of no violations
    if now - lastViolationTime > 30000 then
        violations = 0
    end
    
    CheckHealth()
end

-- Initialize
function Protection.Init(config)
    if config and config.AntiHealthHack then
        Protection.Enabled = config.AntiHealthHack.enabled ~= false
        if config.AntiHealthHack.maxHealth then
            MAX_ALLOWED_HEALTH = config.AntiHealthHack.maxHealth
        end
    end
    
    print('^2[LyxGuard]^7 Anti-HealthHack protection initialized (Max: ' .. MAX_ALLOWED_HEALTH .. ')')
end

-- Self-register with protection system
CreateThread(function()
    Wait(100)
    
    if RegisterProtectionModule then
        RegisterProtectionModule('anti_health', Protection)
    elseif exports['lyx-guard'] and exports['lyx-guard'].RegisterProtection then
        exports['lyx-guard']:RegisterProtection('anti_health', Protection)
    end
end)

return Protection
