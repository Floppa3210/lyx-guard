--[[
    LyxGuard v4.1 - Entity & Explosion Spam Detection Module

    Extracted concepts from: FIREAC, SecureServe
    Rewritten from scratch with LyxGuard architecture

    Features:
    - Explosion spam detection
    - Entity spawn spam detection (vehicles, peds, objects)
    - Blacklisted explosion types
    - Rate limiting per player
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- EXPLOSION BLACKLIST (From FIREAC - Dangerous explosion types)
-- ═══════════════════════════════════════════════════════════════════════════════

local BlacklistedExplosions = {
    -- Weapon explosions (ban-worthy in RP servers)
    [0] = { name = "Grenade", severity = "high" },
    [1] = { name = "GrenadeLauncher", severity = "high" },
    [3] = { name = "Molotov", severity = "high" },
    [4] = { name = "Rocket", severity = "critical" },
    [5] = { name = "TankShell", severity = "critical" },
    [18] = { name = "Bullet", severity = "critical" }, -- Explosive bullets = cheat
    [19] = { name = "SmokeGrenadeLauncher", severity = "high" },
    [32] = { name = "PlaneRocket", severity = "critical" },
    [37] = { name = "Valkyrie_Cannon", severity = "critical" },
}

-- Allowed explosion types (vehicles, environment)
local AllowedExplosions = {
    [6] = true,  -- Hi_Octane
    [7] = true,  -- Car
    [8] = true,  -- Plane
    [9] = true,  -- PetrolPump
    [10] = true, -- Bike
    [15] = true, -- Boat
    [17] = true, -- Truck
    [20] = true, -- SmokeGrenade
    [21] = true, -- BZGAS
    [22] = true, -- Flare
    [24] = true, -- Extinguisher
    [26] = true, -- Train
    [33] = true, -- VehicleBullet
    [35] = true, -- FireWork
    [36] = true, -- SnowBall
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. EXPLOSION SPAM DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('explosion_spam', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'long',
    tolerance = 3,
    maxExplosionsPerSecond = 3,   -- Max explosions per second
    maxBlacklistedExplosions = 1, -- Blacklisted = instant flag
    checkInterval = 100
}, function(config, state)
    -- Skip if immune
    if Helpers.IsPlayerImmune() then return false end

    -- Initialize state
    if not state.data.initialized then
        state.data.initialized = true
        state.data.explosionCount = 0
        state.data.lastResetTime = GetGameTimer()
        state.data.blacklistedCount = 0
        return false
    end

    -- This detection is primarily server-side via event handler
    -- Client-side just tracks for verification
    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. ENTITY SPAWN SPAM DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('entity_spam', {
    enabled = true,
    punishment = 'kick',
    banDuration = 'medium',
    tolerance = 5,
    maxVehiclesPerMinute = 10,
    maxPedsPerMinute = 15,
    maxObjectsPerMinute = 30,
    checkInterval = 1000
}, function(config, state)
    -- Skip if immune
    if Helpers.IsPlayerImmune() then return false end

    -- Initialize tracking
    if not state.data.initialized then
        state.data.initialized = true
        state.data.spawnedVehicles = 0
        state.data.spawnedPeds = 0
        state.data.spawnedObjects = 0
        state.data.lastResetTime = GetGameTimer()
        return false
    end

    local now = GetGameTimer()

    -- Reset counters every minute
    if now - state.data.lastResetTime > 60000 then
        state.data.spawnedVehicles = 0
        state.data.spawnedPeds = 0
        state.data.spawnedObjects = 0
        state.data.lastResetTime = now
    end

    -- Check limits
    if state.data.spawnedVehicles > config.maxVehiclesPerMinute then
        return true, {
            type = 'vehicle_spam',
            count = state.data.spawnedVehicles,
            maxAllowed = config.maxVehiclesPerMinute
        }
    end

    if state.data.spawnedPeds > config.maxPedsPerMinute then
        return true, {
            type = 'ped_spam',
            count = state.data.spawnedPeds,
            maxAllowed = config.maxPedsPerMinute
        }
    end

    if state.data.spawnedObjects > config.maxObjectsPerMinute then
        return true, {
            type = 'object_spam',
            count = state.data.spawnedObjects,
            maxAllowed = config.maxObjectsPerMinute
        }
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. BLACKLISTED EXPLOSION TYPE DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('blacklisted_explosion', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'long',
    tolerance = 1,
    checkInterval = 100
}, function(config, state)
    -- This detection requires event hooking
    -- The actual check is done via AddExplosionEvent native hook
    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- EXPLOSION EVENT HOOK
-- ═══════════════════════════════════════════════════════════════════════════════

-- Hook explosion events
AddEventHandler('explosionEvent', function(sender, ev)
    local playerId = GetPlayerFromServerId(sender)

    -- Check if player is immune (admin)
    if playerId and IsPlayerImmune and IsPlayerImmune(playerId) then
        return
    end

    local explosionType = ev.explosionType

    -- Check against blacklist
    if BlacklistedExplosions[explosionType] then
        local explosionData = BlacklistedExplosions[explosionType]

        -- Trigger detection
        TriggerServerEvent('lyxguard:detection', 'blacklisted_explosion', {
            explosionType = explosionType,
            explosionName = explosionData.name,
            severity = explosionData.severity,
            position = {
                x = ev.posX,
                y = ev.posY,
                z = ev.posZ
            }
        }, {
            x = ev.posX,
            y = ev.posY,
            z = ev.posZ
        })

        -- Cancel the explosion if critical
        if explosionData.severity == 'critical' then
            CancelEvent()
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- ENTITY CREATION HOOKS (For spam detection)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Track vehicle creation
local originalCreateVehicle = CreateVehicle
CreateVehicle = function(modelHash, x, y, z, heading, isNetwork, netMissionEntity)
    local state = GetDetectionState('entity_spam')
    if state and state.data then
        state.data.spawnedVehicles = (state.data.spawnedVehicles or 0) + 1
    end
    return originalCreateVehicle(modelHash, x, y, z, heading, isNetwork, netMissionEntity)
end

-- Track ped creation
local originalCreatePed = CreatePed
CreatePed = function(pedType, modelHash, x, y, z, heading, isNetwork, bScriptHostPed)
    local state = GetDetectionState('entity_spam')
    if state and state.data then
        state.data.spawnedPeds = (state.data.spawnedPeds or 0) + 1
    end
    return originalCreatePed(pedType, modelHash, x, y, z, heading, isNetwork, bScriptHostPed)
end

-- Track object creation
local originalCreateObject = CreateObject
CreateObject = function(modelHash, x, y, z, isNetwork, netMissionEntity, doorFlag)
    local state = GetDetectionState('entity_spam')
    if state and state.data then
        state.data.spawnedObjects = (state.data.spawnedObjects or 0) + 1
    end
    return originalCreateObject(modelHash, x, y, z, isNetwork, netMissionEntity, doorFlag)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- EXPORTS FOR EXTERNAL USE
-- ═══════════════════════════════════════════════════════════════════════════════

-- Check if explosion type is blacklisted
exports('IsExplosionBlacklisted', function(explosionType)
    return BlacklistedExplosions[explosionType] ~= nil
end)

-- Get explosion data
exports('GetExplosionData', function(explosionType)
    return BlacklistedExplosions[explosionType]
end)

print('^2[LyxGuard]^7 Entity & Explosion spam detection module loaded')
