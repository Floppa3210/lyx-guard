--[[
    LyxGuard - Anti-GodMode Protection
    Detects players with invincibility/god mode enabled
    Based on FIREAC detection logic
]]

local Protection = {}
Protection.Name = "Anti-GodMode"
Protection.Enabled = true

-- Local references for performance
local PlayerPedId = PlayerPedId
local GetEntityHealth = GetEntityHealth
local GetEntityMaxHealth = GetEntityMaxHealth
local GetPlayerInvincible = GetPlayerInvincible
local SetPlayerInvincible = SetPlayerInvincible
local IsPedFatallyInjured = IsPedFatallyInjured
local IsEntityDead = IsEntityDead
local GetGameTimer = GetGameTimer

-- State tracking
local lastDamageTime = 0
local lastHealth = 200
local damageAttempts = 0
local CHECK_INTERVAL = 1000 -- ms
local DAMAGE_THRESHOLD = 5 -- Damage attempts before flag
local lastCheck = 0

-- Callback to report detection (set by main.lua)
Protection.OnDetection = nil

-- Check if player has godmode enabled
local function CheckGodMode()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    
    -- Skip if player is dead
    if IsEntityDead(ped) or IsPedFatallyInjured(ped) then
        damageAttempts = 0
        return
    end
    
    local currentHealth = GetEntityHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    
    -- Method 1: Direct invincibility check
    if GetPlayerInvincible(PlayerId()) then
        -- Detected: Player is set as invincible
        if Protection.OnDetection then
            Protection.OnDetection("Anti-GodMode", "Player has invincibility flag enabled", "BAN")
        end
        return true
    end
    
    -- Method 2: Check if health never decreases after damage events
    -- This is tracked via damage events in main loop
    
    lastHealth = currentHealth
    return false
end

-- Called when player takes damage (hook from main)
function Protection.OnPlayerDamage(damageAmount)
    if not Protection.Enabled then return end
    
    local ped = PlayerPedId()
    local currentHealth = GetEntityHealth(ped)
    
    -- If damage was dealt but health didn't decrease
    if damageAmount > 0 and currentHealth >= lastHealth then
        damageAttempts = damageAttempts + 1
        lastDamageTime = GetGameTimer()
        
        if damageAttempts >= DAMAGE_THRESHOLD then
            -- Detected: Player took damage but health didn't decrease
            if Protection.OnDetection then
                Protection.OnDetection(
                    "Anti-GodMode", 
                    ("Player absorbed %d damage events without losing health"):format(damageAttempts),
                    "BAN"
                )
            end
            damageAttempts = 0
            return true
        end
    else
        -- Reset counter if health decreased normally
        damageAttempts = 0
    end
    
    lastHealth = currentHealth
    return false
end

-- Main check loop
function Protection.Run()
    if not Protection.Enabled then return end
    
    local now = GetGameTimer()
    if now - lastCheck < CHECK_INTERVAL then return end
    lastCheck = now
    
    -- Reset damage counter if no damage in 10 seconds
    if now - lastDamageTime > 10000 then
        damageAttempts = 0
    end
    
    CheckGodMode()
end

-- Initialize protection
function Protection.Init(config)
    if config and config.Combat and config.Combat.godMode then
        Protection.Enabled = config.Combat.godMode.enabled
    end
    
    print('^2[LyxGuard]^7 Anti-GodMode protection initialized')
end

-- Self-register with protection system
-- Uses both new global function and legacy exports for compatibility
CreateThread(function()
    Wait(100)
    
    -- Try new global registration first (integrates with DetectionCore)
    if RegisterProtectionModule then
        RegisterProtectionModule('anti_godmode', Protection)
    -- Fallback to exports
    elseif exports['lyx-guard'] and exports['lyx-guard'].RegisterProtection then
        exports['lyx-guard']:RegisterProtection('anti_godmode', Protection)
    end
end)

return Protection

