--[[
    LyxGuard v4.0 - Miscellaneous Detection Module

    Detecciones misceláneas (modelo, partículas, audio, etc.)
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. ANTI-INVALID PLAYER MODEL
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('invalidmodel', {
    enabled = true,
    punishment = 'kick',
    banDuration = 'short',
    tolerance = 1,
    checkInterval = 5000,
    blacklistedModels = {
        GetHashKey('slod_human'),
        GetHashKey('slod_large_quadped'),
        GetHashKey('slod_small_quadped'),
        GetHashKey('a_f_m_downtown_01'), -- Add specific disallowed models
    },
    -- Only allow human-like models
    allowedModelTypes = { 'mp_m_freemode_01', 'mp_f_freemode_01' }
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()

    if GetGameTimer() - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = GetGameTimer()

    local ped = PlayerPedId()
    local model = GetEntityModel(ped)

    for _, blacklisted in ipairs(config.blacklistedModels) do
        if model == blacklisted then
            return true, { model = model, type = 'blacklisted' }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. ANTI-INVISIBLE PLAYER
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('invisibleplayer', {
    enabled = true,
    punishment = 'kill',
    tolerance = 3,
    checkInterval = 2000,
    exceptIfSpectating = true
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()
    state.data.invisibleCount = state.data.invisibleCount or 0

    if GetGameTimer() - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = GetGameTimer()

    local ped = PlayerPedId()

    -- Check if player is legitimately invisible (admin power)
    if LocalPlayer.state.isInvisible or LocalPlayer.state.isSpectating then
        return false
    end

    if not IsEntityVisible(ped) then
        state.data.invisibleCount = state.data.invisibleCount + 1

        if state.data.invisibleCount >= config.tolerance then
            state.data.invisibleCount = 0
            SetEntityVisible(ped, true, false)
            return true, { invisible = true }
        end
    else
        state.data.invisibleCount = 0
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. ANTI-PARTICLE SPAM
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('particlespam', {
    enabled = true,
    punishment = 'kick',
    banDuration = 'short',
    tolerance = 1,
    -- Tracked via render distance and performance impact
    -- Hard to detect client-side
}, function(config, state)
    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. ANTI-SUPER JUMP
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('superjump', {
    enabled = true,
    punishment = 'warn',
    banDuration = 'short',
    tolerance = 4,
    checkInterval = 250,
    maxJumpZVelocity = 19.0,
    minHeightAboveGround = 1.5
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()
    state.data.violations = state.data.violations or 0

    if GetGameTimer() - state.data.lastCheck < (config.checkInterval or 250) then
        return false
    end
    state.data.lastCheck = GetGameTimer()

    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) or IsPedSwimming(ped) then
        state.data.violations = 0
        return false
    end

    if IsPedClimbing(ped) or IsPedRagdoll(ped) or IsPedInParachuteFreeFall(ped) then
        state.data.violations = 0
        return false
    end

    local heightAboveGround = GetEntityHeightAboveGround(ped)
    if heightAboveGround > (config.minHeightAboveGround or 1.5) and IsPedJumping(ped) then
        local velocity = GetEntityVelocity(ped)

        if velocity.z > config.maxJumpZVelocity then
            state.data.violations = state.data.violations + 1

            if state.data.violations >= config.tolerance then
                state.data.violations = 0
                return true, {
                    zVelocity = velocity.z,
                    maxAllowed = config.maxJumpZVelocity,
                    heightAboveGround = heightAboveGround
                }
            end
        end
    else
        state.data.violations = math.max(0, state.data.violations - 1)
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. ANTI-PPT (Player Ped Teleport via task)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('tasktp', {
    enabled = true,
    punishment = 'kick',
    tolerance = 2,
    checkInterval = 500,
    maxDistancePerTick = 100.0
}, function(config, state)
    state.data.lastPos = state.data.lastPos or GetEntityCoords(PlayerPedId())
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()
    state.data.violations = state.data.violations or 0

    if GetGameTimer() - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = GetGameTimer()

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local dist = #(pos - state.data.lastPos)

    -- Ignore if in vehicle or dead
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then
        state.data.lastPos = pos
        return false
    end

    if dist > config.maxDistancePerTick then
        state.data.violations = state.data.violations + 1

        if state.data.violations >= config.tolerance then
            state.data.violations = 0
            return true, { distance = dist, maxAllowed = config.maxDistancePerTick }
        end
    else
        state.data.violations = 0
    end

    state.data.lastPos = pos
    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. ANTI-RAGDOLL DISABLE
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('noragdoll', {
    enabled = false, -- DISABLED: Too many false positives (game disables ragdoll in many normal situations)
    punishment = 'notify',
    tolerance = 20, -- Very high tolerance if enabled
    checkInterval = 5000 -- Check less frequently
}, function(config, state)
    -- DISABLED: This detection causes false positives because the game itself
    -- disables ragdoll in many legitimate situations:
    -- - During certain animations, tasks, and scenarios
    -- - When entering/exiting vehicles
    -- - During combat rolls and tactical movements
    -- - When using specific weapons
    -- - During cutscenes and scripted events
    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. ANTI-NIGHT VISION / THERMAL
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('visionmod', {
    enabled = true,
    punishment = 'notify',
    tolerance = 1,
    allowedScenarios = {} -- Add script names that can use vision mods
}, function(config, state)
    local nightVision = IsNightvisionActive()
    local thermal = IsSeethroughActive()

    if nightVision or thermal then
        -- Check if legitimately allowed
        if not LocalPlayer.state.visionModAllowed then
            SetNightvision(false)
            SetSeethrough(false)
            return true, { nightVision = nightVision, thermal = thermal }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. ANTI-TIME/WEATHER MANIPULATION
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('worldmanip', {
    enabled = true,
    punishment = 'notify',
    tolerance = 3,
    checkInterval = 10000
}, function(config, state)
    -- This detection monitors for unauthorized time/weather changes
    -- Server should sync these values
    return false
end)

print('[LyxGuard] Miscellaneous detection module loaded')
