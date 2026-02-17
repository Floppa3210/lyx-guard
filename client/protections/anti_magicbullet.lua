--[[
    LyxGuard - Anti-Magic Bullet Protection
    Detects players killing through walls (no line of sight)
    Based on AntiMagicBullet detection logic
]]

local Protection = {}
Protection.Name = "Anti-MagicBullet"
Protection.Enabled = true

-- Local references
local PlayerPedId = PlayerPedId
local PlayerId = PlayerId
local GetEntityCoords = GetEntityCoords
local IsPedAPlayer = IsPedAPlayer
local NetworkGetPlayerIndexFromPed = NetworkGetPlayerIndexFromPed
local NetworkIsPlayerActive = NetworkIsPlayerActive
local GetPedSourceOfDeath = GetPedSourceOfDeath
local GetPedCauseOfDeath = GetPedCauseOfDeath
local IsPedDeadOrDying = IsPedDeadOrDying
local IsPedFatallyInjured = IsPedFatallyInjured
local HasEntityClearLosToEntityInFront = HasEntityClearLosToEntityInFront
local HasEntityClearLosToEntity = HasEntityClearLosToEntity
local GetPlayerServerId = GetPlayerServerId
local GetGameTimer = GetGameTimer

-- Configuration
local TOLERANCE = 3 -- Checks before flagging
local LOS_CHECK_DELAY = 500 -- ms between LOS checks
local CHECK_INTERVAL = 1500 -- ms per check cycle

-- Callback
Protection.OnDetection = nil

-- Check if killer had line of sight to victim
local function CheckKillerLOS(attacker, victim, killerClientId)
    if not attacker or not victim or not killerClientId then return end
    
    local attempts = 0
    
    -- Check LOS multiple times with delays
    for i = 0, 3 do
        local hasLosFront = HasEntityClearLosToEntityInFront(attacker, victim)
        local hasLos17 = HasEntityClearLosToEntity(attacker, victim, 17)
        
        -- If no line of sight from any angle
        if not hasLosFront and not hasLos17 then
            attempts = attempts + 1
        end
        
        Wait(LOS_CHECK_DELAY)
    end
    
    -- If majority of checks failed LOS
    if attempts >= TOLERANCE then
        local killerServerId = GetPlayerServerId(killerClientId)
        
        if Protection.OnDetection then
            Protection.OnDetection(
                "Anti-MagicBullet",
                ("Player ID %d killed through wall (no LOS in %d/%d checks)"):format(killerServerId, attempts, 4),
                "BAN"
            )
        end
        
        -- Also report to server
        TriggerServerEvent('lyxguard:detection', 'MagicBullet', killerServerId, 
            ("Killed player without line of sight (%d failed LOS checks)"):format(attempts))
        
        return true
    end
    
    return false
end

-- Event handler for entity damage
local function OnEntityDamage(event, data)
    if event ~= 'CEventNetworkEntityDamage' then return end
    
    local victim = data[1]
    local victimDied = data[4]
    
    -- Only check if victim is a player
    if not IsPedAPlayer(victim) then return end
    
    local player = PlayerId()
    local playerPed = PlayerPedId()
    
    -- Check if WE are the victim who died
    if victimDied and NetworkGetPlayerIndexFromPed(victim) == player then
        if IsPedDeadOrDying(victim, true) or IsPedFatallyInjured(victim) then
            local killerEntity = GetPedSourceOfDeath(playerPed)
            local deathCause = GetPedCauseOfDeath(playerPed)
            
            -- Get killer's client ID
            local killerClientId = NetworkGetPlayerIndexFromPed(killerEntity)
            
            -- Only check if killed by another player (not self)
            if killerEntity ~= playerPed and killerClientId and NetworkIsPlayerActive(killerClientId) then
                local attacker = GetPlayerPed(killerClientId)
                
                -- Run LOS check in a thread to not block
                CreateThread(function()
                    CheckKillerLOS(attacker, victim, killerClientId)
                end)
            end
        end
    end
end

-- Initialize event handler
function Protection.Init(config)
    if config and config.AntiMagicBullet then
        Protection.Enabled = config.AntiMagicBullet.enabled ~= false
        if config.AntiMagicBullet.tolerance then
            TOLERANCE = config.AntiMagicBullet.tolerance
        end
    end
    
    -- Register game event handler
    AddEventHandler('gameEventTriggered', function(event, data)
        if Protection.Enabled then
            OnEntityDamage(event, data)
        end
    end)
    
    print('^2[LyxGuard]^7 Anti-MagicBullet protection initialized (Tolerance: ' .. TOLERANCE .. ')')
end

-- No continuous run needed - event-based
function Protection.Run()
    -- This protection is event-based, not loop-based
end

-- Self-register
CreateThread(function()
    Wait(100)
    if exports['lyx-guard'] and exports['lyx-guard'].RegisterProtection then
        exports['lyx-guard']:RegisterProtection('anti_magicbullet', Protection)
    end
end)

return Protection
