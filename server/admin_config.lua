--[[
    LyxGuard v4.0 - Admin Config Server Callbacks
    Server-side ESX callbacks for Admin Config panel functionality
]]

-- ESX is provided by @es_extended/imports.lua; keep a bounded fallback via bootstrap.
ESX = ESX or _G.ESX
local _PendingESXCallbacks = {}
local _CallbacksFlushed = false

local function _ResolveESX(timeoutMs)
    if ESX then return ESX end

    if LyxGuard and LyxGuard.WaitForESX then
        ESX = LyxGuard.WaitForESX(timeoutMs or 15000)
    end

    ESX = ESX or _G.ESX
    if ESX then
        _G.ESX = _G.ESX or ESX
    end
    return ESX
end

local function RegisterESXCallback(name, handler)
    if ESX and _CallbacksFlushed then
        ESX.RegisterServerCallback(name, handler)
        return
    end

    _PendingESXCallbacks[#_PendingESXCallbacks + 1] = {
        name = name,
        handler = handler
    }
end

CreateThread(function()
    local resolved = _ResolveESX(15000)
    if not resolved then
        print('^3[LyxGuard]^7 admin_config: ESX no disponible (timeout inicial). Reintentando cada 2s...')
        while not resolved do
            Wait(2000)
            if LyxGuard and LyxGuard.GetESX then
                resolved = LyxGuard.GetESX()
            end
            if not resolved then
                resolved = _ResolveESX(2000)
            end
        end
        print('^2[LyxGuard]^7 admin_config: ESX detectado tras reintento. Registrando callbacks.')
    end

    ESX = resolved
    _G.ESX = _G.ESX or ESX

    if not _CallbacksFlushed then
        for i = 1, #_PendingESXCallbacks do
            local entry = _PendingESXCallbacks[i]
            ESX.RegisterServerCallback(entry.name, entry.handler)
        end
        _PendingESXCallbacks = {}
        _CallbacksFlushed = true
    end
end)

-- Runtime configuration storage (overrides config.lua settings)
local RuntimeConfig = {
    immuneGroups = {},
    vipSettings = {},
    detectionSettings = {}
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- WHITELIST CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterESXCallback('lyxguard:panel:getWhitelist', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ whitelist = {} }) end
    
    -- Check admin permission
    local group = xPlayer.getGroup()
    if not (group == 'admin' or group == 'superadmin' or group == 'owner' or group == 'master') then
        return cb({ whitelist = {} })
    end
    
    MySQL.Async.fetchAll('SELECT * FROM lyxguard_whitelist ORDER BY date DESC', {}, function(results)
        cb({ whitelist = results or {} })
    end)
end)

RegisterESXCallback('lyxguard:panel:addToWhitelist', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false }) end
    
    local group = xPlayer.getGroup()
    if not (group == 'admin' or group == 'superadmin' or group == 'owner' or group == 'master') then
        return cb({ success = false, message = 'Sin permisos' })
    end
    
    if not data or not data.identifier or data.identifier == '' then
        return cb({ success = false, message = 'Identifier inválido' })
    end
    
    -- Check if already exists
    MySQL.Async.fetchScalar('SELECT id FROM lyxguard_whitelist WHERE identifier = @id', {
        ['@id'] = data.identifier
    }, function(existingId)
        if existingId then
            return cb({ success = false, message = 'Ya existe en whitelist' })
        end
        
        MySQL.Async.execute([[
            INSERT INTO lyxguard_whitelist (identifier, player_name, added_by, level, notes) 
            VALUES (@identifier, @name, @addedBy, @level, @notes)
        ]], {
            ['@identifier'] = data.identifier,
            ['@name'] = data.playerName or 'Unknown',
            ['@addedBy'] = xPlayer.getName(),
            ['@level'] = data.level or 'full',
            ['@notes'] = data.notes or ''
         }, function(rowsChanged)
             if rowsChanged and rowsChanged > 0 then
                 print(('[LyxGuard] Whitelist: %s added %s (level: %s)'):format(
                     xPlayer.getName(), data.identifier, data.level
                 ))
                 TriggerEvent('lyxguard:whitelist:refresh')
                 cb({ success = true })
             else
                 cb({ success = false, message = 'Error al insertar' })
             end
         end)
    end)
end)

RegisterESXCallback('lyxguard:panel:removeFromWhitelist', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false }) end
    
    local group = xPlayer.getGroup()
    if not (group == 'admin' or group == 'superadmin' or group == 'owner' or group == 'master') then
        return cb({ success = false, message = 'Sin permisos' })
    end
    
    if not data or not data.identifier then
        return cb({ success = false, message = 'Identifier inválido' })
    end
    
     MySQL.Async.execute('DELETE FROM lyxguard_whitelist WHERE identifier = @id', {
         ['@id'] = data.identifier
     }, function(rowsChanged)
         if rowsChanged > 0 then
             print(('[LyxGuard] Whitelist: %s removed %s'):format(xPlayer.getName(), data.identifier))
             TriggerEvent('lyxguard:whitelist:refresh')
             cb({ success = true })
         else
             cb({ success = false, message = 'No encontrado' })
         end
     end)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- IMMUNE GROUPS CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterESXCallback('lyxguard:panel:getImmuneGroups', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ groups = {} }) end
    
    -- Return from runtime config or from Config file
    local groups = RuntimeConfig.immuneGroups
    if #groups == 0 and Config and Config.Permissions and Config.Permissions.immuneGroups then
        groups = Config.Permissions.immuneGroups
    end
    
    cb({ groups = groups })
end)

RegisterESXCallback('lyxguard:panel:saveImmuneGroups', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false }) end
    
    local group = xPlayer.getGroup()
    if not (group == 'superadmin' or group == 'owner') then
        return cb({ success = false, message = 'Solo superadmin/owner pueden modificar esto' })
    end
    
    if not data or not data.groups then
        return cb({ success = false, message = 'Datos inválidos' })
    end
    
    -- Update runtime config
    RuntimeConfig.immuneGroups = data.groups
    
    -- Also update Config if available
    if Config and Config.Permissions then
        Config.Permissions.immuneGroups = data.groups
    end
    
    print(('[LyxGuard] %s updated immune groups: %s'):format(
        xPlayer.getName(), 
        table.concat(data.groups, ', ')
    ))
    
    cb({ success = true })
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- VIP SETTINGS CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterESXCallback('lyxguard:panel:saveVipSettings', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false }) end
    
    local group = xPlayer.getGroup()
    if not (group == 'admin' or group == 'superadmin' or group == 'owner') then
        return cb({ success = false, message = 'Sin permisos' })
    end
    
    if not data then
        return cb({ success = false, message = 'Datos inválidos' })
    end
    
    -- Update runtime config
    RuntimeConfig.vipSettings = {
        enabled = data.enabled,
        toleranceMultiplier = data.toleranceMultiplier,
        ignoredDetections = data.ignoredDetections
    }
    
    -- Also update Config if available
    if Config and Config.Permissions and Config.Permissions.vipWhitelist then
        Config.Permissions.vipWhitelist.enabled = data.enabled
        Config.Permissions.vipWhitelist.toleranceMultiplier = data.toleranceMultiplier or 2.0
        if data.ignoredDetections then
            Config.Permissions.vipWhitelist.ignoredDetections = data.ignoredDetections
        end
    end
    
    print(('[LyxGuard] %s updated VIP settings'):format(xPlayer.getName()))
    
    cb({ success = true })
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- DETECTION SETTINGS CALLBACKS  (UI dinamica + persistencia v4.4)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Secciones de Config donde viven las detecciones y su grupo "logico" para el panel.
local DETECTION_SECTIONS = {
    { key = 'Movement',   group = 'Movement',   clientPrefix = '' },
    { key = 'Combat',     group = 'Combat',     clientPrefix = '' },
    { key = 'Ultra',      group = 'Ultra',      clientPrefix = '' },
    { key = 'Entities',   group = 'Entities',   clientPrefix = '' },
    { key = 'Advanced',   group = 'Advanced',   clientPrefix = '' },
    { key = 'Blacklists', group = 'Blacklists', clientPrefix = '' },
}

-- Convierte camelCase / snake a etiqueta legible: "vehicleSpawn" -> "Vehicle Spawn".
local function _Humanize(name)
    local s = tostring(name or '')
    s = s:gsub('_', ' ')
    s = s:gsub('(%l)(%u)', '%1 %2')
    s = s:gsub('^%l', string.upper)
    return s
end

-- Devuelve la seccion (tabla Config) y el descriptor donde vive una deteccion.
local function _FindDetectionSection(name)
    for _, sec in ipairs(DETECTION_SECTIONS) do
        local t = Config and Config[sec.key]
        if type(t) == 'table' and type(t[name]) == 'table' and t[name].enabled ~= nil then
            return t[name], sec
        end
    end
    return nil, nil
end

-- ── PERSISTENCIA ──────────────────────────────────────────────────────────────
local function _PersistMode()
    local m = tostring((Config and Config.PanelPersistence) or 'database'):lower()
    if m ~= 'database' and m ~= 'json' and m ~= 'off' then m = 'database' end
    return m
end

local OVERRIDES_JSON = 'overrides.json'

local function _JsonRead()
    local raw = LoadResourceFile(GetCurrentResourceName(), OVERRIDES_JSON)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    return {}
end

local function _JsonWrite(tbl)
    local ok, encoded = pcall(json.encode, tbl)
    if not ok then return false end
    return SaveResourceFile(GetCurrentResourceName(), OVERRIDES_JSON, encoded, -1) and true or false
end

-- Aplica un override {enabled, punishment, banDuration} sobre Config en runtime.
local function _ApplyOverrideToConfig(name, ov)
    local settings = _FindDetectionSection(name)
    if not settings then return false end
    if ov.enabled ~= nil then settings.enabled = ov.enabled and true or false end
    if ov.punishment ~= nil and ov.punishment ~= '' then settings.punishment = ov.punishment end
    if ov.banDuration ~= nil and ov.banDuration ~= '' then settings.banDuration = ov.banDuration end
    return true
end

-- Notifica a los clientes conectados el cambio (live, sin reinicio).
local function _PushToClients(entries)
    if type(entries) ~= 'table' or not next(entries) then return end
    TriggerClientEvent('lyxguard:updateDetectionConfig', -1, entries)
end

-- Guarda overrides segun el modo elegido (database / json / off).
local function _SaveOverrides(list, updatedBy)
    local mode = _PersistMode()
    if mode == 'off' then return true end

    if mode == 'json' then
        local data = _JsonRead()
        data.detections = data.detections or {}
        for name, ov in pairs(list) do
            data.detections[name] = {
                enabled = ov.enabled,
                punishment = ov.punishment,
                banDuration = ov.banDuration
            }
        end
        return _JsonWrite(data)
    end

    -- database
    for name, ov in pairs(list) do
        MySQL.Async.execute([[
            INSERT INTO lyxguard_config_overrides (detection_name, enabled, punishment, ban_duration, updated_by)
            VALUES (@n, @e, @p, @b, @by)
            ON DUPLICATE KEY UPDATE enabled=@e, punishment=@p, ban_duration=@b, updated_by=@by
        ]], {
            ['@n'] = name,
            ['@e'] = ov.enabled and 1 or 0,
            ['@p'] = ov.punishment,
            ['@b'] = ov.banDuration,
            ['@by'] = updatedBy or 'panel'
        })
    end
    return true
end

local function _SaveMeta(key, value)
    local mode = _PersistMode()
    if mode == 'off' then return end
    if mode == 'json' then
        local data = _JsonRead()
        data.meta = data.meta or {}
        data.meta[key] = value
        _JsonWrite(data)
        return
    end
    MySQL.Async.execute([[
        INSERT INTO lyxguard_config_meta (meta_key, meta_value) VALUES (@k, @v)
        ON DUPLICATE KEY UPDATE meta_value=@v
    ]], { ['@k'] = key, ['@v'] = tostring(value) })
end

-- Carga overrides persistidos y los aplica a Config al arrancar.
local function _LoadAndApplyOverrides()
    local mode = _PersistMode()
    if mode == 'off' then return end

    if mode == 'json' then
        local data = _JsonRead()
        local dets = data.detections or {}
        local pushed = {}
        for name, ov in pairs(dets) do
            if _ApplyOverrideToConfig(name, ov) then
                pushed[#pushed + 1] = { name = name, enabled = ov.enabled, punishment = ov.punishment, banDuration = ov.banDuration }
            end
        end
        if #pushed > 0 then _PushToClients(pushed) end
        print(('^2[LyxGuard]^7 admin_config: %d overrides (json) aplicados.'):format(#pushed))
        return
    end

    -- database
    MySQL.Async.fetchAll('SELECT detection_name, enabled, punishment, ban_duration FROM lyxguard_config_overrides', {}, function(rows)
        if not rows then return end
        local pushed = {}
        for _, r in ipairs(rows) do
            local ov = {
                enabled = (tonumber(r.enabled) or 0) == 1,
                punishment = r.punishment,
                banDuration = r.ban_duration
            }
            if _ApplyOverrideToConfig(r.detection_name, ov) then
                pushed[#pushed + 1] = { name = r.detection_name, enabled = ov.enabled, punishment = ov.punishment, banDuration = ov.banDuration }
            end
        end
        if #pushed > 0 then _PushToClients(pushed) end
        print(('^2[LyxGuard]^7 admin_config: %d overrides (db) aplicados.'):format(#pushed))
    end)
end

-- Aplicar overrides persistidos poco despues del arranque (deja que migraciones corran).
CreateThread(function()
    Wait(8000)
    local ok, err = pcall(_LoadAndApplyOverrides)
    if not ok then
        print('^3[LyxGuard]^7 admin_config: no se pudieron cargar overrides: ' .. tostring(err))
    end
end)

-- ── CALLBACKS ─────────────────────────────────────────────────────────────────

-- Devuelve TODAS las detecciones (lista plana agrupada) para la UI dinamica.
RegisterESXCallback('lyxguard:panel:getAllDetections', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ detections = {} }) end

    local group = xPlayer.getGroup()
    if not (group == 'admin' or group == 'superadmin' or group == 'owner' or group == 'master') then
        return cb({ detections = {} })
    end

    local detections = {}
    for _, sec in ipairs(DETECTION_SECTIONS) do
        local t = Config and Config[sec.key]
        if type(t) == 'table' then
            for name, settings in pairs(t) do
                if type(settings) == 'table' and settings.enabled ~= nil then
                    detections[#detections + 1] = {
                        name = name,
                        group = sec.group,
                        label = _Humanize(name),
                        enabled = settings.enabled and true or false,
                        punishment = settings.punishment or 'notify',
                        banDuration = settings.banDuration or 'medium'
                    }
                end
            end
        end
    end

    cb({
        detections = detections,
        preset = (Config and Config.Preset) or 'estricto',
        persistence = _PersistMode()
    })
end)

-- Compat: callback antiguo (enabled/punishment por nombre) — se mantiene para no romper.
RegisterESXCallback('lyxguard:panel:getDetectionSettings', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ detections = {} }) end

    local detections = {}
    for _, sec in ipairs(DETECTION_SECTIONS) do
        local t = Config and Config[sec.key]
        if type(t) == 'table' then
            for name, settings in pairs(t) do
                if type(settings) == 'table' and settings.enabled ~= nil then
                    detections[name] = {
                        enabled = settings.enabled,
                        punishment = settings.punishment or 'notify'
                    }
                end
            end
        end
    end
    cb({ detections = detections })
end)

-- Devuelve los castigos que aplicaria un preset a cada deteccion (para "Aplicar preset").
RegisterESXCallback('lyxguard:panel:getPresetPunishments', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ punishments = {} }) end

    local presetName = (data and tostring(data.preset)) or 'estricto'
    local punishments = {}

    if LyxGuardEasy and LyxGuardEasy.ResolvePunishment then
        for _, sec in ipairs(DETECTION_SECTIONS) do
            local t = Config and Config[sec.key]
            if type(t) == 'table' then
                for name, settings in pairs(t) do
                    if type(settings) == 'table' and settings.enabled ~= nil then
                        local p = LyxGuardEasy.ResolvePunishment(presetName, name)
                        if p then
                            punishments[name] = { punishment = p.punishment, banDuration = p.banDuration }
                        end
                    end
                end
            end
        end
    end

    cb({ punishments = punishments })
end)

RegisterESXCallback('lyxguard:panel:saveDetectionSettings', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false }) end

    local group = xPlayer.getGroup()
    if not (group == 'admin' or group == 'superadmin' or group == 'owner') then
        return cb({ success = false, message = 'Sin permisos' })
    end

    if not data or not data.detections then
        return cb({ success = false, message = 'Datos inválidos' })
    end

    local overrides = {}
    local pushList = {}

    for name, settings in pairs(data.detections) do
        local target = _FindDetectionSection(name)
        if target then
            local enabled = settings.enabled and true or false
            local punishment = settings.punishment or target.punishment
            local banDuration = settings.banDuration or target.banDuration

            -- Aplicar en runtime
            target.enabled = enabled
            target.punishment = punishment
            if banDuration then target.banDuration = banDuration end

            overrides[name] = { enabled = enabled, punishment = punishment, banDuration = banDuration }
            pushList[#pushList + 1] = { name = name, enabled = enabled, punishment = punishment, banDuration = banDuration }

            -- Guardar tambien en RuntimeConfig (compat con GetRuntimeConfig)
            RuntimeConfig.detectionSettings[name] = { enabled = enabled, punishment = punishment }
        end
    end

    -- Persistir segun modo
    local okPersist = _SaveOverrides(overrides, xPlayer.getName())

    -- Guardar preset elegido (si vino)
    if data.preset then
        if Config then Config.Preset = data.preset end
        _SaveMeta('preset', data.preset)
    end

    -- Re-push live a clientes conectados
    _PushToClients(pushList)

    print(('^2[LyxGuard]^7 %s actualizó %d detecciones (persist=%s)'):format(
        xPlayer.getName(), #pushList, _PersistMode()
    ))

    cb({ success = okPersist ~= false, persisted = _PersistMode() })
end)

RegisterESXCallback('lyxguard:panel:resetDetectionDefaults', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false }) end

    local group = xPlayer.getGroup()
    if not (group == 'admin' or group == 'superadmin' or group == 'owner') then
        return cb({ success = false, message = 'Sin permisos' })
    end

    -- Limpiar overrides en runtime y persistencia
    RuntimeConfig.detectionSettings = {}

    local mode = _PersistMode()
    if mode == 'database' then
        MySQL.Async.execute('DELETE FROM lyxguard_config_overrides', {})
    elseif mode == 'json' then
        local d = _JsonRead()
        d.detections = {}
        _JsonWrite(d)
    end

    print(('^2[LyxGuard]^7 %s reseteó overrides de detecciones (persist=%s). Reinicia el recurso para recargar defaults del config.'):format(
        xPlayer.getName(), mode
    ))

    cb({ success = true, message = 'Overrides borrados. Reinicia el recurso para aplicar los defaults del config.' })
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- HELPER FUNCTION: Check if player is whitelisted
-- ═══════════════════════════════════════════════════════════════════════════════

function IsPlayerWhitelisted(identifier, callback)
    MySQL.Async.fetchAll('SELECT * FROM lyxguard_whitelist WHERE identifier = @id', {
        ['@id'] = identifier
    }, function(results)
        if results and #results > 0 then
            callback(true, results[1])
        else
            callback(false, nil)
        end
    end)
end

-- Export for other modules
exports('IsPlayerWhitelisted', IsPlayerWhitelisted)
exports('GetRuntimeConfig', function() return RuntimeConfig end)

print('[LyxGuard] Admin Config server module loaded')
