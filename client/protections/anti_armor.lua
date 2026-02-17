--[[
    LyxGuard - Anti-Armor Hack Protection
    Detects players with abnormal armor values
    Based on FIREAC detection logic
]]

local Protection = {}
Protection.Name = "Anti-ArmorHack"
Protection.Enabled = true

-- Local references
local PlayerPedId = PlayerPedId
local GetPedArmour = GetPedArmour
local SetPedArmour = SetPedArmour
local GetPlayerMaxArmour = GetPlayerMaxArmour
local IsEntityDead = IsEntityDead
local GetGameTimer = GetGameTimer

-- Configuration
local MAX_ALLOWED_ARMOR = 100 -- Default GTA max armor
local CHECK_INTERVAL = 500 -- ms
local VIOLATION_THRESHOLD = 3
local lastCheck = 0
local violations = 0
local lastViolationTime = 0

-- Callback
Protection.OnDetection = nil

-- Check for abnormal armor
local function CheckArmor()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    
    if IsEntityDead(ped) then
        violations = 0
        return false
    end
    
    local currentArmor = GetPedArmour(ped)
    
    -- Check if armor exceeds maximum
    if currentArmor > MAX_ALLOWED_ARMOR then
        violations = violations + 1
        lastViolationTime = GetGameTimer()
        
        -- Correct the armor
        SetPedArmour(ped, MAX_ALLOWED_ARMOR)
        
        if violations >= VIOLATION_THRESHOLD then
            if Protection.OnDetection then
                Protection.OnDetection(
                    "Anti-ArmorHack",
                    ("Armor exceeded maximum: %d (max allowed: %d)"):format(currentArmor, MAX_ALLOWED_ARMOR),
                    "BAN"
                )
            end
            violations = 0
            return true
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
    
    if now - lastViolationTime > 30000 then
        violations = 0
    end
    
    CheckArmor()
end

-- Initialize
function Protection.Init(config)
    if config and config.AntiArmorHack then
        Protection.Enabled = config.AntiArmorHack.enabled ~= false
        if config.AntiArmorHack.maxArmor then
            MAX_ALLOWED_ARMOR = config.AntiArmorHack.maxArmor
        end
    end
    
    print('^2[LyxGuard]^7 Anti-ArmorHack protection initialized (Max: ' .. MAX_ALLOWED_ARMOR .. ')')
end

-- Self-register with protection system
CreateThread(function()
    Wait(100)
    
    if RegisterProtectionModule then
        RegisterProtectionModule('anti_armor', Protection)
    elseif exports['lyx-guard'] and exports['lyx-guard'].RegisterProtection then
        exports['lyx-guard']:RegisterProtection('anti_armor', Protection)
    end
end)

return Protection
