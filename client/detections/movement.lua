--[[
    LyxGuard v4.0 - Movement Detections Module

    Este archivo contiene todas las detecciones de movimiento.
    Cada detección se registra con RegisterDetection() del core.
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. ANTI-TELEPORT
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('teleport', {
    enabled = true,
    punishment = 'notify',
    banDuration = 'medium',
    maxDistance = 150.0,
    checkInterval = 100,
    tolerance = 3 -- Aumentado para evitar falsos positivos
}, function(config, state)
    -- Skip if player is immune (admin/staff)
    if Helpers.IsPlayerImmune() then return false end

    -- Skip during screen transitions, loading, etc
    if Helpers.IsInGracePeriod() or Helpers.IsScreenFaded() then return false end

    -- Skip during player switch (loading, respawn, etc)
    if IsPlayerSwitchInProgress() then return false end

    -- Skip if in cutscene or dead
    if IsCutsceneActive() or Helpers.IsPlayerDead() then return false end

    -- Skip if player was just spawned/respawned (grace period extended check)
    if not state.data.initialized then
        state.data.initialized = true
        state.data.lastCheck = GetGameTimer()
        return false
    end

    local dist = Helpers.GetDistanceFromLast()
    local dt = (GetGameTimer() - (state.data.lastCheck or 0)) / 1000

    state.data.lastCheck = GetGameTimer()

    -- Only flag if distance is abnormal and time is too short
    if dist > config.maxDistance and dt < 0.5 then
        -- Extra checks for false positives
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        -- Skip if just entered/exited vehicle
        if veh ~= 0 or GetVehiclePedIsEntering(ped) ~= 0 then
            return false
        end

        -- Skip if was ragdolled (can teleport due to physics)
        if IsPedRagdoll(ped) then
            return false
        end

        return true, { distance = dist, deltaTime = dt }
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. ANTI-NOCLIP (ENHANCED)
-- Detección mejorada de noclip con múltiples métodos
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('noclip', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'long',
    tolerance = 5,             -- Más tolerancia para evitar falsos positivos
    minHeight = 3.0,           -- Altura mínima para considerar flotando
    checkInterval = 200,       -- Check cada 200ms
    wallPhaseThreshold = 3,    -- Cantidad de wall phases antes de detectar
    maxHorizontalSpeed = 25.0, -- Velocidad horizontal máxima sospechosa sin vehículo
}, function(config, state)
    -- Inicializar estado
    if not state.data.initialized then
        state.data.initialized = true
        state.data.lastPos = GetEntityCoords(PlayerPedId())
        state.data.floatCount = 0
        state.data.wallPhaseCount = 0
        state.data.noCollisionCount = 0
        return false
    end

    -- Skip si es admin/staff
    if Helpers.IsPlayerImmune() then
        state.data.floatCount = 0
        return false
    end

    -- Skip durante transiciones
    if Helpers.IsInGracePeriod() or Helpers.IsScreenFaded() then return false end
    if IsPlayerSwitchInProgress() then return false end
    if IsCutsceneActive() or Helpers.IsPlayerDead() then return false end

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local vel = GetEntityVelocity(ped)

    -- Skip si está en vehículo, cayendo, con paracaídas, o escalando
    if Helpers.IsInVehicle() then return false end
    if Helpers.IsFalling() then
        state.data.floatCount = 0
        return false
    end
    if Helpers.HasParachute() then return false end
    if IsPedClimbing(ped) or IsPedVaulting(ped) then return false end
    if IsPedRagdoll(ped) then return false end
    if IsPedInParachuteFreeFall(ped) then return false end

    -- Skip si está en agua
    if IsEntityInWater(ped) then return false end

    local detected = false
    local details = {}

    -- ═══════════════════════════════════════════════════════════════════════════
    -- MÉTODO 1: Flotando en el aire sin movimiento vertical
    -- ═══════════════════════════════════════════════════════════════════════════
    local height = Helpers.GetHeightAboveGround()
    local absVelZ = math.abs(vel.z)

    if height > config.minHeight and absVelZ < 2.0 then
        -- Está flotando sin caer ni subir normalmente
        state.data.floatCount = (state.data.floatCount or 0) + 1

        if state.data.floatCount >= 10 then -- 2 segundos flotando
            detected = true
            details.method = 'floating'
            details.height = height
            details.velocityZ = vel.z
            details.floatDuration = state.data.floatCount * config.checkInterval
        end
    else
        state.data.floatCount = math.max(0, (state.data.floatCount or 0) - 1)
    end

    -- ═══════════════════════════════════════════════════════════════════════════
    -- MÉTODO 2: Atravesando paredes (wall phasing)
    -- ═══════════════════════════════════════════════════════════════════════════
    if not detected then
        local lastPos = state.data.lastPos
        local dist = #(pos - lastPos)

        -- Si se movió significativamente
        if dist > 5.0 then
            local direction = (pos - lastPos) / dist

            -- Hacer raycast para verificar si atravesó algo sólido
            local rayHandle = StartShapeTestRay(
                lastPos.x, lastPos.y, lastPos.z,
                pos.x, pos.y, pos.z,
                1, -- Colisión con mundo
                ped,
                7
            )
            local _, hit, hitPos, _, _ = GetShapeTestResult(rayHandle)

            if hit then
                -- Verificar si el jugador pasó a través del hit point
                local distToHit = #(hitPos - lastPos)
                if distToHit < dist - 1.0 then
                    state.data.wallPhaseCount = (state.data.wallPhaseCount or 0) + 1

                    if state.data.wallPhaseCount >= config.wallPhaseThreshold then
                        detected = true
                        details.method = 'wall_phasing'
                        details.distance = dist
                        details.phaseCount = state.data.wallPhaseCount
                    end
                end
            else
                state.data.wallPhaseCount = math.max(0, (state.data.wallPhaseCount or 0) - 1)
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════════════════════
    -- MÉTODO 3: Velocidad horizontal anormal sin vehículo
    -- ═══════════════════════════════════════════════════════════════════════════
    if not detected then
        local horizontalSpeed = math.sqrt(vel.x * vel.x + vel.y * vel.y)

        -- Velocidad muy alta sin estar en vehículo
        if horizontalSpeed > config.maxHorizontalSpeed and not IsPedSprinting(ped) then
            state.data.highSpeedCount = (state.data.highSpeedCount or 0) + 1

            if state.data.highSpeedCount >= 5 then
                detected = true
                details.method = 'high_speed_flight'
                details.speed = horizontalSpeed
            end
        else
            state.data.highSpeedCount = math.max(0, (state.data.highSpeedCount or 0) - 1)
        end
    end

    -- ═══════════════════════════════════════════════════════════════════════════
    -- MÉTODO 4: Sin colisión activa (noclip típico desactiva colisiones)
    -- ═══════════════════════════════════════════════════════════════════════════
    if not detected then
        -- Verificar si el ped tiene colisión deshabilitada
        local hasCollision = not GetEntityCollisionDisabled(ped)

        if not hasCollision then
            state.data.noCollisionCount = (state.data.noCollisionCount or 0) + 1

            if state.data.noCollisionCount >= 10 then
                detected = true
                details.method = 'collision_disabled'
                details.noCollisionDuration = state.data.noCollisionCount * config.checkInterval
            end
        else
            state.data.noCollisionCount = 0
        end
    end

    -- Actualizar posición anterior
    state.data.lastPos = pos

    if detected then
        -- Reset counters on detection
        state.data.floatCount = 0
        state.data.wallPhaseCount = 0
        state.data.highSpeedCount = 0
        state.data.noCollisionCount = 0
        return true, details
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. ANTI-SPEEDHACK (ADJUSTED FOR LESS FALSE POSITIVES)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('speedhack', {
    enabled = true,
    punishment = 'warn', -- Changed from kick to warn - less aggressive
    banDuration = 'medium',
    tolerance = 15,      -- Increased tolerance significantly
    maxSpeeds = {
        onFoot = 25.0,   -- Increased from 12 - can run fast
        running = 35.0,  -- Increased from 18 - sprinting can be boosted by scripts
        swimming = 15.0, -- Increased from 8
        vehicle = 500.0, -- Increased for fast vehicles
        ragdoll = 100.0  -- NEW: High speed allowed during ragdoll
    }
}, function(config, state)
    -- Skip if immune
    if Helpers.IsPlayerImmune() then return false end

    local speed = Helpers.GetPlayerSpeed()
    local ped = PlayerPedId()

    -- SKIP DETECTION IF RAGDOLL (being thrown by collision)
    if IsPedRagdoll(ped) then
        return false
    end

    -- Skip if falling
    if IsPedFalling(ped) then
        return false
    end

    -- Skip if was recently ragdolled (give 3 second grace period)
    if not state.data.lastRagdollCheck then
        state.data.lastRagdollCheck = 0
        state.data.wasRagdoll = false
    end

    if IsPedRagdoll(ped) then
        state.data.wasRagdoll = true
        state.data.lastRagdollCheck = GetGameTimer()
    end

    -- Grace period after ragdoll
    if state.data.wasRagdoll and (GetGameTimer() - state.data.lastRagdollCheck) < 3000 then
        return false
    else
        state.data.wasRagdoll = false
    end

    -- Skip if in vehicle - let vehicle speed check handle it
    if Helpers.IsInVehicle() then
        if speed > config.maxSpeeds.vehicle then
            return true, { speed = speed, maxAllowed = config.maxSpeeds.vehicle, context = 'vehicle' }
        end
        return false
    end

    local maxSpeed = config.maxSpeeds.onFoot
    if IsPedSprinting(ped) then
        maxSpeed = config.maxSpeeds.running
    elseif IsPedSwimming(ped) then
        maxSpeed = config.maxSpeeds.swimming
    end

    if speed > maxSpeed then
        -- Additional check: need multiple consecutive detections
        state.data.speedViolations = (state.data.speedViolations or 0) + 1

        if state.data.speedViolations >= config.tolerance then
            state.data.speedViolations = 0
            return true, { speed = speed, maxAllowed = maxSpeed }
        end
        return false
    else
        -- Reset counter if speed is normal
        state.data.speedViolations = math.max(0, (state.data.speedViolations or 0) - 1)
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. ANTI-SUPERJUMP
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('superjump', {
    enabled = true,
    punishment = 'teleport',
    banDuration = 'short',
    tolerance = 3,
    maxJumpVelocity = 8.0
}, function(config, state)
    local ped = PlayerPedId()

    if IsPedJumping(ped) then
        local velZ = GetEntityVelocity(ped).z
        if velZ > config.maxJumpVelocity then
            return true, { velocityZ = velZ }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. ANTI-FLYHACK
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('flyhack', {
    enabled = true,
    punishment = 'warn',
    banDuration = 'long',
    tolerance = 1,
    maxAirTime = 10000
}, function(config, state)
    state.data.airTime = state.data.airTime or 0

    local ped = PlayerPedId()
    local onGround = Helpers.IsOnGround()
    local inVehicle = Helpers.IsInVehicle()
    local hasParachute = Helpers.HasParachute()

    if not onGround and not inVehicle and not hasParachute then
        state.data.airTime = state.data.airTime + 100
        if state.data.airTime > config.maxAirTime then
            local result = true
            state.data.airTime = 0
            return result, { airTime = state.data.airTime }
        end
    else
        state.data.airTime = 0
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. ANTI-UNDERGROUND
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('underground', {
    enabled = true,
    punishment = 'teleport',
    banDuration = 'short',
    tolerance = 1,
    minZ = -50.0
}, function(config, state)
    local pos = GetEntityCoords(PlayerPedId())

    if pos.z < config.minZ then
        return true, { z = pos.z }
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. ANTI-WALLBREACH
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('wallbreach', {
    enabled = false, -- v4.1 HOTFIX: DISABLED - causing massive false positives
    punishment = 'teleport',
    banDuration = 'medium',
    tolerance = 2
}, function(config, state)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)

    -- Verificar si está dentro de un objeto sólido
    local rayHandle = StartShapeTestCapsule(pos.x, pos.y, pos.z + 0.5, pos.x, pos.y, pos.z - 0.5, 0.3, 1, ped, 7)
    local _, hit, _, _, _ = GetShapeTestResult(rayHandle)

    if hit and not Helpers.IsInVehicle() then
        -- Posiblemente dentro de una pared
        return true, { position = pos }
    end

    return false
end)
