--[[
    LyxGuard v4.0 - Events & Resources Detection Module

    Detecciones de manipulación de eventos y recursos sospechosos.
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. ANTI-EVENT SPAM (Triggering too many events)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('eventspam', {
    enabled = true,
    punishment = 'kick',
    banDuration = 'short',
    tolerance = 1,
    maxEventsPerMinute = 500,
    trackingWindow = 60000 -- 1 minute
}, function(config, state)
    -- This needs to be tracked server-side for accuracy
    -- Client can only monitor certain patterns
    return false
end)

RegisterDetection('honeypot_event', (Config and Config.Advanced and Config.Advanced.honeypotEvent) or {
    enabled = true,
    punishment = 'ban_perm',
    tolerance = 1,
    events = {}
}, function(config, state)
    return false
end)

local _HoneypotLastTrigger = 0
local function _TriggerHoneypotEvent(eventName, invokingResource)
    local cfg = (Config and Config.Advanced and Config.Advanced.honeypotEvent) or nil
    if not cfg or cfg.enabled == false then return end

    local now = GetGameTimer()
    if _HoneypotLastTrigger ~= 0 and (now - _HoneypotLastTrigger) < 1500 then
        return
    end
    _HoneypotLastTrigger = now

    TriggerDetection('honeypot_event', {
        event = eventName,
        invokingResource = invokingResource
    })
end

CreateThread(function()
    local cfg = (Config and Config.Advanced and Config.Advanced.honeypotEvent) or nil
    local events = cfg and cfg.events or nil
    if type(events) ~= 'table' then return end

    for _, eventName in ipairs(events) do
        if type(eventName) == 'string' and eventName ~= '' then
            RegisterNetEvent(eventName)
            AddEventHandler(eventName, function()
                local invokingResource = nil
                if type(GetInvokingResource) == 'function' then
                    invokingResource = GetInvokingResource()
                end
                if not invokingResource or invokingResource == '' then
                    _TriggerHoneypotEvent(eventName, invokingResource)
                end
            end)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. ANTI-RESOURCE STOP/START (Tampering with resources)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('resourcetamper', {
    enabled = true,
    punishment = 'ban_perm',
    tolerance = 1,
    checkInterval = 5000,
    criticalResources = {
        'lyx-guard',
        'es_extended',
        'oxmysql'
    }
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()
    state.data.resourceStates = state.data.resourceStates or {}

    if GetGameTimer() - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = GetGameTimer()

    for _, res in ipairs(config.criticalResources) do
        local currentState = GetResourceState(res)
        local lastState = state.data.resourceStates[res]

        if lastState and lastState == 'started' and currentState ~= 'started' then
            -- Resource was running and now it's not
            return true, { resource = res, previousState = lastState, currentState = currentState }
        end

        state.data.resourceStates[res] = currentState
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. ANTI-SCRIPT INJECTION (Global variable pollution)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('scriptinjection', {
    enabled = true,
    punishment = 'ban_perm',
    tolerance = 1,
    checkInterval = 30000,
    suspiciousGlobals = {
        'eulen', 'EulenCheats', 'HammafiaMenu', 'LynxMenu',
        'RedEngine', 'BrutanClient', 'CipherMenu', 'SentinelMenu',
        'CheatActivated', 'HackMenu', 'InjectorLoaded', 'MenuOpen',
        'ExecutorClient', 'LuaExecutor', 'ScriptHook', 'CheatEngine'
    }
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or 0

    if GetGameTimer() - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = GetGameTimer()

    for _, globalName in ipairs(config.suspiciousGlobals) do
        if _G[globalName] ~= nil then
            return true, { globalVariable = globalName }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. ANTI-FUNCTION HOOK (Detect if natives are hooked)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('functionhook', {
    enabled = true,
    punishment = 'ban_perm',
    tolerance = 1,
    checkInterval = 60000
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or 0

    if GetGameTimer() - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = GetGameTimer()

    -- Natives criticas que un cheat suele reemplazar por un closure Lua para
    -- interceptar/anular llamadas (ej. neutralizar SetEntityHealth del AC).
    -- Se usa acceso lexico (no rawget) para ser agnostico a como FiveM expone
    -- las natives (algunas via metatabla __index de _G).
    local nativesToCheck = {
        { ref = GetPlayerPed,       name = 'GetPlayerPed' },
        { ref = GetEntityCoords,    name = 'GetEntityCoords' },
        { ref = SetEntityHealth,    name = 'SetEntityHealth' },
        { ref = TriggerServerEvent, name = 'TriggerServerEvent' },
    }

    -- Snapshot de referencias en la primera corrida (identidad original de la native).
    if not state.data.baseline then
        state.data.baseline = {}
        for _, n in ipairs(nativesToCheck) do
            state.data.baseline[n.name] = n.ref
        end
        return false
    end

    for _, n in ipairs(nativesToCheck) do
        -- 1) Ya no es funcion => hook/tamper evidente.
        if type(n.ref) ~= 'function' then
            return true, { hookedFunction = n.name, reason = 'not_a_function', type = type(n.ref) }
        end

        -- 2) La referencia cambio respecto al baseline => reemplazada (hook).
        if state.data.baseline[n.name] ~= nil and n.ref ~= state.data.baseline[n.name] then
            return true, { hookedFunction = n.name, reason = 'reference_replaced' }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. ANTI-FREECAM
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('freecam', {
    enabled = true,
    punishment = 'kick',
    banDuration = 'short',
    tolerance = 3,
    checkInterval = 1000,
    maxCamDistance = 50.0 -- Max allowed distance from player to camera
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()

    if GetGameTimer() - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = GetGameTimer()

    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local camCoords = GetGameplayCamCoord()

    local distance = #(playerCoords - camCoords)

    -- Player in vehicle has different camera position
    if not IsPedInAnyVehicle(ped, false) then
        if distance > config.maxCamDistance then
            return true, { distance = distance, maxAllowed = config.maxCamDistance }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. ANTI-SPECTATE ABUSE
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('spectateabuse', {
    enabled = true,
    punishment = 'notify',
    tolerance = 2,
    checkInterval = 2000
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()

    if GetGameTimer() - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = GetGameTimer()

    local ped = PlayerPedId()
    local isInvisible = not IsEntityVisible(ped)
    local isInvincible = GetPlayerInvincible(PlayerId())
    local isFrozen = IsEntityPositionFrozen(ped)

    -- Spectating typically makes player invisible, invincible, and frozen
    if isInvisible and isInvincible and isFrozen then
        -- Check if it's legitimate admin spectate
        if not LocalPlayer.state.isSpectating then
            return true, { invisible = isInvisible, invincible = isInvincible, frozen = isFrozen }
        end
    end

    return false
end)

print('[LyxGuard] Events & Resources detection module loaded')
