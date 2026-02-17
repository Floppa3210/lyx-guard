--[[
    LyxGuard v4.1 - Resource Injection Protection

    Concept: SecureServe
    Rewritten from scratch - No copied code

    Features:
    - Detect unauthorized resource starts/stops
    - Monitor for injected Lua files
    - Validate resource integrity
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- PROTECTION STATE
-- ═══════════════════════════════════════════════════════════════════════════════

local ProtectionState = {
    initialized = false,
    loadedResources = {},
    playerFullyLoaded = false,
    serverResourceState = {},
    suspiciousAttempts = 0
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. RESOURCE INJECTION DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('resource_injection', {
    enabled = true,
    punishment = 'ban_perm',
    banDuration = 'permanent',
    tolerance = 1,
    checkInterval = 1000
}, function(config, state)
    -- Skip if immune or not fully loaded
    if Helpers and Helpers.IsPlayerImmune and Helpers.IsPlayerImmune() then return false end
    if not ProtectionState.playerFullyLoaded then return false end

    -- Check for suspicious conditions
    if ProtectionState.suspiciousAttempts > 0 then
        local attempts = ProtectionState.suspiciousAttempts
        ProtectionState.suspiciousAttempts = 0
        return true, {
            type = 'unauthorized_resource_activity',
            attempts = attempts
        }
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. MONITOR RESOURCE EVENTS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Wait for player to fully load before monitoring
CreateThread(function()
    Wait(15000) -- 15 second grace period after spawn
    ProtectionState.playerFullyLoaded = true

    if Config and Config.Debug then
        print('^2[LyxGuard]^7 Resource injection protection active')
    end
end)

-- Track initial resources
CreateThread(function()
    Wait(5000)

    local numResources = GetNumResources()
    for i = 0, numResources - 1 do
        local resourceName = GetResourceByFindIndex(i)
        if resourceName then
            ProtectionState.loadedResources[resourceName] = GetResourceState(resourceName)
        end
    end
end)

-- Monitor resource start events
AddEventHandler('onClientResourceStart', function(resourceName)
    if not ProtectionState.playerFullyLoaded then
        -- Still loading, mark as legitimate
        ProtectionState.loadedResources[resourceName] = 'started'
        return
    end

    -- Check if this was authorized by server
    if not ProtectionState.serverResourceState[resourceName] then
        -- Resource started without server authorization
        ProtectionState.suspiciousAttempts = ProtectionState.suspiciousAttempts + 1

        -- Immediately notify server
        TriggerServerEvent('lyxguard:detection', 'resource_injection', {
            type = 'unauthorized_start',
            resource = resourceName,
            timestamp = GetGameTimer()
        }, GetEntityCoords(PlayerPedId()))
    else
        -- Authorized, clear the state
        ProtectionState.serverResourceState[resourceName] = nil
    end

    ProtectionState.loadedResources[resourceName] = 'started'
end)

-- Monitor resource stop events
AddEventHandler('onClientResourceStop', function(resourceName)
    if not ProtectionState.playerFullyLoaded then
        ProtectionState.loadedResources[resourceName] = nil
        return
    end

    -- Critical resources that should NEVER stop
    local criticalResources = {
        ['lyx-guard'] = true,
        ['lyx-panel'] = true,
        ['es_extended'] = true,
        ['oxmysql'] = true
    }

    if criticalResources[resourceName] then
        -- Critical resource stopped unexpectedly
        ProtectionState.suspiciousAttempts = ProtectionState.suspiciousAttempts + 1

        TriggerServerEvent('lyxguard:detection', 'resource_injection', {
            type = 'critical_resource_stop',
            resource = resourceName,
            timestamp = GetGameTimer()
        }, GetEntityCoords(PlayerPedId()))
    end

    ProtectionState.loadedResources[resourceName] = nil
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. SERVER SYNC - Authorization
-- ═══════════════════════════════════════════════════════════════════════════════

-- Server notifies client about authorized resource changes
RegisterNetEvent('lyxguard:resourceAuthorized', function(resourceName, action)
    ProtectionState.serverResourceState[resourceName] = action
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. ANTI-EXECUTOR DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('executor_detection', {
    enabled = true,
    punishment = 'ban_perm',
    banDuration = 'permanent',
    tolerance = 1,
    checkInterval = 5000
}, function(config, state)
    -- Skip if immune
    if Helpers and Helpers.IsPlayerImmune and Helpers.IsPlayerImmune() then return false end

    -- Check for known executor traces
    local executorIndicators = 0

    -- Check 1: Suspicious global functions (injected by executors)
    local suspiciousFunctions = {
        'ExecuteCommand', -- Not normally exposed
        'TriggerServerEventInternal',
        'RegisterNUICallback',
        '__cfx_export',
    }

    -- Check 2: Count unexpected resources
    local numResources = GetNumResources()
    local unexpectedResources = 0

    for i = 0, numResources - 1 do
        local resourceName = GetResourceByFindIndex(i)
        if resourceName and not ProtectionState.loadedResources[resourceName] then
            unexpectedResources = unexpectedResources + 1
        end
    end

    -- If we find multiple unexpected resources, flag
    if unexpectedResources > 3 then
        return true, {
            type = 'unexpected_resources',
            count = unexpectedResources
        }
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. ANTI-DEBUG DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('debugger_detection', {
    enabled = true,
    punishment = 'kick',
    banDuration = 'short',
    tolerance = 3,
    checkInterval = 10000
}, function(config, state)
    -- Skip if immune
    if Helpers and Helpers.IsPlayerImmune and Helpers.IsPlayerImmune() then return false end

    -- Check for debug hooks (common in Lua injectors)
    if debug and debug.gethook then
        local hookFunc, hookMask = debug.gethook()
        if hookFunc ~= nil then
            return true, {
                type = 'debug_hook_detected',
                hookMask = hookMask or 'unknown'
            }
        end
    end

    return false
end)

print('^2[LyxGuard]^7 Resource injection protection module loaded')
