--[[
    
                               LYXGUARD v4.0 PROFESSIONAL                         
                               Client Bootstrap                                    
    
      Author: LyxDev                                                               
      License: Commercial                                                          
      Purpose: Client initialization and event handling                            
    
]]

-- 
-- FRAMEWORK INITIALIZATION
-- 

-- ESX es proporcionado por @es_extended/imports.lua

-- Wait for player data and initialize
CreateThread(function()
    -- Wait for player data
    while ESX.GetPlayerData().job == nil do
        Wait(100)
    end

    -- Initialize anti-cheat
    InitializeAntiCheat()
end)

-- 
-- ANTI-CHEAT INITIALIZATION
-- 

local isInitialized = false
local heartbeatStarted = false

function InitializeAntiCheat()
    if isInitialized then return end

    -- Get immunity status from server
    ESX.TriggerServerCallback('lyxguard:checkImmunity', function(immune)
        PlayerState.immune = immune

        if immune then
            print('^3[LyxGuard]^7 You have immunity - detections disabled')
        end
    end)

    -- Get detection configs from server
    ESX.TriggerServerCallback('lyxguard:getConfig', function(cfg)
        if not cfg then return end

        -- Merge all configs into DetectionConfigs
        local function _CamelToSnake(str)
            return tostring(str or ''):gsub('(%l)(%u)', '%1_%2'):lower()
        end

        local function _AddDetectionConfig(key, config)
            key = tostring(key or '')
            if key == '' then return end

            DetectionConfigs[key] = config

            local snake = _CamelToSnake(key)
            DetectionConfigs[snake] = config
            DetectionConfigs[snake:gsub('_', '')] = config
        end

        local configMappings = {
            { source = cfg.movement,   prefix = '' },
            { source = cfg.combat,     prefix = '' },
            { source = cfg.entities,   prefix = '' },
            { source = cfg.advanced,   prefix = '' },
            { source = cfg.blacklists, prefix = 'blacklist_' }
        }

        for _, mapping in ipairs(configMappings) do
            if mapping.source then
                for name, config in pairs(mapping.source) do
                    if mapping.prefix == 'blacklist_' then
                        if name == 'weapons' then
                            _AddDetectionConfig('blacklist_weapon', config)
                        elseif name == 'vehicles' then
                            _AddDetectionConfig('blacklist_vehicle', config)
                        elseif name == 'peds' then
                            _AddDetectionConfig('blacklist_ped', config)
                        else
                            _AddDetectionConfig(mapping.prefix .. name, config)
                        end
                    else
                        _AddDetectionConfig(mapping.prefix .. name, config)
                    end
                end
            end
        end

        if Config and Config.Debug then
            local count = 0
            for _ in pairs(DetectionConfigs) do count = count + 1 end
            print('^2[LyxGuard]^7 Loaded ' .. count .. ' detection configs from server')
        end
    end)

    -- Set spawn time and grace period
    PlayerState.spawnTime = GetGameTimer()
    PlayerState.inGracePeriod = true

    -- Grace period (5 seconds after spawn)
    CreateThread(function()
        Wait(5000)
        PlayerState.inGracePeriod = false

        -- Start detection loops if not immune
        if not PlayerState.immune then
            -- Use the unified detection system that runs both DetectionCore and Protections
            if StartUnifiedDetectionLoops then
                StartUnifiedDetectionLoops()
            elseif DetectionCore and DetectionCore.StartLoops then
                DetectionCore.StartLoops()
            else
                -- Fallback: use legacy function if core module not available
                StartLegacyDetectionLoops()
            end
        end

        -- Count registered detections and protections
        local detectionCount = 0
        if Detections then
            for _ in pairs(Detections) do detectionCount = detectionCount + 1 end
        end
        
        local protectionCount = GetProtectionCount and GetProtectionCount() or 0

        print(string.format('^2[LyxGuard v%s]^7 Client started - %d detections, %d protections active',
            LyxGuardLib and LyxGuardLib.VERSION or '4.0.0', detectionCount, protectionCount))
    end)

    isInitialized = true

    if not heartbeatStarted then
        heartbeatStarted = true
        CreateThread(function()
            local hbCfg = Config and Config.Advanced and Config.Advanced.heartbeat or nil
            local interval = tonumber(hbCfg and hbCfg.intervalMs) or 10000
            if interval < 5000 then interval = 5000 end

            local function _Fnv1a32(s)
                s = tostring(s or '')
                local hash = 2166136261
                for i = 1, #s do
                    hash = (hash ~ s:byte(i)) & 0xFFFFFFFF
                    hash = (hash * 16777619) & 0xFFFFFFFF
                end
                return hash
            end

            local lastFull = 0
            local lastDetHash = nil
            local lastProtHash = nil

            while true do
                Wait(interval)

                if hbCfg and hbCfg.enabled == false then
                    goto continue
                end

                local detCount = 0
                if Detections then
                    for _ in pairs(Detections) do detCount = detCount + 1 end
                end

                local protCount = (GetProtectionCount and GetProtectionCount()) or 0

                local detNames = (DetectionCore and DetectionCore.ListDetections and DetectionCore.ListDetections()) or nil
                local protNames = (GetProtectionNames and GetProtectionNames()) or nil

                local detHash = detNames and _Fnv1a32(table.concat(detNames, ',')) or 0
                local protHash = protNames and _Fnv1a32(table.concat(protNames, ',')) or 0

                local now = GetGameTimer()
                local sendFull = false
                if (now - lastFull) >= 60000 then
                    sendFull = true
                end
                if lastDetHash ~= nil and detHash ~= lastDetHash then
                    sendFull = true
                end
                if lastProtHash ~= nil and protHash ~= lastProtHash then
                    sendFull = true
                end

                lastDetHash = detHash
                lastProtHash = protHash
                if sendFull then
                    lastFull = now
                end

                TriggerServerEvent('lyxguard:heartbeat', {
                    ver = LyxGuardLib and LyxGuardLib.VERSION or 'unknown',
                    detections = detCount,
                    protections = protCount,
                    detHash = detHash,
                    protHash = protHash,
                    detNames = sendFull and detNames or nil,
                    protNames = sendFull and protNames or nil
                })

                ::continue::
            end
        end)
    end
end

-- 
-- LEGACY DETECTION LOOPS (Fallback)
-- 

function StartLegacyDetectionLoops()
    -- Fast loop (100ms) - Movement
    CreateThread(function()
        while true do
            Wait(100)
            if not (PlayerState.immune or PlayerState.frozen or PlayerState.inGracePeriod) then
                UpdatePlayerPosition()
                RunDetection('teleport')
                RunDetection('speedhack')
                RunDetection('superjump')
            end
        end
    end)

    -- Normal loop (500ms) - Combat
    CreateThread(function()
        while true do
            Wait(500)
            if not (PlayerState.immune or PlayerState.inGracePeriod) then
                RunDetection('noclip')
                RunDetection('flyhack')
                RunDetection('godmode')
                RunDetection('rapidfire')
            end
        end
    end)

    -- Slow loop (2s) - Entities
    CreateThread(function()
        while true do
            Wait(2000)
            if not (PlayerState.immune or PlayerState.inGracePeriod) then
                RunDetection('underground')
                RunDetection('healthhack')
                RunDetection('armorhack')
                RunDetection('blacklist_weapon')
                RunDetection('blacklist_vehicle')
                RunDetection('cagetrap')
            end
        end
    end)

    -- Periodic loop (30s) - Advanced
    CreateThread(function()
        while true do
            Wait(30000)
            RunDetection('injection')
            RunDetection('afkfarming')
            RunDetection('resourcevalidation')
        end
    end)
end

function UpdatePlayerPosition()
    PlayerState.lastPos = GetEntityCoords(PlayerPedId())
end

-- 
-- SERVER EVENT HANDLERS
-- 

-- Notification from server
RegisterNetEvent('lyxguard:notify', function(data)
    if type(data) == 'table' then
        -- Modern format
        ShowNotification(data.message or '', data.type or 'info')
    else
        -- Legacy format
        ShowNotification(data, 'info')
    end
end)

-- Quarantine alert (warn -> warn -> ban escalation is server-side).
local QuarantineState = {
    untilMs = 0,
    strikes = 0,
    strikesToBan = 3,
    reason = '',
}

local function _QFormatTime(ms)
    ms = tonumber(ms) or 0
    if ms < 0 then ms = 0 end
    local total = math.floor(ms / 1000)
    local m = math.floor(total / 60)
    local s = total % 60
    return string.format('%02d:%02d', m, s)
end

RegisterNetEvent('lyxguard:quarantine:set', function(data)
    if type(data) ~= 'table' then return end
    local dur = tonumber(data.durationMs) or (5 * 60 * 1000)
    if dur < 5000 then dur = 5000 end
    if dur > (30 * 60 * 1000) then dur = (30 * 60 * 1000) end

    local now = GetGameTimer()
    QuarantineState.untilMs = math.max(QuarantineState.untilMs or 0, now + dur)
    QuarantineState.strikes = tonumber(data.strikes) or QuarantineState.strikes or 0
    QuarantineState.strikesToBan = tonumber(data.strikesToBan) or QuarantineState.strikesToBan or 3

    local r = tostring(data.reason or '')
    if #r > 64 then r = r:sub(1, 64) end
    QuarantineState.reason = r
end)

CreateThread(function()
    while true do
        local now = GetGameTimer()
        if QuarantineState.untilMs and QuarantineState.untilMs > now then
            local remaining = QuarantineState.untilMs - now

            local warnMax = math.max(0, (tonumber(QuarantineState.strikesToBan) or 3) - 1)
            local warnCount = tonumber(QuarantineState.strikes) or 0
            if warnMax > 0 and warnCount > warnMax then warnCount = warnMax end

            local txt = string.format(
                'LyxGuard: Actividad sospechosa (%s) | Advertencia %d/%d | %s',
                (QuarantineState.reason and QuarantineState.reason ~= '' and QuarantineState.reason or 'unknown'),
                warnCount,
                (warnMax > 0 and warnMax or (tonumber(QuarantineState.strikesToBan) or 3)),
                _QFormatTime(remaining)
            )

            -- Background bar
            DrawRect(0.5, 0.06, 0.76, 0.045, 0, 0, 0, 170)

            -- Text
            SetTextFont(4)
            SetTextScale(0.35, 0.35)
            SetTextColour(255, 204, 0, 255)
            SetTextCentre(true)
            SetTextOutline()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentString(txt)
            EndTextCommandDisplayText(0.5, 0.048)

            Wait(0)
        else
            Wait(750)
        end
    end
end)

-- Legacy notification event
RegisterNetEvent('lyxguard:notification', function(notifType, message)
    ShowNotification(message, notifType)
end)

-- Teleport player
RegisterNetEvent('lyxguard:teleport', function(x, y, z)
    if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then
        return
    end
    SetEntityCoords(PlayerPedId(), x, y, z, false, false, false, false)
end)

-- Freeze player
RegisterNetEvent('lyxguard:freeze', function(duration)
    duration = tonumber(duration) or 30
    PlayerState.frozen = true
    FreezeEntityPosition(PlayerPedId(), true)

    -- Auto-unfreeze after duration
    CreateThread(function()
        Wait(duration * 1000)
        PlayerState.frozen = false
        FreezeEntityPosition(PlayerPedId(), false)
    end)
end)

-- Kill player
RegisterNetEvent('lyxguard:kill', function()
    SetEntityHealth(PlayerPedId(), 0)
end)

-- Admin notification
RegisterNetEvent('lyxguard:adminNotify', function(data)
    if not data then return end

    local message = string.format(' %s (%d) - %s',
        data.playerName or 'Unknown',
        data.playerId or 0,
        data.detection or 'Unknown'
    )

    ShowNotification(message, 'warning')
end)

-- 
-- UTILITY FUNCTIONS
-- 

---Show notification to player
---@param message string
---@param notifType? string 'info', 'success', 'warning', 'error'
function ShowNotification(message, notifType)
    if not message or message == '' then return end

    -- Prefix based on type
    local prefix = ''
    if notifType == 'warning' or notifType == 'error' then
        prefix = ' '
    elseif notifType == 'success' then
        prefix = ' '
    end

    SetNotificationTextEntry('STRING')
    AddTextComponentString(prefix .. tostring(message))
    DrawNotification(true, true)
end

-- 
-- EXPORTS
-- 

exports('IsImmune', function()
    return PlayerState.immune
end)

exports('IsInGracePeriod', function()
    return PlayerState.inGracePeriod
end)

exports('GetDetectionCount', function()
    local count = 0
    if Detections then
        for _ in pairs(Detections) do count = count + 1 end
    end
    return count
end)

-- 
-- DUAL-LAYER PROTECTION: CLIENT -> SERVER SYNC
-- Enva datos al servidor para verificacin adicional
-- 

local SyncData = {
    shotsFired = 0,
    lastWeapon = 0
}

-- Contar disparos para sincronizacin (v4.2: Optimizado de Wait(0) a Wait(50))
CreateThread(function()
    while true do
        Wait(50) -- v4.2 FIX: Was Wait(0), now 50ms for ~20 checks/sec (enough for gunfire detection)
        local ped = PlayerPedId()
        if IsPedShooting(ped) then
            SyncData.shotsFired = SyncData.shotsFired + 1
        end
    end
end)

-- Responder a solicitud de sincronizacin del servidor
RegisterNetEvent('lyxguard:requestSync', function()
    if PlayerState.immune then return end

    local ped = PlayerPedId()
    local _, weapon = GetCurrentPedWeapon(ped, true)

    -- Reset contador si cambi de arma
    if weapon ~= SyncData.lastWeapon then
        SyncData.shotsFired = 0
        SyncData.lastWeapon = weapon
    end

    -- Enviar datos al servidor para verificacin
    TriggerServerEvent('lyxguard:sync:playerData', {
        health = GetEntityHealth(ped),
        armor = GetPedArmour(ped),
        weaponHash = weapon,
        ammo = weapon ~= GetHashKey('WEAPON_UNARMED') and GetAmmoInPedWeapon(ped, weapon) or 0,
        shotsFired = SyncData.shotsFired,
        position = GetEntityCoords(ped)
    })

    -- Enviar lista de armas
    local weapons = {}
    local weaponsToCheck = {
        GetHashKey('WEAPON_MINIGUN'),
        GetHashKey('WEAPON_RAILGUN'),
        GetHashKey('WEAPON_RPG'),
        GetHashKey('WEAPON_HOMINGLAUNCHER'),
        GetHashKey('WEAPON_RAYMINIGUN'),
        GetHashKey('WEAPON_RAYCARBINE'),
        GetHashKey('WEAPON_EMPLAUNCHER')
    }

    for _, wHash in ipairs(weaponsToCheck) do
        if HasPedGotWeapon(ped, wHash, false) then
            table.insert(weapons, wHash)
        end
    end

    if #weapons > 0 then
        TriggerServerEvent('lyxguard:sync:weapons', weapons)
    end
end)

-- Sincronizacin automtica cada 3 segundos (backup por si el servidor no solicita)
CreateThread(function()
    Wait(10000) -- Esperar 10 segundos despus de cargar

    while true do
        Wait(3000)

        if not PlayerState.immune then
            local ped = PlayerPedId()
            local _, weapon = GetCurrentPedWeapon(ped, true)

            TriggerServerEvent('lyxguard:sync:playerData', {
                health = GetEntityHealth(ped),
                armor = GetPedArmour(ped),
                weaponHash = weapon,
                ammo = weapon ~= GetHashKey('WEAPON_UNARMED') and GetAmmoInPedWeapon(ped, weapon) or 0,
                shotsFired = SyncData.shotsFired
            })
        end
    end
end)

print('^2[LyxGuard v4.0]^7 Client loaded with DUAL-LAYER PROTECTION')

