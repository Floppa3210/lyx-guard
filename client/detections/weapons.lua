--[[
    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║                    LYXGUARD v4.0 - WEAPON DETECTION ULTRA                     ║
    ║                    Detecciones de cheats de armas avanzadas                   ║
    ╠═══════════════════════════════════════════════════════════════════════════════╣
    ║  • Infinite Ammo (munición infinita)                                          ║
    ║  • Rapid Fire (disparo ultra-rápido)                                          ║
    ║  • Fast Reload (recarga instantánea)                                          ║
    ║  • No Spread (sin dispersión)                                                 ║
    ║  • No Recoil (sin retroceso)                                                  ║
    ║  • One-shot kill                                                              ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝
]]

-- Datos de armas para validación
local WeaponData = {
    -- Pistolas (tiempo mínimo entre disparos en ms)
    [GetHashKey('WEAPON_PISTOL')] = { minFireDelay = 150, magazineSize = 12, reloadTime = 1500 },
    [GetHashKey('WEAPON_COMBATPISTOL')] = { minFireDelay = 140, magazineSize = 12, reloadTime = 1400 },
    [GetHashKey('WEAPON_APPISTOL')] = { minFireDelay = 80, magazineSize = 18, reloadTime = 1200 },
    [GetHashKey('WEAPON_PISTOL50')] = { minFireDelay = 200, magazineSize = 9, reloadTime = 1600 },
    [GetHashKey('WEAPON_HEAVYPISTOL')] = { minFireDelay = 180, magazineSize = 18, reloadTime = 1500 },

    -- SMGs
    [GetHashKey('WEAPON_MICROSMG')] = { minFireDelay = 50, magazineSize = 16, reloadTime = 2000 },
    [GetHashKey('WEAPON_SMG')] = { minFireDelay = 60, magazineSize = 30, reloadTime = 2200 },
    [GetHashKey('WEAPON_ASSAULTSMG')] = { minFireDelay = 55, magazineSize = 30, reloadTime = 2000 },
    [GetHashKey('WEAPON_COMBATPDW')] = { minFireDelay = 55, magazineSize = 30, reloadTime = 2100 },

    -- Assault Rifles
    [GetHashKey('WEAPON_ASSAULTRIFLE')] = { minFireDelay = 80, magazineSize = 30, reloadTime = 2500 },
    [GetHashKey('WEAPON_CARBINERIFLE')] = { minFireDelay = 75, magazineSize = 30, reloadTime = 2400 },
    [GetHashKey('WEAPON_ADVANCEDRIFLE')] = { minFireDelay = 70, magazineSize = 30, reloadTime = 2300 },
    [GetHashKey('WEAPON_SPECIALCARBINE')] = { minFireDelay = 75, magazineSize = 30, reloadTime = 2400 },
    [GetHashKey('WEAPON_BULLPUPRIFLE')] = { minFireDelay = 75, magazineSize = 30, reloadTime = 2400 },
    [GetHashKey('WEAPON_COMPACTRIFLE')] = { minFireDelay = 80, magazineSize = 30, reloadTime = 2500 },

    -- LMGs
    [GetHashKey('WEAPON_MG')] = { minFireDelay = 60, magazineSize = 54, reloadTime = 3500 },
    [GetHashKey('WEAPON_COMBATMG')] = { minFireDelay = 55, magazineSize = 100, reloadTime = 4000 },
    [GetHashKey('WEAPON_GUSENBERG')] = { minFireDelay = 70, magazineSize = 30, reloadTime = 2500 },

    -- Shotguns
    [GetHashKey('WEAPON_PUMPSHOTGUN')] = { minFireDelay = 600, magazineSize = 8, reloadTime = 3000 },
    [GetHashKey('WEAPON_SAWNOFFSHOTGUN')] = { minFireDelay = 500, magazineSize = 2, reloadTime = 2500 },
    [GetHashKey('WEAPON_ASSAULTSHOTGUN')] = { minFireDelay = 200, magazineSize = 8, reloadTime = 2800 },
    [GetHashKey('WEAPON_BULLPUPSHOTGUN')] = { minFireDelay = 250, magazineSize = 14, reloadTime = 3000 },
    [GetHashKey('WEAPON_HEAVYSHOTGUN')] = { minFireDelay = 300, magazineSize = 6, reloadTime = 2800 },

    -- Sniper
    [GetHashKey('WEAPON_SNIPERRIFLE')] = { minFireDelay = 1000, magazineSize = 10, reloadTime = 2500 },
    [GetHashKey('WEAPON_HEAVYSNIPER')] = { minFireDelay = 1500, magazineSize = 6, reloadTime = 3000 },
    [GetHashKey('WEAPON_HEAVYSNIPER_MK2')] = { minFireDelay = 1400, magazineSize = 8, reloadTime = 2800 },
    [GetHashKey('WEAPON_MARKSMANRIFLE')] = { minFireDelay = 400, magazineSize = 8, reloadTime = 2500 },

    -- Special
    [GetHashKey('WEAPON_MINIGUN')] = { minFireDelay = 10, magazineSize = 9999, reloadTime = 5000 },
    [GetHashKey('WEAPON_RPG')] = { minFireDelay = 2000, magazineSize = 1, reloadTime = 4000 },
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. RAPID FIRE DETECTION (Disparo más rápido que el arma permite)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('rapidfire', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'medium',
    tolerance = 1,            -- BAN rápido
    fireDelayTolerance = 0.5, -- 50% de tolerancia
    consecutiveViolations = 5 -- 5 disparos rápidos = ban
}, function(config, state)
    state.data.shotTimes = state.data.shotTimes or {}
    state.data.violations = state.data.violations or 0
    state.data.lastWeapon = state.data.lastWeapon or 0

    local ped = PlayerPedId()
    local _, weapon = GetCurrentPedWeapon(ped, true)

    if weapon == GetHashKey('WEAPON_UNARMED') then
        return false
    end

    -- Reset si cambió de arma
    if weapon ~= state.data.lastWeapon then
        state.data.shotTimes = {}
        state.data.violations = 0
        state.data.lastWeapon = weapon
    end

    if IsPedShooting(ped) then
        local now = GetGameTimer()
        table.insert(state.data.shotTimes, now)

        -- Mantener solo últimos 20 disparos
        if #state.data.shotTimes > 20 then
            table.remove(state.data.shotTimes, 1)
        end

        -- Calcular delay entre disparos
        if #state.data.shotTimes >= 2 then
            local lastDelay = state.data.shotTimes[#state.data.shotTimes] -
            state.data.shotTimes[#state.data.shotTimes - 1]

            local weaponInfo = WeaponData[weapon]
            if weaponInfo then
                local minDelay = weaponInfo.minFireDelay * config.fireDelayTolerance

                if lastDelay < minDelay then
                    state.data.violations = state.data.violations + 1

                    if state.data.violations >= config.consecutiveViolations then
                        state.data.violations = 0
                        return true, {
                            weapon = weapon,
                            fireDelay = lastDelay,
                            minAllowed = weaponInfo.minFireDelay,
                            violations = config.consecutiveViolations,
                            type = 'RAPID_FIRE'
                        }
                    end
                else
                    -- Decrementar gradualmente
                    state.data.violations = math.max(0, state.data.violations - 0.5)
                end
            end
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. INFINITE AMMO DETECTION (Munición nunca baja)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('infiniteammo', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'long',
    tolerance = 1,
    shotsBeforeCheck = 15,    -- Disparos antes de verificar
    ammoTolerancePercent = 10 -- 10% de margen de error
}, function(config, state)
    state.data.weaponTracking = state.data.weaponTracking or {}

    local ped = PlayerPedId()
    local _, weapon = GetCurrentPedWeapon(ped, true)

    if weapon == GetHashKey('WEAPON_UNARMED') or weapon == GetHashKey('WEAPON_MINIGUN') then
        return false
    end

    local weaponHash = tostring(weapon)
    local currentAmmo = GetAmmoInPedWeapon(ped, weapon)
    local clipAmmo, maxClip = GetAmmoInClip(ped, weapon)

    if not state.data.weaponTracking[weaponHash] then
        state.data.weaponTracking[weaponHash] = {
            startAmmo = currentAmmo,
            startClip = clipAmmo,
            shotsFired = 0,
            lastAmmo = currentAmmo
        }
        return false
    end

    local tracking = state.data.weaponTracking[weaponHash]

    if IsPedShooting(ped) then
        tracking.shotsFired = tracking.shotsFired + 1
    end

    -- Verificar después de suficientes disparos
    if tracking.shotsFired >= config.shotsBeforeCheck then
        local expectedAmmoLoss = tracking.shotsFired
        local actualAmmoLoss = tracking.startAmmo - currentAmmo

        -- Si disparó pero la munición no bajó proporcionalmente
        if actualAmmoLoss < expectedAmmoLoss * (1 - config.ammoTolerancePercent / 100) then
            -- INFINITE AMMO DETECTED
            tracking.shotsFired = 0
            tracking.startAmmo = currentAmmo

            return true, {
                weapon = weapon,
                shotsFired = tracking.shotsFired,
                expectedLoss = expectedAmmoLoss,
                actualLoss = actualAmmoLoss,
                type = 'INFINITE_AMMO'
            }
        end

        -- Reset tracking
        tracking.shotsFired = 0
        tracking.startAmmo = currentAmmo
    end

    tracking.lastAmmo = currentAmmo
    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. FAST RELOAD DETECTION (Recarga instantánea)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('fastreload', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'medium',
    tolerance = 2,
    reloadSpeedTolerance = 0.3 -- 30% del tiempo normal mínimo
}, function(config, state)
    state.data.isReloading = state.data.isReloading or false
    state.data.reloadStart = state.data.reloadStart or 0
    state.data.preReloadClip = state.data.preReloadClip or 0
    state.data.violations = state.data.violations or 0

    local ped = PlayerPedId()
    local _, weapon = GetCurrentPedWeapon(ped, true)

    if weapon == GetHashKey('WEAPON_UNARMED') then
        return false
    end

    local clipAmmo, maxClip = GetAmmoInClip(ped, weapon)
    local isReloadingNow = IsPedReloading(ped)

    -- Detectar inicio de recarga
    if isReloadingNow and not state.data.isReloading then
        state.data.isReloading = true
        state.data.reloadStart = GetGameTimer()
        state.data.preReloadClip = clipAmmo
    end

    -- Detectar fin de recarga
    if state.data.isReloading and not isReloadingNow then
        local reloadTime = GetGameTimer() - state.data.reloadStart
        local weaponInfo = WeaponData[weapon]

        if weaponInfo then
            local minReloadTime = weaponInfo.reloadTime * config.reloadSpeedTolerance

            -- Si la recarga fue más rápida de lo físicamente posible
            if reloadTime < minReloadTime and clipAmmo > state.data.preReloadClip then
                state.data.violations = state.data.violations + 1

                if state.data.violations >= config.tolerance then
                    state.data.violations = 0
                    state.data.isReloading = false

                    return true, {
                        weapon = weapon,
                        reloadTime = reloadTime,
                        minAllowed = weaponInfo.reloadTime,
                        type = 'FAST_RELOAD'
                    }
                end
            end
        end

        state.data.isReloading = false
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. NO RECOIL DETECTION (Sin retroceso de arma)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('norecoil', {
    enabled = true,
    punishment = 'warn',
    tolerance = 5,
    checkInterval = 50,
    minRecoilAngle = 0.1, -- Grados mínimos de retroceso esperado
    consecutiveShotsToCheck = 10
}, function(config, state)
    state.data.shootingData = state.data.shootingData or {}
    state.data.noRecoilCount = state.data.noRecoilCount or 0
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()

    local now = GetGameTimer()
    if now - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = now

    local ped = PlayerPedId()
    local _, weapon = GetCurrentPedWeapon(ped, true)

    if weapon == GetHashKey('WEAPON_UNARMED') then
        return false
    end

    local pitch = GetGameplayCamRelativePitch()

    if IsPedShooting(ped) then
        table.insert(state.data.shootingData, {
            pitch = pitch,
            time = now
        })

        -- Mantener últimos disparos
        if #state.data.shootingData > config.consecutiveShotsToCheck then
            table.remove(state.data.shootingData, 1)
        end

        -- Analizar si hay retroceso
        if #state.data.shootingData >= config.consecutiveShotsToCheck then
            local totalPitchChange = 0
            for i = 2, #state.data.shootingData do
                local diff = state.data.shootingData[i].pitch - state.data.shootingData[i - 1].pitch
                totalPitchChange = totalPitchChange + math.abs(diff)
            end

            -- Si disparó muchas veces pero el pitch no cambió = no recoil
            if totalPitchChange < config.minRecoilAngle * config.consecutiveShotsToCheck then
                state.data.noRecoilCount = state.data.noRecoilCount + 1

                if state.data.noRecoilCount >= config.tolerance then
                    state.data.noRecoilCount = 0
                    state.data.shootingData = {}

                    return true, {
                        weapon = weapon,
                        pitchChange = totalPitchChange,
                        shots = config.consecutiveShotsToCheck,
                        type = 'NO_RECOIL'
                    }
                end
            else
                state.data.noRecoilCount = math.max(0, state.data.noRecoilCount - 1)
            end
        end
    else
        -- Limpiar datos si no está disparando
        if #state.data.shootingData > 0 then
            local lastShot = state.data.shootingData[#state.data.shootingData]
            if now - lastShot.time > 2000 then
                state.data.shootingData = {}
            end
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. NO SPREAD DETECTION (Disparos siempre centrados)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('nospread', {
    enabled = true,
    punishment = 'warn',
    tolerance = 10,
    checkInterval = 100,
    maxPerfectHits = 15 -- Hits perfectos consecutivos = sospechoso
}, function(config, state)
    state.data.perfectHits = state.data.perfectHits or 0
    state.data.totalHits = state.data.totalHits or 0
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()

    local now = GetGameTimer()
    if now - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = now

    local ped = PlayerPedId()

    if IsPedShooting(ped) then
        local _, entity = GetEntityPlayerIsFreeAimingAt(PlayerId())

        if entity and DoesEntityExist(entity) and IsEntityAPed(entity) then
            -- Verificar si dio headshot
            local hitBone = GetPedLastDamageBone(entity)

            if hitBone == 31086 then -- Head bone
                state.data.perfectHits = state.data.perfectHits + 1
            end
            state.data.totalHits = state.data.totalHits + 1

            -- Demasiados headshots perfectos = no spread/aimbot
            if state.data.perfectHits >= config.maxPerfectHits then
                local ratio = state.data.perfectHits / state.data.totalHits

                if ratio > 0.8 then -- 80%+ headshots = muy sospechoso
                    state.data.perfectHits = 0
                    state.data.totalHits = 0

                    return true, {
                        headshots = state.data.perfectHits,
                        total = state.data.totalHits,
                        accuracy = math.floor(ratio * 100),
                        type = 'NO_SPREAD_AIMBOT'
                    }
                end
            end
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. ONE-SHOT KILL DETECTION (Daño excesivo)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('oneshoot', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'medium',
    tolerance = 2,
    maxDamageMultiplier = 3.0 -- 3x el daño normal máximo
}, function(config, state)
    state.data.damageDealt = state.data.damageDealt or {}

    -- Esta detección es principalmente server-side
    -- Client-side solo puede verificar patrones sospechosos

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. WEAPON BLACKLIST (Armas que nunca deberían tenerse)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('weaponblacklist', {
    enabled = true,
    punishment = 'ban_perm',
    tolerance = 1,
    checkInterval = 1000,
    blacklistedWeapons = {
        GetHashKey('WEAPON_MINIGUN'), GetHashKey('WEAPON_RAILGUN'), GetHashKey('WEAPON_RPG'),
        GetHashKey('WEAPON_HOMINGLAUNCHER'), GetHashKey('WEAPON_GRENADELAUNCHER'),
        GetHashKey('WEAPON_GRENADELAUNCHER_SMOKE'), GetHashKey('WEAPON_COMPACTLAUNCHER'),
        GetHashKey('WEAPON_RAYMINIGUN'), GetHashKey('WEAPON_RAYCARBINE'), GetHashKey('WEAPON_RAYPISTOL'),
        GetHashKey('WEAPON_EMPLAUNCHER'), GetHashKey('WEAPON_WIDOWMAKER'), GetHashKey('WEAPON_STINGER'),
        GetHashKey('WEAPON_FIREWORK'), GetHashKey('WEAPON_MUSKET'), GetHashKey('WEAPON_STUNGUN_MP')
    }
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or 0

    local now = GetGameTimer()
    if now - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = now

    local ped = PlayerPedId()

    for _, weapon in ipairs(config.blacklistedWeapons) do
        if HasPedGotWeapon(ped, weapon, false) then
            -- Quitar inmediatamente
            RemoveWeaponFromPed(ped, weapon)

            return true, {
                weapon = weapon,
                type = 'BLACKLISTED_WEAPON'
            }
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. EXPLOSIVE SPAM ULTRA (Spam de explosivos)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('explosion_spam', {
    enabled = true,
    punishment = 'kick', -- Changed from ban_perm to kick (less harsh for potential false positives)
    tolerance = 3, -- Increased tolerance
    maxExplosionsPerSecond = 3, -- Increased limit
    trackingWindow = 5000 -- Longer window for more accurate rate calculation
}, function(config, state)
    -- NOTE: This detection relies on the 'explosionEvent' event handler in entities.lua
    -- It cannot accurately detect player-caused explosions via polling (IsExplosionInSphere)
    -- because that native detects ALL explosions in the area, not just player-caused ones.
    
    -- This polling method is disabled to prevent false positives from:
    -- - NPC vehicles exploding
    -- - Other players using explosives
    -- - Environmental explosions (gas stations, etc.)
    -- - Mission-related explosions
    
    -- The actual explosive spam detection should be handled server-side
    -- or via the explosionEvent event which properly identifies the source
    
    return false
end)

print('^2[LyxGuard v4.0]^7 Weapon Detection ULTRA loaded (8 modules)')
