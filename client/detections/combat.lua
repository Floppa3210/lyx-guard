--[[
    LyxGuard v4.0 - Combat Detections Module

    Detecciones relacionadas con combate y daño.
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. ANTI-GODMODE
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('godmode', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'long',
    tolerance = 2,
    damageThreshold = 300, -- Daño acumulado para verificar
    checkInterval = 3000,  -- Verificar cada 3 segundos
    minDamageEvents = 5    -- Mínimo de eventos de daño
}, function(config, state)
    state.data.damageEvents = state.data.damageEvents or {}
    state.data.lastHealth = state.data.lastHealth or GetEntityHealth(PlayerPedId())
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()

    local ped = PlayerPedId()
    local health = GetEntityHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    local armor = GetPedArmour(ped)
    local now = GetGameTimer()

    -- Registrar evento de daño
    local dmg = state.data.lastHealth - health
    if dmg > 0 then
        table.insert(state.data.damageEvents, {
            damage = dmg,
            time = now,
            healthAfter = health
        })
    end

    -- Limpiar eventos viejos (más de 10 segundos)
    local recentEvents = {}
    for _, event in ipairs(state.data.damageEvents) do
        if now - event.time < 10000 then
            table.insert(recentEvents, event)
        end
    end
    state.data.damageEvents = recentEvents

    -- Verificar cada intervalo
    if now - state.data.lastCheck > config.checkInterval then
        state.data.lastCheck = now

        -- Calcular daño total reciente
        local totalDamage = 0
        for _, event in ipairs(state.data.damageEvents) do
            totalDamage = totalDamage + event.damage
        end

        -- Si recibió mucho daño pero sigue con vida alta
        if totalDamage > config.damageThreshold and #state.data.damageEvents >= config.minDamageEvents then
            -- Verificar que tiene vida casi completa
            if health >= maxHealth - 20 then
                -- CONFIRMADO: Godmode
                state.data.damageEvents = {}
                return true, {
                    damageReceived = totalDamage,
                    currentHealth = health,
                    maxHealth = maxHealth,
                    events = #state.data.damageEvents,
                    type = 'GODMODE_CONFIRMED'
                }
            end
        end
    end

    -- Si la salud subió sin razón (regeneración sospechosa)
    if health > state.data.lastHealth + 30 then
        -- Ignorar si el jugador estaba muerto y revivió
        if not IsEntityDead(ped) and state.data.lastHealth > 0 then
            -- Verificar que no haya sido un heal de admin
            local timeSinceLastDamage = 0
            if #state.data.damageEvents > 0 then
                timeSinceLastDamage = now - state.data.damageEvents[#state.data.damageEvents].time
            end

            -- Si se curó muy rápido después de daño = sospechoso
            if timeSinceLastDamage < 2000 and timeSinceLastDamage > 0 then
                return true, {
                    healthGained = health - state.data.lastHealth,
                    timeSinceDamage = timeSinceLastDamage,
                    type = 'INSTANT_HEAL'
                }
            end
        end
    end

    state.data.lastHealth = health
    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. ANTI-HEALTHHACK
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('healthhack', {
    enabled = true,
    punishment = 'kill',
    banDuration = 'medium',
    tolerance = 1,
    maxHealth = 200,
    buffer = 50
}, function(config, state)
    local health = GetEntityHealth(PlayerPedId())

    if health > config.maxHealth + config.buffer then
        return true, { health = health, maxAllowed = config.maxHealth }
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. ANTI-ARMORHACK
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('armorhack', {
    enabled = true,
    punishment = 'kill',
    banDuration = 'medium',
    tolerance = 1,
    maxArmor = 100,
    buffer = 10
}, function(config, state)
    local armor = GetPedArmour(PlayerPedId())

    if armor > config.maxArmor + config.buffer then
        return true, { armor = armor, maxAllowed = config.maxArmor }
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. ANTI-RAPIDFIRE (Placeholder - requiere tracking de disparos)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('rapidfire', {
    enabled = true,
    punishment = 'kick',
    banDuration = 'medium',
    tolerance = 3,
    minFireDelay = 0.05
}, function(config, state)
    state.data.lastShot = state.data.lastShot or 0
    state.data.rapidCount = state.data.rapidCount or 0

    if IsPedShooting(PlayerPedId()) then
        local now = GetGameTimer() / 1000
        local delay = now - state.data.lastShot

        if delay < config.minFireDelay and delay > 0 then
            state.data.rapidCount = state.data.rapidCount + 1
            if state.data.rapidCount >= config.tolerance then
                state.data.rapidCount = 0
                return true, { fireDelay = delay }
            end
        else
            state.data.rapidCount = 0
        end

        state.data.lastShot = now
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. ANTI-INFINITEAMMO
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('infiniteammo', {
    enabled = true,
    punishment = 'kick',
    banDuration = 'medium',
    tolerance = 5,
    shotsBeforeCheck = 30
}, function(config, state)
    state.data.shotsFired = state.data.shotsFired or 0
    state.data.lastAmmo = state.data.lastAmmo or -1

    local ped = PlayerPedId()
    local _, weapon = GetCurrentPedWeapon(ped, true)

    if weapon ~= GetHashKey('WEAPON_UNARMED') then
        local ammo = GetAmmoInPedWeapon(ped, weapon)

        if IsPedShooting(ped) then
            state.data.shotsFired = state.data.shotsFired + 1
        end

        if state.data.shotsFired >= config.shotsBeforeCheck then
            if ammo >= state.data.lastAmmo and state.data.lastAmmo > 0 then
                -- Disparó muchas veces pero la munición no bajó
                state.data.shotsFired = 0
                return true, { shots = state.data.shotsFired, ammo = ammo }
            end
            state.data.shotsFired = 0
        end

        state.data.lastAmmo = ammo
    end

    return false
end)
