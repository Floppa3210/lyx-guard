--[[
    LyxGuard v4.1 - Player State Detection Module

    Concept Source: SecureServe
    Rewritten from scratch with LyxGuard architecture

    Features:
    - God mode detection (health/armor tracking)
    - Invisibility detection
    - Super jump detection
    - Infinite stamina detection
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. GOD MODE DETECTION
-- Detects players who take no damage
-- ═══════════════════════════════════════════════════════════════════════════════

local GodModeState = {
    lastHealth = 0,
    lastArmor = 0,
    damageTakenCount = 0,
    noDamageCount = 0,
    healthHistory = {}
}

RegisterDetection('god_mode', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'long',
    tolerance = 5,
    maxHealth = 200,
    maxArmor = 100,
    checkInterval = 1000
}, function(config, state)
    -- Skip if immune
    if Helpers and Helpers.IsPlayerImmune and Helpers.IsPlayerImmune() then return false end

    local playerPed = PlayerPedId()
    local currentHealth = GetEntityHealth(playerPed)
    local currentArmor = GetPedArmour(playerPed)

    -- Initialize
    if GodModeState.lastHealth == 0 then
        GodModeState.lastHealth = currentHealth
        GodModeState.lastArmor = currentArmor
        return false
    end

    -- Skip if dead
    if IsEntityDead(playerPed) then
        GodModeState.lastHealth = 0
        GodModeState.lastArmor = 0
        return false
    end

    local suspicious = false
    local details = {}

    -- Check 1: Health above max
    if currentHealth > config.maxHealth then
        suspicious = true
        details.reason = 'health_above_max'
        details.health = currentHealth
        details.max = config.maxHealth
    end

    -- Check 2: Armor above max
    if currentArmor > config.maxArmor then
        suspicious = true
        details.reason = 'armor_above_max'
        details.armor = currentArmor
        details.max = config.maxArmor
    end

    -- Check 3: Track damage events
    -- If health decreased, player took damage
    if currentHealth < GodModeState.lastHealth then
        GodModeState.damageTakenCount = GodModeState.damageTakenCount + 1
        GodModeState.noDamageCount = 0
    else
        -- Health stayed same or increased
        GodModeState.noDamageCount = GodModeState.noDamageCount + 1
    end

    -- Check 4: Suspicious instant healing
    if currentHealth > GodModeState.lastHealth + 20 then
        local healAmount = currentHealth - GodModeState.lastHealth
        -- Store for pattern analysis
        table.insert(GodModeState.healthHistory, {
            time = GetGameTimer(),
            heal = healAmount
        })

        -- Clean old entries
        local now = GetGameTimer()
        for i = #GodModeState.healthHistory, 1, -1 do
            if now - GodModeState.healthHistory[i].time > 10000 then
                table.remove(GodModeState.healthHistory, i)
            end
        end

        -- Multiple rapid heals = suspicious
        if #GodModeState.healthHistory >= 3 then
            suspicious = true
            details.reason = 'rapid_healing'
            details.healEvents = #GodModeState.healthHistory
        end
    end

    GodModeState.lastHealth = currentHealth
    GodModeState.lastArmor = currentArmor

    if suspicious then
        return true, details
    end

    return false
end, 'periodic')

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. INVISIBILITY DETECTION
-- Detects players who made themselves invisible
-- ═══════════════════════════════════════════════════════════════════════════════

local InvisibleState = {
    invisibleCount = 0
}

RegisterDetection('invisible', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'medium',
    tolerance = 3,
    minAlpha = 50,
    checkInterval = 3000
}, function(config, state)
    -- Skip if immune
    if Helpers and Helpers.IsPlayerImmune and Helpers.IsPlayerImmune() then return false end

    local playerPed = PlayerPedId()
    local isVisible = IsEntityVisible(playerPed)
    local alpha = GetEntityAlpha(playerPed)

    local suspicious = false
    local details = {}

    -- Check 1: Entity not visible
    if not isVisible then
        InvisibleState.invisibleCount = InvisibleState.invisibleCount + 1

        if InvisibleState.invisibleCount >= config.tolerance then
            suspicious = true
            details.reason = 'persistent_invisible'
            details.count = InvisibleState.invisibleCount
        end
    else
        InvisibleState.invisibleCount = 0
    end

    -- Check 2: Alpha too low
    if alpha < config.minAlpha then
        suspicious = true
        details.reason = 'low_alpha'
        details.alpha = alpha
    end

    -- Check 3: No physics (ghost mode)
    if not DoesEntityHavePhysics(playerPed) then
        suspicious = true
        details.reason = 'no_physics'
    end

    if suspicious then
        return true, details
    end

    return false
end, 'periodic')

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2b. INVISIBLE VEHICLE DETECTION
-- La deteccion 'invisible' de arriba solo mira el PED. Los cheats de "vehiculo
-- invisible" ocultan el vehiculo ocupado (visible=false o alpha bajo) mientras el
-- jugador conduce. Aqui verificamos el vehiculo en si.
-- ═══════════════════════════════════════════════════════════════════════════════

local InvisibleVehicleState = {
    count = 0
}

RegisterDetection('vehicle_invisible', {
    enabled = true,
    punishment = 'warn',
    banDuration = 'medium',
    tolerance = 3,
    minAlpha = 50,
    checkInterval = 3000
}, function(config, state)
    if Helpers and Helpers.IsPlayerImmune and Helpers.IsPlayerImmune() then return false end

    -- Admin/spectate legitimo.
    if LocalPlayer.state.isSpectating or LocalPlayer.state.adminInvisible then
        InvisibleVehicleState.count = 0
        return false
    end

    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        InvisibleVehicleState.count = 0
        return false
    end

    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        InvisibleVehicleState.count = 0
        return false
    end

    local isVisible = IsEntityVisible(veh)
    local alpha = GetEntityAlpha(veh)

    -- Solo el conductor puede ocultar su propio vehiculo con este cheat; evitar
    -- falsos positivos de vehiculos de otros aun no renderizados.
    local isDriver = GetPedInVehicleSeat(veh, -1) == ped

    if isDriver and ((not isVisible) or (alpha > 0 and alpha < (config.minAlpha or 50))) then
        InvisibleVehicleState.count = InvisibleVehicleState.count + 1
        if InvisibleVehicleState.count >= (config.tolerance or 3) then
            InvisibleVehicleState.count = 0
            return true, {
                type = 'VEHICLE_INVISIBLE',
                visible = isVisible,
                alpha = alpha,
                vehicleModel = GetEntityModel(veh)
            }
        end
    else
        InvisibleVehicleState.count = 0
    end

    return false
end, 'periodic')

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. SUPER JUMP DETECTION
-- (unificado) La deteccion 'super_jump'/'superjump' vive en
-- client/detections/misc.lua ('superjump'). Se elimino el registro duplicado
-- que existia aqui para evitar doble ejecucion del mismo tipo de deteccion.
-- ═══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. INFINITE STAMINA DETECTION
-- Detects players who never get tired
-- ═══════════════════════════════════════════════════════════════════════════════

local StaminaState = {
    fullStaminaTime = 0,
    isRunning = false
}

RegisterDetection('infinite_stamina', {
    enabled = true,
    punishment = 'notify',
    banDuration = 'short',
    tolerance = 3,
    maxFullStaminaRunTime = 30000, -- 30 seconds of running with full stamina
    checkInterval = 1000
}, function(config, state)
    -- Skip if immune
    if Helpers and Helpers.IsPlayerImmune and Helpers.IsPlayerImmune() then return false end

    local playerPed = PlayerPedId()
    local stamina = GetPlayerSprintStaminaRemaining(PlayerId())
    local isRunning = IsPedRunning(playerPed) or IsPedSprinting(playerPed)
    local isInVehicle = IsPedInAnyVehicle(playerPed, false)

    -- Skip if in vehicle
    if isInVehicle then
        StaminaState.fullStaminaTime = 0
        return false
    end

    -- Track running with full stamina
    if isRunning and stamina >= 99.0 then
        if StaminaState.fullStaminaTime == 0 then
            StaminaState.fullStaminaTime = GetGameTimer()
        end

        local runDuration = GetGameTimer() - StaminaState.fullStaminaTime

        if runDuration > config.maxFullStaminaRunTime then
            StaminaState.fullStaminaTime = GetGameTimer() -- Reset
            return true, {
                runDuration = runDuration,
                stamina = stamina
            }
        end
    else
        -- Reset if not running or stamina decreased
        StaminaState.fullStaminaTime = 0
    end

    return false
end, 'periodic')

print('^2[LyxGuard]^7 Player state detection module loaded (god mode, invisible, super jump, stamina)')
