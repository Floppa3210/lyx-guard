--[[
    LyxGuard - Anti-Explosion Protection
    Detects and blocks blacklisted explosion types
    Based on Icarus ExplosionFilterModule
]]

local Protection = {}
Protection.Name = "Anti-Explosion"
Protection.Enabled = true

-- Local references
local GetGameTimer = GetGameTimer
local GetEntityCoords = GetEntityCoords
local PlayerPedId = PlayerPedId

-- Configuration
local MAX_EXPLOSIONS_PER_SECOND = 5
local CHECK_INTERVAL = 1000
local explosionCount = 0
local lastCheck = 0
local lastResetTime = 0

-- Callback
Protection.OnDetection = nil

-- Whitelisted explosion types (from Icarus)
-- See: https://docs.fivem.net/natives/?_0xE3AD2BDBAEE269AC
local WHITELISTED_EXPLOSIONS = {
    [6] = true,   -- HI_OCTANE
    [7] = true,   -- CAR
    [8] = true,   -- PLANE
    [9] = true,   -- PETROL_PUMP
    [10] = true,  -- BIKE
    [11] = true,  -- DIR_STEAM
    [12] = true,  -- DIR_FLAME
    [13] = true,  -- DIR_WATER_HYDRANT
    [14] = true,  -- DIR_GAS_CANISTER
    [15] = true,  -- BOAT
    [16] = true,  -- SHIP_DESTROY
    [17] = true,  -- TRUCK
    [22] = true,  -- FLARE
    [23] = true,  -- GAS_CANISTER
    [24] = true,  -- EXTINGUISHER
    [27] = true,  -- EXP_TAG_BARREL
    [28] = true,  -- EXP_TAG_PROPANE
    [30] = true,  -- EXP_TAG_DIR_FLAME_EXPLODE
    [31] = true,  -- EXP_TAG_TANKER
    [34] = true,  -- EXP_TAG_GAS_TANK
    [38] = true,  -- EXP_TAG_FIREWORK
    [39] = true,  -- EXP_TAG_SNOWBALL
    [78] = true,  -- EXP_TAG_FLASHGRENADE
    [79] = true,  -- EXP_TAG_STUNGRENADE
}

-- Blacklisted explosion types (dangerous)
local BLACKLISTED_EXPLOSIONS = {
    [0] = "GRENADE",
    [1] = "GRENADELAUNCHER",
    [2] = "STICKYBOMB",
    [3] = "MOLOTOV",
    [4] = "ROCKET",
    [5] = "TANKSHELL",
    [18] = "BULLET",
    [19] = "SMOKEGRENADELAUNCHER",
    [20] = "BZGAS",
    [21] = "FLARE",
    [35] = "BIRD_CRAP",
}

-- Track explosions
local recentExplosions = {}

-- Called when explosion event is detected
function Protection.OnExplosion(sender, explosionType, posX, posY, posZ, isAudible, isInvisible, cameraShake, damageScale)
    if not Protection.Enabled then return true end
    
    local now = GetGameTimer()
    
    -- Reset counter every second
    if now - lastResetTime > 1000 then
        explosionCount = 0
        lastResetTime = now
    end
    
    explosionCount = explosionCount + 1
    
    -- Check for explosion spam
    if explosionCount > MAX_EXPLOSIONS_PER_SECOND then
        if Protection.OnDetection then
            Protection.OnDetection(
                "Anti-Explosion",
                ("Explosion spam detected: %d explosions/second"):format(explosionCount),
                "BAN"
            )
        end
        return false -- Block the explosion
    end
    
    -- Check if explosion type is blacklisted
    if not WHITELISTED_EXPLOSIONS[explosionType] then
        local explosionName = BLACKLISTED_EXPLOSIONS[explosionType] or ("Unknown Type " .. explosionType)
        
        if Protection.OnDetection then
            Protection.OnDetection(
                "Anti-Explosion",
                ("Blacklisted explosion type: %s (ID: %d)"):format(explosionName, explosionType),
                "KICK"
            )
        end
        
        return false -- Block the explosion
    end
    
    return true -- Allow the explosion
end

-- Initialize explosion event handler
function Protection.Init(config)
    if config and config.AntiExplosion then
        Protection.Enabled = config.AntiExplosion.enabled ~= false
        if config.AntiExplosion.maxPerSecond then
            MAX_EXPLOSIONS_PER_SECOND = config.AntiExplosion.maxPerSecond
        end
    end
    
    -- Register explosion event handler
    AddEventHandler('explosionEvent', function(sender, ev)
        if not Protection.OnExplosion(
            sender, 
            ev.explosionType, 
            ev.posX, ev.posY, ev.posZ,
            ev.isAudible, ev.isInvisible,
            ev.cameraShake, ev.damageScale
        ) then
            CancelEvent()
        end
    end)
    
    print('^2[LyxGuard]^7 Anti-Explosion protection initialized')
end

-- No continuous run needed - event-based
function Protection.Run()
    -- Event-based protection
end

-- Self-register
CreateThread(function()
    Wait(100)
    if exports['lyx-guard'] and exports['lyx-guard'].RegisterProtection then
        exports['lyx-guard']:RegisterProtection('anti_explosion', Protection)
    end
end)

return Protection
