--[[
    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║                           LYXGUARD v4.0 ULTRA                                ║
    ║                    DETECCIONES ULTRA-AVANZADAS                               ║
    ╠═══════════════════════════════════════════════════════════════════════════════╣
    ║  • Anti-Citizen/AI folder (.meta, .rpf exploits)                             ║
    ║  • Aimbot robusto con ban automático                                         ║
    ║  • Health regeneration detection                                             ║
    ║  • Ammo monitoring avanzado                                                  ║
    ║  • Entity spawn detection                                                    ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. ANTI-CITIZEN/AI FOLDER EXPLOITS
-- Detecta recursos sospechosos que podrían ser inyectados en citizen folder
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('citizen_exploit', {
    enabled = true,
    punishment = 'ban_perm',
    tolerance = 1,
    checkInterval = 30000,
    suspiciousResourceNames = {
        'ai', 'godmode', 'cheat', 'mod', 'menu', 'hack', 'trainer',
        'immortal', 'unlimited', 'god', 'norecoil', 'aimbot', 'esp',
        'wallhack', 'triggerbot', 'nocd', 'infinite', 'bypass',
        'inject', 'loader', 'executor', 'lua_', '_lua', 'script_'
    },
    suspiciousPatterns = {
        '^ai$', '^mod$', '^hack', 'cheat', 'godmode', 'trainer',
        '^x_', '^_x', 'bypass', 'spoof', 'undetect'
    }
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or 0

    local now = GetGameTimer()
    if now - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = now

    local numResources = GetNumResources()
    for i = 0, numResources - 1 do
        local resName = GetResourceByFindIndex(i)
        if resName then
            local resLower = resName:lower()

            -- Check exact suspicious names
            for _, suspicious in ipairs(config.suspiciousResourceNames) do
                if resLower == suspicious then
                    local resState = GetResourceState(resName)
                    if resState == 'started' or resState == 'starting' then
                        return true, {
                            resource = resName,
                            matchType = 'exact_name',
                            state = resState
                        }
                    end
                end
            end

            -- Check patterns
            for _, pattern in ipairs(config.suspiciousPatterns) do
                if string.match(resLower, pattern) then
                    local resState = GetResourceState(resName)
                    -- Solo detectar si está activo y no es un recurso conocido
                    if resState == 'started' then
                        -- Whitelist de recursos legítimos
                        local whitelist = {
                            'lyx-guard', 'lyx-panel', 'es_extended', 'oxmysql',
                            'ox_lib', 'ox_inventory', 'esx_', 'qb-', 'vms_',
                            'mythic_', 'wasabi_', 'cd_', 'jim-', 'ps-'
                        }
                        local isWhitelisted = false
                        for _, wl in ipairs(whitelist) do
                            if string.find(resLower, wl) then
                                isWhitelisted = true
                                break
                            end
                        end

                        if not isWhitelisted then
                            return true, {
                                resource = resName,
                                matchType = 'pattern',
                                pattern = pattern,
                                state = resState
                            }
                        end
                    end
                end
            end
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. AIMBOT ULTRA DETECTION (Con ban automático)
-- Detecta velocidad de mira absurdamente rápida + precisión sospechosa
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('aimbot_ultra', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'long',
    tolerance = 1,                   -- INSTANT BAN
    minAimSpeedThreshold = 300.0,    -- Velocidad muy alta (grados/segundo)
    suspiciousSnapThreshold = 200.0, -- Snap sospechoso
    consecutiveSnapsForBan = 5,      -- Snaps consecutivos para ban
    trackingWindow = 5000,           -- Ventana de 5 segundos
    checkInterval = 50               -- Check cada 50ms para precisión
}, function(config, state)
    state.data.aimHistory = state.data.aimHistory or {}
    state.data.lastAim = state.data.lastAim or { pitch = 0, heading = 0, time = GetGameTimer() }
    state.data.suspiciousSnaps = state.data.suspiciousSnaps or 0
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()

    local now = GetGameTimer()
    if now - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = now

    local ped = PlayerPedId()

    -- Solo verificar si el jugador está apuntando/disparando
    if not IsPlayerFreeAiming(PlayerId()) and not IsPedShooting(ped) then
        state.data.suspiciousSnaps = math.max(0, state.data.suspiciousSnaps - 1)
        return false
    end

    local currentPitch = GetGameplayCamRelativePitch()
    local currentHeading = GetGameplayCamRelativeHeading()

    local dt = (now - state.data.lastAim.time) / 1000.0
    if dt > 0 and dt < 1.0 then -- Evitar divisiones raras
        local pitchDiff = math.abs(currentPitch - state.data.lastAim.pitch)
        local headingDiff = math.abs(currentHeading - state.data.lastAim.heading)

        -- Normalizar heading
        if headingDiff > 180 then headingDiff = 360 - headingDiff end

        local totalSpeed = (pitchDiff + headingDiff) / dt

        -- Guardar en historial
        table.insert(state.data.aimHistory, {
            speed = totalSpeed,
            time = now
        })

        -- Limpiar historial viejo
        local cutoff = now - config.trackingWindow
        local newHistory = {}
        for _, entry in ipairs(state.data.aimHistory) do
            if entry.time > cutoff then
                table.insert(newHistory, entry)
            end
        end
        state.data.aimHistory = newHistory

        -- Velocidad absurda = BAN INSTANT
        if totalSpeed > config.minAimSpeedThreshold then
            return true, {
                aimSpeed = math.floor(totalSpeed),
                threshold = config.minAimSpeedThreshold,
                type = 'INSTANT_SNAP',
                severity = 'CRITICAL'
            }
        end

        -- Velocidad sospechosa = acumular
        if totalSpeed > config.suspiciousSnapThreshold then
            state.data.suspiciousSnaps = state.data.suspiciousSnaps + 1

            -- Múltiples snaps sospechosos = BAN
            if state.data.suspiciousSnaps >= config.consecutiveSnapsForBan then
                return true, {
                    aimSpeed = math.floor(totalSpeed),
                    threshold = config.suspiciousSnapThreshold,
                    snapsDetected = state.data.suspiciousSnaps,
                    type = 'ACCUMULATED_SNAPS',
                    severity = 'HIGH'
                }
            end
        else
            -- Decrementar gradualmente
            state.data.suspiciousSnaps = math.max(0, state.data.suspiciousSnaps - 0.5)
        end
    end

    state.data.lastAim = { pitch = currentPitch, heading = currentHeading, time = now }
    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. HEALTH REGENERATION DETECTION
-- Detecta regeneración de vida anormal
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('health_regen', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'medium',
    tolerance = 2,
    maxHealthGainPerSecond = 5,    -- Máximo 5 HP por segundo natural
    monitoringWindow = 3000,       -- Ventana de 3 segundos
    minHealthGainForDetection = 50 -- Mínimo 50 HP ganados para detectar
}, function(config, state)
    state.data.healthHistory = state.data.healthHistory or {}
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()

    local now = GetGameTimer()
    local ped = PlayerPedId()
    local currentHealth = GetEntityHealth(ped)

    -- Guardar en historial
    table.insert(state.data.healthHistory, {
        health = currentHealth,
        time = now
    })

    -- Limpiar historial viejo
    local cutoff = now - config.monitoringWindow
    local newHistory = {}
    for _, entry in ipairs(state.data.healthHistory) do
        if entry.time > cutoff then
            table.insert(newHistory, entry)
        end
    end
    state.data.healthHistory = newHistory

    -- Analizar regeneración
    if #state.data.healthHistory >= 2 then
        local oldest = state.data.healthHistory[1]
        local newest = state.data.healthHistory[#state.data.healthHistory]

        local healthGain = newest.health - oldest.health
        local timeSpan = (newest.time - oldest.time) / 1000.0

        if timeSpan > 0 and healthGain > config.minHealthGainForDetection then
            local regenRate = healthGain / timeSpan

            -- Ignorar si el jugador está en un vehículo de emergencia o cerca de medical
            if not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false) then
                if regenRate > config.maxHealthGainPerSecond then
                    -- Verificar que no sea un evento legítimo (respawn, heal de admin, etc)
                    local maxHealth = GetEntityMaxHealth(ped)
                    if currentHealth < maxHealth then -- No está en full health después
                        return true, {
                            healthGained = math.floor(healthGain),
                            timeSeconds = math.floor(timeSpan),
                            regenRate = string.format("%.1f", regenRate),
                            maxAllowed = config.maxHealthGainPerSecond
                        }
                    end
                end
            end
        end
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. AMMO EXPLOIT ULTRA DETECTION
-- Monitoreo avanzado de munición
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('ammo_exploit', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'medium',
    tolerance = 2,
    maxAmmoGain = 100,     -- Máximo aumento de munición permitido sin pickup
    shotsBeforeCheck = 10, -- Disparos antes de verificar
    checkInterval = 1000
}, function(config, state)
    state.data.weaponAmmo = state.data.weaponAmmo or {}
    state.data.shotsFired = state.data.shotsFired or {}
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()

    local now = GetGameTimer()
    local ped = PlayerPedId()
    local _, weapon = GetCurrentPedWeapon(ped, true)

    if weapon == GetHashKey('WEAPON_UNARMED') then
        return false
    end

    local weaponHash = tostring(weapon)
    local currentAmmo = GetAmmoInPedWeapon(ped, weapon)

    -- Inicializar tracking para esta arma
    if not state.data.weaponAmmo[weaponHash] then
        state.data.weaponAmmo[weaponHash] = currentAmmo
        state.data.shotsFired[weaponHash] = 0
        return false
    end

    -- Contar disparos
    if IsPedShooting(ped) then
        state.data.shotsFired[weaponHash] = (state.data.shotsFired[weaponHash] or 0) + 1
    end

    local lastAmmo = state.data.weaponAmmo[weaponHash]
    local shots = state.data.shotsFired[weaponHash] or 0

    -- Verificar munición infinita (disparó pero no bajó la munición)
    if shots >= config.shotsBeforeCheck then
        if currentAmmo >= lastAmmo then
            -- Disparó muchas veces pero no perdió munición = infinite ammo
            state.data.shotsFired[weaponHash] = 0
            return true, {
                weapon = weaponHash,
                shotsFired = shots,
                ammoStart = lastAmmo,
                ammoCurrent = currentAmmo,
                type = 'INFINITE_AMMO'
            }
        end
        state.data.shotsFired[weaponHash] = 0
    end

    -- Verificar ganancia sospechosa de munición
    local ammoGain = currentAmmo - lastAmmo
    if ammoGain > config.maxAmmoGain then
        return true, {
            weapon = weaponHash,
            ammoGained = ammoGain,
            maxAllowed = config.maxAmmoGain,
            type = 'AMMO_SPAWN'
        }
    end

    state.data.weaponAmmo[weaponHash] = currentAmmo
    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. VEHICLE SPAWN DETECTION
-- Detecta spawn de vehículos sospechoso
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('vehicle_spawn', {
    enabled = true,
    punishment = 'warn',
    tolerance = 3,
    maxVehiclesPerMinute = 3,
    checkInterval = 5000,
    blacklistedVehicles = {
        'hydra', 'lazer', 'khanjali', 'rhino', 'hunter', 'savage',
        'akula', 'strikeforce', 'bombushka', 'volatol', 'titan',
        'cargoplane', 'jet', 'luxor2', 'nimbus'
    }
}, function(config, state)
    state.data.spawnedVehicles = state.data.spawnedVehicles or {}
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()
    state.data.resetTime = state.data.resetTime or GetGameTimer()

    local now = GetGameTimer()

    -- Reset cada minuto
    if now - state.data.resetTime > 60000 then
        state.data.spawnedVehicles = {}
        state.data.resetTime = now
    end

    if now - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = now

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    -- Obtener vehículos cercanos
    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehCoords = GetEntityCoords(vehicle)
            local dist = #(coords - vehCoords)

            if dist < 30.0 then
                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                if netId and not state.data.spawnedVehicles[netId] then
                    -- Vehículo nuevo cercano
                    local model = GetEntityModel(vehicle)
                    local vehName = GetDisplayNameFromVehicleModel(model):lower()

                    state.data.spawnedVehicles[netId] = {
                        model = vehName,
                        time = now
                    }

                    -- Verificar si es un vehículo blacklisted
                    for _, blacklisted in ipairs(config.blacklistedVehicles) do
                        if vehName == blacklisted then
                            return true, {
                                vehicle = vehName,
                                type = 'BLACKLISTED_VEHICLE',
                                netId = netId
                            }
                        end
                    end
                end
            end
        end
    end

    -- Contar vehículos spawneados en el último minuto
    local recentSpawns = 0
    for netId, data in pairs(state.data.spawnedVehicles) do
        if now - data.time < 60000 then
            recentSpawns = recentSpawns + 1
        end
    end

    if recentSpawns > config.maxVehiclesPerMinute then
        return true, {
            vehiclesSpawned = recentSpawns,
            maxAllowed = config.maxVehiclesPerMinute,
            type = 'VEHICLE_SPAM'
        }
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. WEAPON SPAWN DETECTION
-- Detecta spawn/obtención ilegítima de armas
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('weapon_spawn', {
    enabled = true,
    punishment = 'warn',
    tolerance = 2,
    checkInterval = 2000,
    maxWeaponsPerMinute = 5,
    blacklistedWeapons = {
        GetHashKey('WEAPON_MINIGUN'), GetHashKey('WEAPON_RAILGUN'), GetHashKey('WEAPON_RPG'),
        GetHashKey('WEAPON_GRENADELAUNCHER_SMOKE'), GetHashKey('WEAPON_HOMINGLAUNCHER'),
        GetHashKey('WEAPON_COMPACTLAUNCHER'), GetHashKey('WEAPON_RAYMINIGUN'), GetHashKey('WEAPON_RAYCARBINE')
    }
}, function(config, state)
    state.data.weapons = state.data.weapons or {}
    state.data.newWeaponsThisMinute = state.data.newWeaponsThisMinute or 0
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()
    state.data.resetTime = state.data.resetTime or GetGameTimer()

    local now = GetGameTimer()

    -- Reset cada minuto
    if now - state.data.resetTime > 60000 then
        state.data.newWeaponsThisMinute = 0
        state.data.resetTime = now
    end

    if now - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = now

    local ped = PlayerPedId()

    -- Lista de armas para verificar
    local weaponsToCheck = {
        GetHashKey('WEAPON_PISTOL'), GetHashKey('WEAPON_COMBATPISTOL'), GetHashKey('WEAPON_APPISTOL'),
        GetHashKey('WEAPON_SMG'), GetHashKey('WEAPON_MICROSMG'), GetHashKey('WEAPON_ASSAULTRIFLE'),
        GetHashKey('WEAPON_CARBINERIFLE'), GetHashKey('WEAPON_PUMPSHOTGUN'), GetHashKey('WEAPON_SAWNOFFSHOTGUN'),
        GetHashKey('WEAPON_SNIPERRIFLE'), GetHashKey('WEAPON_HEAVYSNIPER'), GetHashKey('WEAPON_MINIGUN'),
        GetHashKey('WEAPON_RPG'), GetHashKey('WEAPON_GRENADELAUNCHER'), GetHashKey('WEAPON_RAILGUN')
    }

    for _, weapon in ipairs(weaponsToCheck) do
        local hasWeapon = HasPedGotWeapon(ped, weapon, false)
        local hadWeapon = state.data.weapons[weapon] or false

        if hasWeapon and not hadWeapon then
            -- El jugador obtuvo una nueva arma
            state.data.newWeaponsThisMinute = state.data.newWeaponsThisMinute + 1

            -- Verificar si es blacklisted
            for _, blacklisted in ipairs(config.blacklistedWeapons) do
                if weapon == blacklisted then
                    return true, {
                        weapon = weapon,
                        type = 'BLACKLISTED_WEAPON'
                    }
                end
            end
        end

        state.data.weapons[weapon] = hasWeapon
    end

    -- Demasiadas armas nuevas en poco tiempo
    if state.data.newWeaponsThisMinute > config.maxWeaponsPerMinute then
        return true, {
            weaponsGained = state.data.newWeaponsThisMinute,
            maxAllowed = config.maxWeaponsPerMinute,
            type = 'WEAPON_SPAM'
        }
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. PED MODEL EXPLOIT DETECTION
-- Detecta cambios de modelo sospechosos
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('model_exploit', {
    enabled = true,
    punishment = 'kick',
    tolerance = 3,
    checkInterval = 5000,
    maxModelChangesPerMinute = 3,
    blacklistedModels = {
        'a_c_chicken', 'a_c_hen', 'a_c_pigeon', 'a_c_seagull',
        'slod_human', 'slod_large_quadped', 's_m_m_movspace_01'
    }
}, function(config, state)
    state.data.lastModel = state.data.lastModel or GetEntityModel(PlayerPedId())
    state.data.modelChanges = state.data.modelChanges or 0
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()
    state.data.resetTime = state.data.resetTime or GetGameTimer()

    local now = GetGameTimer()

    -- Reset cada minuto
    if now - state.data.resetTime > 60000 then
        state.data.modelChanges = 0
        state.data.resetTime = now
    end

    if now - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = now

    local ped = PlayerPedId()
    local currentModel = GetEntityModel(ped)

    if currentModel ~= state.data.lastModel then
        state.data.modelChanges = state.data.modelChanges + 1

        -- Verificar modelos blacklisted
        for _, modelName in ipairs(config.blacklistedModels) do
            if currentModel == GetHashKey(modelName) then
                state.data.lastModel = currentModel
                return true, {
                    model = modelName,
                    type = 'BLACKLISTED_MODEL'
                }
            end
        end

        state.data.lastModel = currentModel
    end

    -- Demasiados cambios de modelo
    if state.data.modelChanges > config.maxModelChangesPerMinute then
        return true, {
            changes = state.data.modelChanges,
            maxAllowed = config.maxModelChangesPerMinute,
            type = 'MODEL_SPAM'
        }
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. MONEY CHANGE DETECTION (Client-side verification)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('money_exploit', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'long',
    tolerance = 1,
    maxMoneyGainPerMinute = 500000, -- Max $500k per minute legit
    checkInterval = 5000
}, function(config, state)
    state.data.lastMoney = state.data.lastMoney or 0
    state.data.moneyGainThisMinute = state.data.moneyGainThisMinute or 0
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()
    state.data.resetTime = state.data.resetTime or GetGameTimer()

    local now = GetGameTimer()

    -- Reset cada minuto
    if now - state.data.resetTime > 60000 then
        state.data.moneyGainThisMinute = 0
        state.data.resetTime = now
    end

    if now - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = now

    -- Obtener dinero desde ESX (si está disponible)
    local success, xPlayer = pcall(function()
        return ESX.GetPlayerData()
    end)

    if success and xPlayer and xPlayer.accounts then
        local totalMoney = 0
        for _, account in ipairs(xPlayer.accounts) do
            if account.name == 'money' or account.name == 'bank' or account.name == 'black_money' then
                totalMoney = totalMoney + (account.money or 0)
            end
        end

        if state.data.lastMoney > 0 then
            local moneyGain = totalMoney - state.data.lastMoney
            if moneyGain > 0 then
                state.data.moneyGainThisMinute = state.data.moneyGainThisMinute + moneyGain

                if state.data.moneyGainThisMinute > config.maxMoneyGainPerMinute then
                    return true, {
                        moneyGained = state.data.moneyGainThisMinute,
                        maxAllowed = config.maxMoneyGainPerMinute,
                        type = 'MONEY_EXPLOIT'
                    }
                end
            end
        end

        state.data.lastMoney = totalMoney
    end

    return false
end)

print('^2[LyxGuard v4.0 ULTRA]^7 Detecciones Ultra-Avanzadas cargadas (8 módulos)')
