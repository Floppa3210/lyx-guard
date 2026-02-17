--[[
    LyxGuard v4.0 - Extended Detections Module

    Detecciones avanzadas adicionales para mayor seguridad.
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. ANTI-RESOURCE INJECTOR
-- Detecta cuando se inyectan recursos no autorizados
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('resource_injection', {
    enabled = true,
    punishment = 'ban_perm',
    checkInterval = 5000,
    tolerance = 1
}, function(config, state)
    -- Verificar ejecutores comunes
    local badExecutors = {
        'meow', 'owl', 'lunar', 'skid', 'redengine', 'eulen',
        'hammafia', 'desudo', 'brutan', 'dopamine', 'kitsune'
    }

    for _, executor in ipairs(badExecutors) do
        if GetResourceState(executor) == 'started' then
            return true, { executor = executor }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. ANTI-INVISIBLE (God Mode con invisibilidad)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('invisible_abuse', {
    enabled = true,
    punishment = 'kick',
    checkInterval = 2000,
    tolerance = 3
}, function(config, state)
    local ped = PlayerPedId()

    -- Si está invisible pero no debería estarlo
    if not IsEntityVisible(ped) then
        -- Verificar si es legítimo (algún script de admin lo hizo invisible)
        if not LocalPlayer.state.adminInvisible then
            return true, { visible = false }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. ANTI-SUPER JUMP
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('super_jump', {
    enabled = true,
    punishment = 'warn',
    maxJumpHeight = 8.0,
    checkInterval = 100,
    tolerance = 3
}, function(config, state)
    local ped = PlayerPedId()

    if IsPedJumping(ped) then
        local velZ = GetEntityVelocity(ped).z
        if velZ > config.maxJumpHeight then
            return true, { jumpVelocity = velZ }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. ANTI-PED CHANGE (Cambiar el modelo a algo ilegal)
-- ═══════════════════════════════════════════════════════════════════════════════

local lastPedModel = nil

RegisterDetection('illegal_ped', {
    enabled = true,
    punishment = 'kick',
    checkInterval = 2000,
    tolerance = 2,
    bannedModels = {
        GetHashKey('a_f_m_prolhost_01'),
        GetHashKey('s_m_m_movprem_01'),
        GetHashKey('a_m_m_bevhills_02')
    }
}, function(config, state)
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)

    -- Verificar modelos baneados
    for _, banned in ipairs(config.bannedModels or {}) do
        if model == banned then
            return true, { model = model }
        end
    end

    -- Verificar cambio frecuente de modelo (puede ser menu)
    if lastPedModel and lastPedModel ~= model then
        state.data.modelChanges = (state.data.modelChanges or 0) + 1
        if state.data.modelChanges > 5 then
            state.data.modelChanges = 0
            return true, { rapidModelChange = true, model = model }
        end
    end
    lastPedModel = model

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. ANTI-EXPLOSION SPAM
-- ═══════════════════════════════════════════════════════════════════════════════

local explosionCount = 0
local lastExplosionReset = 0

RegisterDetection('explosion_spam', {
    enabled = false, -- v4.2 FIX: DISABLED - Duplicate of spam.lua, this version uses IsExplosionInSphere which detects ALL explosions (including environmental) not player-caused ones
    punishment = 'kick',
    maxExplosions = 5,
    timeWindow = 5000,
    checkInterval = 500,
    tolerance = 1
}, function(config, state)
    local now = GetGameTimer()

    -- Reset counter periodically
    if now - lastExplosionReset > config.timeWindow then
        explosionCount = 0
        lastExplosionReset = now
    end

    -- Check for explosion near player
    local coords = GetEntityCoords(PlayerPedId())
    if IsExplosionInSphere(-1, coords.x, coords.y, coords.z, 50.0) then
        explosionCount = explosionCount + 1

        if explosionCount > config.maxExplosions then
            return true, { explosions = explosionCount }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. ANTI-VEHICLE SPAWN SPAM
-- ═══════════════════════════════════════════════════════════════════════════════

local vehicleSpawns = {}

RegisterDetection('vehicle_spawn_spam', {
    enabled = true,
    punishment = 'kick',
    maxSpawns = 5,
    timeWindow = 10000,
    checkInterval = 1000,
    tolerance = 1
}, function(config, state)
    local now = GetGameTimer()

    -- Limpiar spawns viejos
    for i = #vehicleSpawns, 1, -1 do
        if now - vehicleSpawns[i] > config.timeWindow then
            table.remove(vehicleSpawns, i)
        end
    end

    -- Verificar vehículos cercanos
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicles = GetGamePool('CVehicle')
    local nearbyCount = 0

    for _, veh in ipairs(vehicles) do
        local vehCoords = GetEntityCoords(veh)
        if #(coords - vehCoords) < 20.0 then
            nearbyCount = nearbyCount + 1
        end
    end

    -- Si hay muchos vehículos nuevos
    if nearbyCount > 10 then
        return true, { nearbyVehicles = nearbyCount }
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. ANTI-FREECAM / SPECTATE ABUSE
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('freecam_abuse', {
    enabled = true,
    punishment = 'warn',
    maxDistance = 500.0,
    checkInterval = 2000,
    tolerance = 3
}, function(config, state)
    local ped = PlayerPedId()
    local camCoords = GetGameplayCamCoord()
    local pedCoords = GetEntityCoords(ped)

    local dist = #(camCoords - pedCoords)

    -- Si la cámara está muy lejos del ped
    if dist > config.maxDistance then
        -- Verificar si no está en modo spectate legítimo
        if not LocalPlayer.state.spectating then
            return true, { cameraDistance = dist }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. ANTI-RAGDOLL ABUSE
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('ragdoll_disabled', {
    enabled = false, -- v4.2 FIX: DISABLED - Too many false positives! The game disables ragdoll in many legitimate situations:
    -- - During animations, tasks, and scenarios
    -- - When entering/exiting vehicles
    -- - During combat rolls and tactical movements  
    -- - When using specific weapons
    -- - During cutscenes and scripted events
    punishment = 'warn',
    checkInterval = 1000,
    tolerance = 5
}, function(config, state)
    local ped = PlayerPedId()

    -- Verificar si ragdoll está deshabilitado cuando debería estar habilitado
    if not CanPedRagdoll(ped) and not IsPedInAnyVehicle(ped, false) then
        -- No en vehículo pero ragdoll deshabilitado = sospechoso
        return true, { ragdollDisabled = true }
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 9. ANTI-THERMAL/NIGHT VISION ABUSE
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('vision_abuse', {
    enabled = false, -- Disabled by default (puede dar falsos positivos)
    punishment = 'warn',
    checkInterval = 5000,
    tolerance = 3
}, function(config, state)
    -- Verificar visión térmica/nocturna
    if GetUsingseethrough() or GetUsingnightvision() then
        -- Sin item/permiso legítimo
        if not LocalPlayer.state.hasNVG and not LocalPlayer.state.hasThermal then
            return true, { nightVision = GetUsingnightvision(), thermalVision = GetUsingseethrough() }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 10. ANTI-TASK ABUSE (Forcing tasks on other players)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('forced_animation', {
    enabled = true,
    punishment = 'warn',
    checkInterval = 500,
    tolerance = 5
}, function(config, state)
    local ped = PlayerPedId()

    -- Verificar si estamos en una animación forzada sin haberla iniciado nosotros
    if IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) or
        IsEntityPlayingAnim(ped, 'random@mugging3', 'handsup_standing_base', 3) or
        IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 3) then
        -- Verificar si fue forzado (no iniciado por el jugador)
        if not LocalPlayer.state.handsUp and not LocalPlayer.state.beingArrested then
            return true, { forcedAnimation = true }
        end
    end

    return false
end)

print('^2[LyxGuard]^7 Extended detections module loaded - 10 new detections')
