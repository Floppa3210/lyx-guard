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
-- 3. SUPER JUMP DETECTION
-- Detects abnormally high jumps
-- ═══════════════════════════════════════════════════════════════════════════════

local JumpState = {
    jumpStartZ = 0,
    isJumping = false,
    maxJumpHeight = 0,
    jumpCount = 0
}

RegisterDetection('super_jump', {
    enabled = true,
    punishment = 'kick',
    banDuration = 'short',
    tolerance = 3,
    maxJumpHeight = 3.5, -- Normal jump is about 1-2 units
    checkInterval = 100
}, function(config, state)
    -- Skip if immune
    if Helpers and Helpers.IsPlayerImmune and Helpers.IsPlayerImmune() then return false end

    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)
    local isInAir = IsEntityInAir(playerPed)
    local isInVehicle = IsPedInAnyVehicle(playerPed, false)
    local isParachuting = GetPedParachuteState(playerPed) ~= -1

    -- Skip if in vehicle or parachuting
    if isInVehicle or isParachuting then
        JumpState.isJumping = false
        return false
    end

    -- Detect jump start
    if isInAir and not JumpState.isJumping then
        JumpState.isJumping = true
        JumpState.jumpStartZ = playerPos.z
        JumpState.maxJumpHeight = 0
    end

    -- Track max height during jump
    if JumpState.isJumping then
        local currentHeight = playerPos.z - JumpState.jumpStartZ
        if currentHeight > JumpState.maxJumpHeight then
            JumpState.maxJumpHeight = currentHeight
        end
    end

    -- Detect jump end
    if not isInAir and JumpState.isJumping then
        JumpState.isJumping = false

        -- Check if jump was abnormally high
        if JumpState.maxJumpHeight > config.maxJumpHeight then
            JumpState.jumpCount = JumpState.jumpCount + 1

            if JumpState.jumpCount >= config.tolerance then
                JumpState.jumpCount = 0
                return true, {
                    height = JumpState.maxJumpHeight,
                    maxAllowed = config.maxJumpHeight
                }
            end
        else
            -- Reset counter on normal jump
            JumpState.jumpCount = math.max(0, JumpState.jumpCount - 1)
        end
    end

    return false
end, 'fast')

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
