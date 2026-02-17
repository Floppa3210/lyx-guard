--[[
    LyxGuard v4.0 - Admin Config Server Callbacks
    Server-side ESX callbacks for Admin Config panel functionality
]]

-- ESX is provided by @es_extended/imports.lua; keep a bounded fallback via bootstrap.
ESX = ESX or _G.ESX
if not ESX and LyxGuard and LyxGuard.WaitForESX then
    ESX = LyxGuard.WaitForESX(15000)
end

if not ESX then
    print('^1[LyxGuard]^7 admin_config: ESX no disponible (timeout). Callbacks no registrados.')
    return
end

_G.ESX = _G.ESX or ESX

-- Runtime configuration storage (overrides config.lua settings)
local RuntimeConfig = {
    immuneGroups = {},
    vipSettings = {},
    detectionSettings = {}
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- WHITELIST CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════════

ESX.RegisterServerCallback('lyxguard:panel:getWhitelist', function(source, cb)
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

ESX.RegisterServerCallback('lyxguard:panel:addToWhitelist', function(source, cb, data)
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

ESX.RegisterServerCallback('lyxguard:panel:removeFromWhitelist', function(source, cb, data)
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

ESX.RegisterServerCallback('lyxguard:panel:getImmuneGroups', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ groups = {} }) end
    
    -- Return from runtime config or from Config file
    local groups = RuntimeConfig.immuneGroups
    if #groups == 0 and Config and Config.Permissions and Config.Permissions.immuneGroups then
        groups = Config.Permissions.immuneGroups
    end
    
    cb({ groups = groups })
end)

ESX.RegisterServerCallback('lyxguard:panel:saveImmuneGroups', function(source, cb, data)
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

ESX.RegisterServerCallback('lyxguard:panel:saveVipSettings', function(source, cb, data)
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
-- DETECTION SETTINGS CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════════

ESX.RegisterServerCallback('lyxguard:panel:getDetectionSettings', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ detections = {} }) end
    
    -- Build detection settings from Config
    local detections = {}
    
    -- Movement detections
    if Config and Config.Movement then
        for name, settings in pairs(Config.Movement) do
            if type(settings) == 'table' and settings.enabled ~= nil then
                detections[name] = {
                    enabled = settings.enabled,
                    punishment = settings.punishment or 'notify'
                }
            end
        end
    end
    
    -- Combat detections
    if Config and Config.Combat then
        for name, settings in pairs(Config.Combat) do
            if type(settings) == 'table' and settings.enabled ~= nil then
                detections[name] = {
                    enabled = settings.enabled,
                    punishment = settings.punishment or 'notify'
                }
            end
        end
    end
    
    -- Entity detections
    if Config and Config.Entities then
        for name, settings in pairs(Config.Entities) do
            if type(settings) == 'table' and settings.enabled ~= nil then
                detections[name] = {
                    enabled = settings.enabled,
                    punishment = settings.punishment or 'notify'
                }
            end
        end
    end
    
    -- Advanced detections
    if Config and Config.Advanced then
        for name, settings in pairs(Config.Advanced) do
            if type(settings) == 'table' and settings.enabled ~= nil then
                detections[name] = {
                    enabled = settings.enabled,
                    punishment = settings.punishment or 'notify'
                }
            end
        end
    end
    
    -- Override with runtime settings if any
    for name, settings in pairs(RuntimeConfig.detectionSettings) do
        detections[name] = settings
    end
    
    cb({ detections = detections })
end)

ESX.RegisterServerCallback('lyxguard:panel:saveDetectionSettings', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false }) end
    
    local group = xPlayer.getGroup()
    if not (group == 'admin' or group == 'superadmin' or group == 'owner') then
        return cb({ success = false, message = 'Sin permisos' })
    end
    
    if not data or not data.detections then
        return cb({ success = false, message = 'Datos inválidos' })
    end
    
    -- Update runtime config
    for name, settings in pairs(data.detections) do
        RuntimeConfig.detectionSettings[name] = settings
        
        -- Also update Config if available
        -- Movement
        if Config and Config.Movement and Config.Movement[name] then
            Config.Movement[name].enabled = settings.enabled
            Config.Movement[name].punishment = settings.punishment
        end
        -- Combat
        if Config and Config.Combat and Config.Combat[name] then
            Config.Combat[name].enabled = settings.enabled
            Config.Combat[name].punishment = settings.punishment
        end
        -- Entities
        if Config and Config.Entities and Config.Entities[name] then
            Config.Entities[name].enabled = settings.enabled
            Config.Entities[name].punishment = settings.punishment
        end
        -- Advanced
        if Config and Config.Advanced and Config.Advanced[name] then
            Config.Advanced[name].enabled = settings.enabled
            Config.Advanced[name].punishment = settings.punishment
        end
    end
    
    print(('[LyxGuard] %s updated detection settings'):format(xPlayer.getName()))
    
    cb({ success = true })
end)

ESX.RegisterServerCallback('lyxguard:panel:resetDetectionDefaults', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false }) end
    
    local group = xPlayer.getGroup()
    if not (group == 'admin' or group == 'superadmin' or group == 'owner') then
        return cb({ success = false, message = 'Sin permisos' })
    end
    
    -- Clear runtime overrides
    RuntimeConfig.detectionSettings = {}
    
    print(('[LyxGuard] %s reset detection settings to defaults'):format(xPlayer.getName()))
    
    cb({ success = true })
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
