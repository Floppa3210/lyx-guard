--[[
    LyxGuard v4.1 - Advanced Combat Detection Module

    Concept Source: SecureServe
    Rewritten from scratch with LyxGuard architecture

    Features:
    - Magic bullet detection (LOS validation)
    - No recoil detection
    - Aimbot detection (camera stability)
    - Rapid fire detection
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. MAGIC BULLET DETECTION
-- Detects when bullets hit without line of sight
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('magic_bullet', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'long',
    tolerance = 3,
    checkAttempts = 4,
    delayBetweenChecks = 1500
}, function(config, state)
    -- This detection is event-based, not loop-based
    return false
end, 'periodic')

-- Store pending magic bullet checks
local MagicBulletChecks = {}

-- Listen for death events
AddEventHandler('gameEventTriggered', function(event, data)
    if event ~= 'CEventNetworkEntityDamage' then return end

    -- Skip if immune
    if Helpers and Helpers.IsPlayerImmune and Helpers.IsPlayerImmune() then return end

    local victim = data[1]
    local victimDied = data[4]

    if not IsPedAPlayer(victim) then return end

    local player = PlayerId()
    local playerPed = PlayerPedId()

    -- Check if we're the victim and died
    if victimDied and NetworkGetPlayerIndexFromPed(victim) == player then
        if IsPedDeadOrDying(victim, true) or IsPedFatallyInjured(victim) then
            local killerEntity = GetPedSourceOfDeath(playerPed)
            local killerPlayerId = NetworkGetPlayerIndexFromPed(killerEntity)

            -- Verify killer is a valid remote player
            if killerEntity ~= playerPed and killerPlayerId and NetworkIsPlayerActive(killerPlayerId) then
                local attackerPed = GetPlayerPed(killerPlayerId)

                -- Start async LOS validation
                CreateThread(function()
                    local noLosCount = 0
                    local config = GetDetectionConfig and GetDetectionConfig('magic_bullet') or
                    { checkAttempts = 4, tolerance = 3, delayBetweenChecks = 1500 }

                    for i = 1, config.checkAttempts do
                        -- Check multiple LOS methods
                        local hasLos1 = HasEntityClearLosToEntityInFront(attackerPed, victim)
                        local hasLos2 = HasEntityClearLosToEntity(attackerPed, victim, 17)

                        if not hasLos1 and not hasLos2 then
                            noLosCount = noLosCount + 1
                        end

                        Wait(config.delayBetweenChecks)
                    end

                    -- If most checks failed LOS, it's suspicious
                    if noLosCount >= config.tolerance then
                        TriggerServerEvent('lyxguard:detection', 'magic_bullet', {
                            attackerServerId = GetPlayerServerId(killerPlayerId),
                            noLosCount = noLosCount,
                            totalChecks = config.checkAttempts
                        }, GetEntityCoords(playerPed))
                    end
                end)
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. NO RECOIL DETECTION
-- Detects when weapon has no recoil during shooting
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('no_recoil', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'medium',
    tolerance = 3,
    graceAfterSpawn = 30000,
    checkInterval = 2500
}, function(config, state)
    -- Skip if immune
    if Helpers and Helpers.IsPlayerImmune and Helpers.IsPlayerImmune() then return false end

    -- Initialize spawn time
    if not state.data.spawnTime then
        state.data.spawnTime = GetGameTimer()
        return false
    end

    -- Grace period after spawn
    if GetGameTimer() - state.data.spawnTime < config.graceAfterSpawn then
        return false
    end

    local playerPed = PlayerPedId()
    local _, currentWeapon = GetCurrentPedWeapon(playerPed, true)

    -- Only check if shooting with a weapon
    if not currentWeapon or currentWeapon == GetHashKey('WEAPON_UNARMED') then
        return false
    end

    -- Skip if in vehicle or NUI focused
    if IsPedInAnyVehicle(playerPed, false) or IsNuiFocused() or IsPauseMenuActive() then
        return false
    end

    -- Only check when actively shooting
    if not IsPedShooting(playerPed) then
        return false
    end

    -- Get recoil amount
    local recoilAmount = GetWeaponRecoilShakeAmplitude(currentWeapon)
    local cameraPitch = GetGameplayCamRelativePitch()

    -- Suspicious: No recoil + camera perfectly stable while shooting
    if recoilAmount <= 0.0 and math.abs(cameraPitch) < 0.1 then
        state.data.suspiciousShots = (state.data.suspiciousShots or 0) + 1

        if state.data.suspiciousShots >= config.tolerance then
            state.data.suspiciousShots = 0
            return true, {
                weapon = currentWeapon,
                recoil = recoilAmount,
                cameraPitch = cameraPitch
            }
        end
    else
        -- Reset counter on normal behavior
        state.data.suspiciousShots = 0
    end

    return false
end, 'fast')

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. AIMBOT DETECTION
-- Detects unnatural aiming patterns
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('aimbot', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'long',
    tolerance = 5,
    maxSnapAngle = 60, -- Max degrees of instant aim change
    sampleInterval = 100,
    sampleCount = 10,
    checkInterval = 500
}, function(config, state)
    -- Skip if immune
    if Helpers and Helpers.IsPlayerImmune and Helpers.IsPlayerImmune() then return false end

    -- Initialize tracking
    if not state.data.aimHistory then
        state.data.aimHistory = {}
        state.data.suspiciousSnaps = 0
        return false
    end

    local playerPed = PlayerPedId()

    -- Only check when aiming
    if not IsPlayerFreeAiming(PlayerId()) then
        return false
    end

    -- Get current aim direction
    local camRot = GetGameplayCamRot(2)
    local currentYaw = camRot.z
    local currentPitch = camRot.x

    -- Store sample
    table.insert(state.data.aimHistory, {
        yaw = currentYaw,
        pitch = currentPitch,
        time = GetGameTimer()
    })

    -- Keep only recent samples
    while #state.data.aimHistory > config.sampleCount do
        table.remove(state.data.aimHistory, 1)
    end

    -- Need at least 2 samples to check
    if #state.data.aimHistory < 2 then
        return false
    end

    -- Check for snap aiming (instant large angle changes)
    local prevSample = state.data.aimHistory[#state.data.aimHistory - 1]
    local currSample = state.data.aimHistory[#state.data.aimHistory]

    local yawDelta = math.abs(currSample.yaw - prevSample.yaw)
    local pitchDelta = math.abs(currSample.pitch - prevSample.pitch)
    local timeDelta = currSample.time - prevSample.time

    -- Normalize yaw delta (handle 360 wrap)
    if yawDelta > 180 then yawDelta = 360 - yawDelta end

    -- Check for instant snap
    if timeDelta < 150 and (yawDelta > config.maxSnapAngle or pitchDelta > config.maxSnapAngle * 0.5) then
        state.data.suspiciousSnaps = state.data.suspiciousSnaps + 1

        if state.data.suspiciousSnaps >= config.tolerance then
            state.data.suspiciousSnaps = 0
            return true, {
                yawDelta = yawDelta,
                pitchDelta = pitchDelta,
                timeDelta = timeDelta
            }
        end
    end

    return false
end, 'fast')

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. RAPID FIRE DETECTION
-- Detects weapons firing faster than normal
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('rapid_fire', {
    enabled = true,
    punishment = 'kick',
    banDuration = 'short',
    tolerance = 5,
    minShotInterval = 50, -- Minimum ms between shots
    sampleWindow = 2000,  -- Window to track shots
    checkInterval = 100
}, function(config, state)
    -- Skip if immune
    if Helpers and Helpers.IsPlayerImmune and Helpers.IsPlayerImmune() then return false end

    local playerPed = PlayerPedId()

    -- Initialize tracking
    if not state.data.shotTimes then
        state.data.shotTimes = {}
        state.data.rapidFireCount = 0
        return false
    end

    -- Track shots
    if IsPedShooting(playerPed) then
        local now = GetGameTimer()
        table.insert(state.data.shotTimes, now)

        -- Clean old shots
        local cutoff = now - config.sampleWindow
        local newShots = {}
        for _, time in ipairs(state.data.shotTimes) do
            if time > cutoff then
                table.insert(newShots, time)
            end
        end
        state.data.shotTimes = newShots

        -- Check for rapid fire
        if #state.data.shotTimes >= 2 then
            local interval = state.data.shotTimes[#state.data.shotTimes] -
            state.data.shotTimes[#state.data.shotTimes - 1]

            if interval > 0 and interval < config.minShotInterval then
                state.data.rapidFireCount = state.data.rapidFireCount + 1

                if state.data.rapidFireCount >= config.tolerance then
                    state.data.rapidFireCount = 0
                    return true, {
                        shotInterval = interval,
                        shotsInWindow = #state.data.shotTimes
                    }
                end
            end
        end
    end

    return false
end, 'fast')

print('^2[LyxGuard]^7 Advanced combat detection module loaded (magic bullet, no recoil, aimbot, rapid fire)')
