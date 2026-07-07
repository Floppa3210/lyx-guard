--[[
    LyxGuard v4.0 - Advanced Detections Module

    Detecciones avanzadas (inyecciones, comportamiento sospechoso).
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. INJECTION/EXECUTOR DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('injection', {
    enabled = true,
    punishment = 'ban_perm',
    tolerance = 1,
    checkInterval = 30000,
    knownExecutors = {
        'eulen', 'hammafia', 'sakura', 'redengine', 'skript', 'lynx',
        'brutan', 'cipher', 'sentinel', 'desudo', 'dopamine', 'famous',
        'phoenix', 'evo', 'exm', 'kiddions', 'impulse', 'paragon',
        'stand', 'cherax', 'midnight', 'skid', 'cheat', 'hack', 'menu'
    }
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or 0

    if GetGameTimer() - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = GetGameTimer()

    local numRes = GetNumResources()
    for i = 0, numRes - 1 do
        local name = GetResourceByFindIndex(i):lower()
        for _, ex in ipairs(config.knownExecutors) do
            if string.find(name, ex) then
                return true, { resource = name, matchedPattern = ex }
            end
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. MENU KEYBIND DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('menudetection', {
    enabled = true,
    punishment = 'notify',
    tolerance = 3,
    suspiciousKeys = {
        { control = 288, name = 'F1' }, -- Común en menús
        { control = 166, name = 'F5' },
        { control = 57,  name = 'F10' },
        { control = 344, name = 'INSERT' },
        { control = 46,  name = 'E' }, -- Solo cuando está en pantalla de carga
    }
}, function(config, state)
    -- Esta es más un placeholder, detectar menús por keybinds es difícil
    -- Se puede expandir para detectar patrones sospechosos
    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. AFK FARMING DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('afkfarming', {
    enabled = true,
    punishment = 'kick',
    tolerance = 1,
    maxAFKTime = 900000, -- 15 minutos
    checkInterval = 10000
}, function(config, state)
    state.data.lastPos = state.data.lastPos or GetEntityCoords(PlayerPedId())
    state.data.afkTime = state.data.afkTime or 0
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()

    if GetGameTimer() - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = GetGameTimer()

    local pos = GetEntityCoords(PlayerPedId())
    local dist = #(pos - state.data.lastPos)

    if dist < 1.0 then
        state.data.afkTime = state.data.afkTime + config.checkInterval
        if state.data.afkTime >= config.maxAFKTime then
            state.data.afkTime = 0
            return true, { afkTime = config.maxAFKTime }
        end
    else
        state.data.afkTime = 0
    end

    state.data.lastPos = pos
    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. RESOURCE HASH VALIDATION
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('resourcevalidation', {
    enabled = true,
    punishment = 'kick',
    tolerance = 1,
    checkInterval = 60000,
    requiredResources = {
        'es_extended',
        'lyx-guard'
    }
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or 0

    if GetGameTimer() - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = GetGameTimer()

    for _, res in ipairs(config.requiredResources) do
        if GetResourceState(res) ~= 'started' then
            return true, { resource = res, state = GetResourceState(res) }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. AIMBOT DETECTION
-- (unificado) La deteccion 'aimbot' vive en client/detections/combat_advanced.lua
-- (analisis de snap-angle sobre historial de camara). Se elimino el registro
-- duplicado que existia aqui para evitar doble ejecucion del mismo nombre.
-- Nota: 'aimbot_ultra' (ultra.lua) es un nombre distinto y se conserva.
-- ═══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. SPECTATE/FREECAM DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('spectate', {
    enabled = true,
    punishment = 'notify',
    tolerance = 3,
    maxCameraDistance = 100.0, -- Max distance camera can be from ped
    checkInterval = 1000
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or 0

    local now = GetGameTimer()
    if now - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = now

    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local camCoords = GetGameplayCamCoord()

    local dist = #(pedCoords - camCoords)

    -- Check if camera is too far from the player (possible freecam)
    if dist > config.maxCameraDistance then
        -- Verify player is not in a vehicle with special camera
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle == 0 then
            return true, {
                distance = math.floor(dist),
                maxAllowed = config.maxCameraDistance
            }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. INVISIBILITY DETECTION
-- (unificado) La deteccion 'invisibility' se consolido en
-- client/detections/player_state.lua ('invisible', con checks de alpha/physics).
-- Se elimino el registro duplicado que existia aqui.
-- ═══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. TASK/ANIMATION EXPLOIT DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('taskexploit', {
    enabled = true,
    punishment = 'notify',
    tolerance = 5,
    suspiciousTasks = {
        'TASK_PARACHUTE',
        'TASK_CLIMB',
        'TASK_RAPPEL_FROM_HELI'
    },
    checkInterval = 2000
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or 0

    local now = GetGameTimer()
    if now - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = now

    local ped = PlayerPedId()

    -- Check for parachute without jumping from height
    if GetPedParachuteState(ped) >= 0 then
        local coords = GetEntityCoords(ped)
        local ground, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
        local heightAboveGround = coords.z - groundZ

        -- If player has parachute open but is very low, suspicious
        if heightAboveGround < 10.0 then
            return true, { parachuteState = GetPedParachuteState(ped), height = math.floor(heightAboveGround) }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 9. ENTITY SPAWN DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('entityspam', {
    enabled = true,
    punishment = 'kick',
    tolerance = 2,
    maxVehiclesPerMinute = 5,
    maxPedsPerMinute = 10,
    checkInterval = 5000
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or 0
    state.data.vehicleCount = state.data.vehicleCount or 0
    state.data.pedCount = state.data.pedCount or 0
    state.data.resetTime = state.data.resetTime or GetGameTimer()

    local now = GetGameTimer()

    -- Reset counts every minute
    if now - state.data.resetTime > 60000 then
        state.data.vehicleCount = 0
        state.data.pedCount = 0
        state.data.resetTime = now
    end

    if now - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = now

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    -- Count nearby vehicles that player owns
    local vehicles = GetGamePool('CVehicle')
    local playerVehicles = 0
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local netId = NetworkGetNetworkIdFromEntity(vehicle)
            if netId and NetworkDoesNetworkIdExist(netId) then
                local owner = NetworkGetEntityOwner(vehicle)
                if owner == PlayerId() then
                    local vehCoords = GetEntityCoords(vehicle)
                    if #(coords - vehCoords) < 50.0 then
                        playerVehicles = playerVehicles + 1
                    end
                end
            end
        end
    end

    if playerVehicles > config.maxVehiclesPerMinute then
        return true, { vehicles = playerVehicles, maxAllowed = config.maxVehiclesPerMinute }
    end

    return false
end)

print('^2[LyxGuard v4.0]^7 Advanced Detections loaded (9 modules)')
