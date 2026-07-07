--[[
    
                            LYXGUARD v4.0 - PANEL SERVER                           
                            Optimizado para ESX Legacy 1.9+                        
    
]]

-- Use ESX global from @es_extended/imports.lua when available.
local ESX = ESX
local PanelAdmins = {}

local _PanelCooldowns = {}
local _GuardPanelActionSecurityState = {
    sessions = {},
    contexts = {},
}
local _GuardPanelRandSeeded = false

local function _NowMs()
    return GetGameTimer()
end

local function _GetGuardRiskExport(fnName, ...)
    local resource = GetCurrentResourceName()
    if not exports or not exports[resource] or type(exports[resource][fnName]) ~= 'function' then
        return nil
    end

    local ok, result = pcall(function(...)
        return exports[resource][fnName](...)
    end, ...)
    if ok then
        return result
    end
    return nil
end

local function _GetRiskThresholdValue(name, defaultValue)
    local thresholds = Config and Config.Risk and Config.Risk.thresholds or nil
    return tonumber(thresholds and thresholds[name]) or tonumber(defaultValue) or 0
end

local function _GetRiskProfile(identifier)
    local profile = _GetGuardRiskExport('GetRiskProfile', identifier)
    if type(profile) ~= 'table' then
        return {
            identifier = tostring(identifier or 'unknown'),
            score = 0,
            level = 'low',
            flagCount = 0,
            recentSignals = {}
        }
    end
    return profile
end

local function _GetTopRiskProfiles(limit, minScore)
    local rows = _GetGuardRiskExport('GetTopRiskProfiles', limit, minScore)
    if type(rows) == 'table' then
        return rows
    end
    return {}
end

local function _FindOnlinePlayerNameByIdentifier(identifier)
    if type(identifier) ~= 'string' or identifier == '' or type(GetIdentifier) ~= 'function' then
        return nil
    end

    for _, src in ipairs(GetPlayers()) do
        local playerId = tonumber(src)
        if playerId and GetIdentifier(playerId, 'license') == identifier then
            return GetPlayerName(playerId)
        end
    end

    return nil
end

local function _AuditGuardAction(src, action, result, reason, targetId, targetName, metadata)
    if type(LyxGuardPushExhaustiveLog) ~= 'function' then
        return
    end

    src = tonumber(src)
    local actorId = nil
    if src and src > 0 and type(GetIdentifier) == 'function' then
        actorId = GetIdentifier(src, 'license') or GetIdentifier(src, 'steam') or ('src:' .. tostring(src))
    else
        actorId = 'system'
    end

    local actorName = (src and src > 0 and GetPlayerName(src)) or 'system'
    pcall(LyxGuardPushExhaustiveLog, {
        level = (result == 'blocked') and 'warn' or 'info',
        actor_type = (src and src > 0) and 'admin' or 'system',
        actor_id = actorId,
        actor_name = actorName,
        target_id = targetId,
        target_name = targetName,
        resource = 'lyx-guard',
        action = action,
        result = result or 'allowed',
        reason = reason,
        metadata = metadata or {}
    })
end

local function _GetGuardPanelActionSecurityCfg()
    local root = Config and Config.TriggerProtection and Config.TriggerProtection.guardPanelEventProtection or nil
    local cfg = root and root.actionSecurity or nil

    local out = {
        enabled = cfg == nil or cfg.enabled ~= false,
        requireForPanelEvents = cfg == nil or cfg.requireForPanelEvents ~= false,
        tokenTtlMs = tonumber(cfg and cfg.tokenTtlMs) or (5 * 60 * 1000),
        nonceTtlMs = tonumber(cfg and cfg.nonceTtlMs) or (5 * 60 * 1000),
        maxUsedNonces = tonumber(cfg and cfg.maxUsedNonces) or 2048,
        maxClockSkewMs = tonumber(cfg and cfg.maxClockSkewMs) or 180000,
        contextTtlMs = tonumber(cfg and cfg.contextTtlMs) or 15000,
        tokenMinLen = tonumber(cfg and cfg.tokenMinLen) or 24,
        tokenMaxLen = tonumber(cfg and cfg.tokenMaxLen) or 128,
        nonceMinLen = tonumber(cfg and cfg.nonceMinLen) or 16,
        nonceMaxLen = tonumber(cfg and cfg.nonceMaxLen) or 128,
        correlationMinLen = tonumber(cfg and cfg.correlationMinLen) or 10,
        correlationMaxLen = tonumber(cfg and cfg.correlationMaxLen) or 128,
    }

    if out.tokenTtlMs < 30000 then out.tokenTtlMs = 30000 end
    if out.nonceTtlMs < 15000 then out.nonceTtlMs = 15000 end
    if out.maxUsedNonces < 128 then out.maxUsedNonces = 128 end
    if out.maxClockSkewMs < 10000 then out.maxClockSkewMs = 10000 end
    if out.contextTtlMs < 5000 then out.contextTtlMs = 5000 end

    return out
end

local function _EnsureGuardPanelRandomSeed()
    if _GuardPanelRandSeeded then return end
    local base = (os.time() or 0) + (_NowMs() or 0) + math.floor((os.clock() or 0) * 1000)
    math.randomseed(base)
    for _ = 1, 10 do math.random() end
    _GuardPanelRandSeeded = true
end

local function _GenerateGuardPanelSecureId(prefix, bytes)
    _EnsureGuardPanelRandomSeed()
    bytes = tonumber(bytes) or 20
    if bytes < 8 then bytes = 8 end
    if bytes > 48 then bytes = 48 end

    local chunks = {}
    for _ = 1, bytes do
        chunks[#chunks + 1] = string.format('%02x', math.random(0, 255))
    end

    local pre = tostring(prefix or 'id')
    return pre .. '_' .. table.concat(chunks)
end

local function _GetGuardPanelActionSession(source, createIfMissing)
    source = tonumber(source)
    if not source or source <= 0 then
        return nil
    end

    local session = _GuardPanelActionSecurityState.sessions[source]
    if session then
        return session
    end
    if createIfMissing ~= true then
        return nil
    end

    session = {
        token = nil,
        issuedAtMs = 0,
        expiresAtMs = 0,
        consumedNonces = {},
        nonceQueue = {},
        seq = 0,
    }
    _GuardPanelActionSecurityState.sessions[source] = session
    return session
end

local function _CleanupGuardPanelConsumedNonces(session, nowMs, cfg)
    if type(session) ~= 'table' then return end
    if type(session.nonceQueue) ~= 'table' then
        session.nonceQueue = {}
    end
    if type(session.consumedNonces) ~= 'table' then
        session.consumedNonces = {}
    end

    local queue = session.nonceQueue
    local ttl = tonumber(cfg and cfg.nonceTtlMs) or 300000
    local maxNonces = tonumber(cfg and cfg.maxUsedNonces) or 2048

    while #queue > 0 do
        local first = queue[1]
        if type(first) ~= 'table' then
            table.remove(queue, 1)
        else
            local ts = tonumber(first.ts) or 0
            if ts <= 0 or (nowMs - ts) >= ttl or #queue > maxNonces then
                session.consumedNonces[first.nonce] = nil
                table.remove(queue, 1)
            else
                break
            end
        end
    end
end

local function _IssueGuardPanelActionSession(source, forceRenew)
    local cfg = _GetGuardPanelActionSecurityCfg()
    local now = _NowMs()
    local session = _GetGuardPanelActionSession(source, true)
    if not session then
        return nil
    end

    local isExpired = (tonumber(session.expiresAtMs) or 0) <= now
    if forceRenew == true or isExpired or type(session.token) ~= 'string' then
        session.token = _GenerateGuardPanelSecureId('lygsec', 24)
        session.issuedAtMs = now
        session.expiresAtMs = now + cfg.tokenTtlMs
        session.consumedNonces = {}
        session.nonceQueue = {}
        session.seq = 0
    else
        session.expiresAtMs = math.max(session.expiresAtMs or 0, now + cfg.tokenTtlMs)
    end

    _GuardPanelActionSecurityState.sessions[source] = session
    return {
        enabled = cfg.enabled == true,
        token = session.token,
        tokenTtlMs = cfg.tokenTtlMs,
        nonceTtlMs = cfg.nonceTtlMs,
        maxClockSkewMs = cfg.maxClockSkewMs
    }
end

local function _ExtractGuardPanelSecurityEnvelope(eventData)
    if type(eventData) ~= 'table' then
        return nil
    end

    local argCount = #eventData
    if argCount <= 0 then
        return nil
    end

    local raw = eventData[argCount]
    if type(raw) ~= 'table' then
        return nil
    end

    local sec = raw.__lyxsec
    if type(sec) ~= 'table' then
        return nil
    end
    return sec
end

function ValidateGuardPanelActionEnvelope(source, eventName, eventData)
    local cfg = _GetGuardPanelActionSecurityCfg()
    if cfg.enabled ~= true then
        return true, nil, nil
    end

    local root = Config and Config.TriggerProtection and Config.TriggerProtection.guardPanelEventProtection or {}
    local eventPrefix = tostring(root.eventPrefix or 'lyxguard:panel:')
    if type(eventName) ~= 'string' or eventName == '' or eventName:sub(1, #eventPrefix) ~= eventPrefix then
        return true, nil, nil
    end

    local excluded = type(root.excludedEvents) == 'table' and root.excludedEvents or {}
    if excluded[eventName] == true then
        return true, nil, nil
    end

    if cfg.requireForPanelEvents ~= true then
        return true, nil, nil
    end

    local now = _NowMs()
    local session = _GetGuardPanelActionSession(source, false)
    if not session or type(session.token) ~= 'string' or (tonumber(session.expiresAtMs) or 0) <= now then
        return false, 'security_session_missing_or_expired', { event = eventName }
    end

    local sec = _ExtractGuardPanelSecurityEnvelope(eventData)
    if type(sec) ~= 'table' then
        return false, 'security_envelope_missing', { event = eventName }
    end

    local token = tostring(sec.token or '')
    local nonce = tostring(sec.nonce or '')
    local correlationId = tostring(sec.correlation_id or sec.correlationId or '')
    local ts = tonumber(sec.ts) or 0

    if #token < cfg.tokenMinLen or #token > cfg.tokenMaxLen then
        return false, 'security_token_bad_length', { len = #token }
    end
    if token ~= session.token then
        return false, 'security_token_mismatch', { event = eventName }
    end

    if #nonce < cfg.nonceMinLen or #nonce > cfg.nonceMaxLen then
        return false, 'security_nonce_bad_length', { len = #nonce }
    end
    if not nonce:match('^[%w%-%_%.:]+$') then
        return false, 'security_nonce_bad_format', { nonce = nonce:sub(1, 32) }
    end

    if #correlationId < cfg.correlationMinLen or #correlationId > cfg.correlationMaxLen then
        return false, 'security_correlation_bad_length', { len = #correlationId }
    end

    if ts > 0 then
        local serverEpochMs = os.time() * 1000
        if math.abs(serverEpochMs - ts) > cfg.maxClockSkewMs then
            return false, 'security_timestamp_out_of_window', {
                clientTs = ts,
                serverTs = serverEpochMs
            }
        end
    end

    _CleanupGuardPanelConsumedNonces(session, now, cfg)
    if session.consumedNonces[nonce] then
        return false, 'security_nonce_replay', {
            nonce = nonce:sub(1, 32),
            correlation_id = correlationId
        }
    end

    session.seq = (tonumber(session.seq) or 0) + 1
    session.consumedNonces[nonce] = now
    session.nonceQueue[#session.nonceQueue + 1] = { nonce = nonce, ts = now }
    _CleanupGuardPanelConsumedNonces(session, now, cfg)
    session.expiresAtMs = math.max(tonumber(session.expiresAtMs) or 0, now + cfg.tokenTtlMs)
    _GuardPanelActionSecurityState.sessions[source] = session

    local ctx = {
        source = source,
        event = tostring(eventName or ''),
        nonce = nonce,
        correlation_id = correlationId,
        seq = session.seq,
        ts = now
    }
    _GuardPanelActionSecurityState.contexts[source] = ctx
    return true, nil, ctx
end

function GetGuardPanelActionSecurityForClient(source)
    local cfg = _GetGuardPanelActionSecurityCfg()
    if cfg.enabled ~= true then
        return { enabled = false }
    end
    return _IssueGuardPanelActionSession(source, false) or { enabled = false }
end

local function _IsRateLimited(src, key, cooldownMs)
    if not src or src <= 0 then return true end
    local now = GetGameTimer()
    _PanelCooldowns[src] = _PanelCooldowns[src] or {}
    local last = _PanelCooldowns[src][key] or 0
    if (now - last) < (cooldownMs or 0) then
        return true
    end
    _PanelCooldowns[src][key] = now
    return false
end

local _PanelQueryCache = {
    stats = {
        value = nil,
        expiresAtMs = 0,
        ttlMs = 5000
    },
    recentEvents = {},
    playerDetails = {}
}

local function _ReadPanelCache(entry)
    if type(entry) ~= 'table' or entry.value == nil then
        return nil
    end
    if (tonumber(entry.expiresAtMs) or 0) <= _NowMs() then
        return nil
    end
    return entry.value
end

local function _WritePanelCache(entry, value, ttlMs)
    if type(entry) ~= 'table' then
        return value
    end
    entry.value = value
    entry.expiresAtMs = _NowMs() + math.max(tonumber(ttlMs or entry.ttlMs) or 0, 250)
    return value
end

local function _InvalidatePanelQueryCache(opts)
    opts = opts or {}

    if opts.stats ~= false then
        _PanelQueryCache.stats.value = nil
        _PanelQueryCache.stats.expiresAtMs = 0
    end

    if opts.recentEvents ~= false then
        _PanelQueryCache.recentEvents = {}
    end

    if opts.playerDetails ~= false then
        local identifier = opts.identifier and tostring(opts.identifier) or ''
        if identifier ~= '' then
            _PanelQueryCache.playerDetails[identifier] = nil
        else
            _PanelQueryCache.playerDetails = {}
        end
    end
end

-- 
-- CONTROL DE ACCESO
-- 

local function _IsValidIdentifier(identifier)
    if type(identifier) ~= 'string' then return false end
    identifier = identifier:gsub('%s+', '')
    if #identifier < 6 or #identifier > 128 then return false end

    local prefix, value = identifier:match('^(%w+):(.+)$')
    if not prefix or not value then
        return false
    end

    prefix = prefix:lower()
    local allowed = {
        license = true,
        steam = true,
        discord = true,
        fivem = true,
        xbl = true,
        live = true,
        ip = true
    }
    if not allowed[prefix] then
        return false
    end

    return value:match('^[%w%._%-]+$') ~= nil
end

local function HasPanelAccess(source)
    -- ACE permissions primero (mas rapido)
    local acePerms = (Config and Config.Panel and Config.Panel.acePermissions) or { 'lyxguard.panel' }
    for _, perm in ipairs(acePerms) do
        if IsPlayerAceAllowed(source, perm) then return true end
    end

    -- ESX group check - SOLO grupos de administracin avanzada
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            local group = xPlayer.getGroup()
            -- Solo permitir grupos de administracin avanzada
            local advancedGroups = (Config and Config.Panel and Config.Panel.allowedGroups) or
                { 'superadmin', 'admin', 'master', 'owner' }
            for _, g in ipairs(advancedGroups) do
                if group == g then return true end
            end
        end
    end

    return false
end

local function CanManageBans(source)
    if not source or source <= 0 then return false end

    if IsPlayerAceAllowed(source, 'lyxguard.admin') then
        return true
    end

    if ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            local g = xPlayer.getGroup()
            local adminGroups = { superadmin = true, admin = true, master = true, owner = true }
            if adminGroups[g] then
                return true
            end
        end
    end

    return false
end

local _WebhookTypes = { 'detections', 'bans', 'kicks', 'warnings', 'logs', 'screenshots', 'alerts' }

local function _IsValidDiscordWebhookUrl(url)
    if not url or type(url) ~= 'string' then return false end
    if url == '' then return true end -- allow clearing
    return (string.match(url, '^https://discord%.com/api/webhooks/') ~= nil) or
        (string.match(url, '^https://discordapp%.com/api/webhooks/') ~= nil)
end

local function _ApplyWebhookOverrides()
    if not Config or not Config.Discord or not Config.Discord.webhooks then return end

    for _, t in ipairs(_WebhookTypes) do
        local v = GetResourceKvpString('lyxguard_webhook_' .. t)
        if v and v ~= '' then
            Config.Discord.webhooks[t] = v
        end
    end
end

CreateThread(function()
    Wait(0)
    _ApplyWebhookOverrides()
end)

RegisterNetEvent('lyxguard:panel:saveWebhooks', function(data)
    local src = source
    if not HasPanelAccess(src) then
        _AuditGuardAction(src, 'guard_panel_save_webhooks', 'blocked', 'no_panel_access')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Sin acceso')
    end

    -- Restrict config edits to high-privilege admins.
    if not CanManageBans(src) then
        _AuditGuardAction(src, 'guard_panel_save_webhooks', 'blocked', 'no_permission')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Sin permisos')
    end

    if type(data) ~= 'table' then
        _AuditGuardAction(src, 'guard_panel_save_webhooks', 'blocked', 'invalid_payload')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Datos invalidos')
    end

    if not Config or not Config.Discord then Config = Config or {}; Config.Discord = Config.Discord or {} end
    Config.Discord.webhooks = Config.Discord.webhooks or {}

    for _, t in ipairs(_WebhookTypes) do
        local url = data[t]
        if url ~= nil then
            url = tostring(url or ''):gsub('%s+$', '')

            if not _IsValidDiscordWebhookUrl(url) then
                _AuditGuardAction(src, 'guard_panel_save_webhooks', 'blocked', 'invalid_webhook_url', tostring(t))
                TriggerClientEvent('lyxguard:notify', src, 'error', ('Webhook invalido: %s'):format(t))
                return
            end

            if url == '' then
                DeleteResourceKvp('lyxguard_webhook_' .. t)
                Config.Discord.webhooks[t] = ''
            else
                SetResourceKvp('lyxguard_webhook_' .. t, url)
                Config.Discord.webhooks[t] = url
            end
        end
    end

    TriggerClientEvent('lyxguard:notify', src, 'success', 'Webhooks guardados')
    _AuditGuardAction(src, 'guard_panel_save_webhooks', 'allowed', nil, nil, nil, { updated = true })
end)

-- Broadcast to all panel admins
local function BroadcastToPanelAdmins(eventName, data)
    for admin, _ in pairs(PanelAdmins) do
        TriggerClientEvent('lyxguard:panel:' .. eventName, admin, data)
    end
end

-- 
-- STATS & DATA
-- 

local function GetPanelStatsAsync(cb, forceRefresh)
    if type(cb) ~= 'function' then return end

    local cached = forceRefresh ~= true and _ReadPanelCache(_PanelQueryCache.stats)
    if cached then
        cb(cached)
        return
    end

    MySQL.query([[
        SELECT
            (SELECT COUNT(*) FROM lyxguard_detections WHERE DATE(detection_date) = CURDATE()) AS detectionsToday,
            (SELECT COUNT(*) FROM lyxguard_bans WHERE active = 1) AS bansActive,
            (SELECT COUNT(*) FROM lyxguard_warnings WHERE active = 1) AS warnings
    ]], {}, function(rows)
        local row = rows and rows[1] or {}
        local notifyAt = _GetRiskThresholdValue('notify', 20)
        local staffAlertAt = _GetRiskThresholdValue('staffAlert', 60)
        local suspiciousProfiles = _GetTopRiskProfiles(500, notifyAt)
        local highRiskProfiles = _GetTopRiskProfiles(500, staffAlertAt)
        local stats = {
            players = #GetPlayers(),
            maxPlayers = GetConvarInt('sv_maxclients', 32),
            detectionsToday = tonumber(row and row.detectionsToday) or 0,
            bansActive = tonumber(row and row.bansActive) or 0,
            warnings = tonumber(row and row.warnings) or 0,
            suspicious = #suspiciousProfiles,
            highRiskPlayers = #highRiskProfiles
        }
        cb(_WritePanelCache(_PanelQueryCache.stats, stats, _PanelQueryCache.stats.ttlMs))
    end)
end

local function GetRecentEventsAsync(limit, cb, forceRefresh)
    if type(cb) ~= 'function' then return end

    limit = math.floor(tonumber(limit) or 20)
    if limit < 1 then limit = 1 end
    if limit > 100 then limit = 100 end

    local cacheKey = tostring(limit)
    local entry = _PanelQueryCache.recentEvents[cacheKey]
    if not entry then
        entry = {
            value = nil,
            expiresAtMs = 0,
            ttlMs = 3000
        }
        _PanelQueryCache.recentEvents[cacheKey] = entry
    end

    local cached = forceRefresh ~= true and _ReadPanelCache(entry)
    if cached then
        cb(cached)
        return
    end

    MySQL.query([[
        SELECT 'detection' as type, player_name, detection_type, detection_date as time, identifier
        FROM lyxguard_detections ORDER BY detection_date DESC LIMIT ?
    ]], { limit }, function(rows)
        cb(_WritePanelCache(entry, rows or {}, entry.ttlMs))
    end)
end

local function GetPlayerDetailsAsync(identifier, cb, forceRefresh)
    if type(cb) ~= 'function' then return end

    identifier = tostring(identifier or ''):gsub('%s+', '')
    if identifier == '' then
        cb({})
        return
    end

    local entry = _PanelQueryCache.playerDetails[identifier]
    if not entry then
        entry = {
            value = nil,
            expiresAtMs = 0,
            ttlMs = 5000
        }
        _PanelQueryCache.playerDetails[identifier] = entry
    end

    local cached = forceRefresh ~= true and _ReadPanelCache(entry)
    if cached then
        cb(cached)
        return
    end

    MySQL.query([[
        SELECT
            COALESCE((
                SELECT player_name
                FROM lyxguard_detections
                WHERE identifier = ?
                ORDER BY detection_date DESC
                LIMIT 1
            ), 'Unknown') AS player_name,
            (SELECT COUNT(*) FROM lyxguard_detections WHERE identifier = ?) AS detections,
            (SELECT COUNT(*) FROM lyxguard_warnings WHERE identifier = ? AND active = 1) AS warnings,
            (SELECT COUNT(*) FROM lyxguard_bans WHERE identifier = ?) AS bans
    ]], { identifier, identifier, identifier, identifier }, function(rows)
        local row = rows and rows[1] or {}
        local risk = _GetRiskProfile(identifier)
        local player = {
            identifier = identifier,
            name = tostring(row.player_name or risk.playerName or 'Unknown'),
            detections = tonumber(row.detections) or 0,
            warnings = tonumber(row.warnings) or 0,
            bans = tonumber(row.bans) or 0,
            riskScore = tonumber(risk.score) or 0,
            riskLevel = tostring(risk.level or 'low'),
            riskSignals = tonumber(risk.flagCount) or 0,
            lastRiskSignal = risk.lastReason,
            recentRiskSignals = risk.recentSignals or {}
        }
        cb(_WritePanelCache(entry, player, entry.ttlMs))
    end)
end

local function BroadcastStatsRefresh()
    GetPanelStatsAsync(function(stats)
        BroadcastToPanelAdmins('refreshStats', stats or {})
    end, true)
end

-- 
-- PANEL OPEN/CLOSE
-- 

RegisterNetEvent('lyxguard:panel:open', function()
    local src = source
    if not HasPanelAccess(src) then
        _AuditGuardAction(src, 'guard_panel_open', 'blocked', 'no_panel_access')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Sin acceso')
    end

    local security = _IssueGuardPanelActionSession(src, true)
    PanelAdmins[src] = true
    GetPanelStatsAsync(function(stats)
        GetRecentEventsAsync(20, function(recentEvents)
            TriggerClientEvent('lyxguard:panel:openUI', src, {
                config = { soundEnabled = true, autoRefresh = true },
                stats = stats or {},
                recentEvents = recentEvents or {},
                security = security or { enabled = false }
            })
            _AuditGuardAction(src, 'guard_panel_open', 'allowed')
        end)
    end)
end)

RegisterNetEvent('lyxguard:panel:close', function()
    local src = source
    PanelAdmins[src] = nil
    _GuardPanelActionSecurityState.sessions[src] = nil
    _GuardPanelActionSecurityState.contexts[src] = nil
    _AuditGuardAction(src, 'guard_panel_close', 'allowed')
end)

-- 
-- ESX CALLBACKS (Registered after ESX is ready)
-- 

CreateThread(function()
    local resolved = ESX
    if LyxGuard and LyxGuard.WaitForESX then
        resolved = LyxGuard.WaitForESX(15000)
    end
    resolved = resolved or _G.ESX

    if not resolved then
        print('^3[LyxGuard]^7 panel: ESX no disponible (timeout inicial). Reintentando cada 2s...')
        while not resolved do
            Wait(2000)
            if LyxGuard and LyxGuard.GetESX then
                resolved = LyxGuard.GetESX()
            end
            if not resolved and LyxGuard and LyxGuard.WaitForESX then
                resolved = LyxGuard.WaitForESX(2000)
            end
            resolved = resolved or ESX or _G.ESX
        end
        print('^2[LyxGuard]^7 panel: ESX detectado tras reintento. Registrando callbacks.')
    end

    ESX = resolved
    _G.ESX = _G.ESX or resolved

    ESX.RegisterServerCallback('lyxguard:panel:getStats', function(source, cb)
        if not HasPanelAccess(source) then return cb({}) end
        GetPanelStatsAsync(cb)
    end)

    ESX.RegisterServerCallback('lyxguard:panel:getRecentActivity', function(source, cb)
        if not HasPanelAccess(source) then return cb({ events = {} }) end
        GetRecentEventsAsync(20, function(events)
            cb({ events = events or {} })
        end)
    end)

    ESX.RegisterServerCallback('lyxguard:panel:getDetections', function(source, cb, data)
        if not HasPanelAccess(source) then return cb({ detections = {} }) end

        local filter = data and data.filter or 'all'
        local query = 'SELECT * FROM lyxguard_detections'
        local params = {}

        if filter ~= 'all' then
            query = query .. ' WHERE detection_type LIKE ?'
            params[1] = '%' .. filter .. '%'
        end

        MySQL.query(query .. ' ORDER BY detection_date DESC LIMIT 100', params, function(r)
            cb({ detections = r or {} })
        end)
    end)

    ESX.RegisterServerCallback('lyxguard:panel:getBans', function(source, cb, data)
        if not HasPanelAccess(source) then return cb({ bans = {} }) end

        local filter = data and data.filter or 'active'
        local query = 'SELECT * FROM lyxguard_bans'

        if filter == 'active' then
            query = query .. ' WHERE active = 1'
        elseif filter == 'expired' then
            query = query .. ' WHERE active = 0'
        end

        MySQL.query(query .. ' ORDER BY ban_date DESC LIMIT 100', {}, function(r)
            cb({ bans = r or {} })
        end)
    end)

    ESX.RegisterServerCallback('lyxguard:panel:getWarnings', function(source, cb)
        if not HasPanelAccess(source) then return cb({ warnings = {} }) end
        MySQL.query('SELECT * FROM lyxguard_warnings WHERE active = 1 ORDER BY warn_date DESC LIMIT 100', {}, function(r)
            cb({ warnings = r or {} })
        end)
    end)

    ESX.RegisterServerCallback('lyxguard:panel:getSuspicious', function(source, cb)
        if not HasPanelAccess(source) then return cb({ players = {} }) end
        local notifyAt = _GetRiskThresholdValue('notify', 20)
        MySQL.query([[
            SELECT d.identifier, MAX(d.player_name) as player_name,
                   COUNT(*) as detection_count,
                   (SELECT COUNT(*) FROM lyxguard_warnings w WHERE w.identifier = d.identifier AND w.active = 1) AS warning_count
            FROM lyxguard_detections d
            WHERE detection_date >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
            GROUP BY d.identifier
            HAVING COUNT(*) >= 2
            ORDER BY detection_count DESC LIMIT 50
        ]], {}, function(r)
            local merged = {}

            for _, row in ipairs(r or {}) do
                local identifier = tostring(row.identifier or '')
                if identifier ~= '' then
                    local risk = _GetRiskProfile(identifier)
                    merged[identifier] = {
                        identifier = identifier,
                        player_name = tostring(row.player_name or risk.playerName or _FindOnlinePlayerNameByIdentifier(identifier) or 'Unknown'),
                        detection_count = tonumber(row.detection_count) or 0,
                        warning_count = tonumber(row.warning_count) or 0,
                        risk_score = tonumber(risk.score) or 0,
                        risk_level = tostring(risk.level or 'low'),
                        risk_signals = tonumber(risk.flagCount) or 0,
                        last_signal = risk.lastReason
                    }
                end
            end

            for _, risk in ipairs(_GetTopRiskProfiles(100, notifyAt)) do
                local identifier = tostring(risk.identifier or '')
                if identifier ~= '' then
                    local row = merged[identifier]
                    if not row then
                        row = {
                            identifier = identifier,
                            player_name = risk.playerName or _FindOnlinePlayerNameByIdentifier(identifier) or 'Unknown',
                            detection_count = 0,
                            warning_count = 0
                        }
                        merged[identifier] = row
                    end
                    row.risk_score = tonumber(risk.score) or 0
                    row.risk_level = tostring(risk.level or 'low')
                    row.risk_signals = tonumber(risk.flagCount) or 0
                    row.last_signal = risk.lastReason
                end
            end

            local players = {}
            for _, row in pairs(merged) do
                players[#players + 1] = row
            end

            table.sort(players, function(a, b)
                local riskA = tonumber(a.risk_score) or 0
                local riskB = tonumber(b.risk_score) or 0
                if riskA == riskB then
                    local detA = tonumber(a.detection_count) or 0
                    local detB = tonumber(b.detection_count) or 0
                    if detA == detB then
                        return tostring(a.player_name or '') < tostring(b.player_name or '')
                    end
                    return detA > detB
                end
                return riskA > riskB
            end)

            cb({ players = players })
        end)
    end)

    ESX.RegisterServerCallback('lyxguard:panel:getPlayerDetails', function(source, cb, data)
        if not HasPanelAccess(source) then return cb({}) end

        local identifier = data and data.identifier
        if not identifier then return cb({}) end
        GetPlayerDetailsAsync(identifier, cb)
    end)

    print('^2[LyxGuard]^7 Panel callbacks registered')
end)

-- 
-- PANEL ACTIONS
-- 

RegisterNetEvent('lyxguard:panel:unban', function(data)
    local src = source
    if not HasPanelAccess(src) then
        _AuditGuardAction(src, 'guard_panel_unban', 'blocked', 'no_panel_access')
        return
    end
    if not CanManageBans(src) then
        _AuditGuardAction(src, 'guard_panel_unban', 'blocked', 'no_permission')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Sin permisos')
    end
    if _IsRateLimited(src, 'unban', 1500) then
        _AuditGuardAction(src, 'guard_panel_unban', 'blocked', 'rate_limited')
        return
    end
    if not data or not data.banId then
        _AuditGuardAction(src, 'guard_panel_unban', 'blocked', 'missing_ban_id')
        return
    end

    local banId = tonumber(data.banId)
    if not banId or banId <= 0 then
        _AuditGuardAction(src, 'guard_panel_unban', 'blocked', 'invalid_ban_id')
        return
    end

    MySQL.update('UPDATE lyxguard_bans SET active = 0, unbanned_by = ? WHERE id = ?',
        { GetPlayerName(src), banId }, function(affected)
            if affected > 0 then
                TriggerEvent('lyxguard:reloadBans')
                _InvalidatePanelQueryCache()
                BroadcastStatsRefresh()
                BroadcastPanelEvent({ type = 'unban', player = 'ID:' .. banId, unbanBy = GetPlayerName(src) })
                TriggerClientEvent('lyxguard:notify', src, 'success', 'Jugador desbaneado')
                _AuditGuardAction(src, 'guard_panel_unban', 'allowed', nil, tostring(banId), 'BanID:' .. tostring(banId))
            else
                TriggerClientEvent('lyxguard:notify', src, 'error', 'No se pudo desbanear')
                _AuditGuardAction(src, 'guard_panel_unban', 'blocked', 'unban_failed', tostring(banId),
                    'BanID:' .. tostring(banId))
            end
        end)
end)

RegisterNetEvent('lyxguard:panel:removeWarning', function(data)
    local src = source
    if not HasPanelAccess(src) then
        _AuditGuardAction(src, 'guard_panel_remove_warning', 'blocked', 'no_panel_access')
        return
    end
    if not CanManageBans(src) then
        _AuditGuardAction(src, 'guard_panel_remove_warning', 'blocked', 'no_permission')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Sin permisos')
    end
    if _IsRateLimited(src, 'removeWarning', 750) then
        _AuditGuardAction(src, 'guard_panel_remove_warning', 'blocked', 'rate_limited')
        return
    end
    if not data or not data.warningId then
        _AuditGuardAction(src, 'guard_panel_remove_warning', 'blocked', 'missing_warning_id')
        return
    end

    local warningId = tonumber(data.warningId)
    if not warningId or warningId <= 0 then
        _AuditGuardAction(src, 'guard_panel_remove_warning', 'blocked', 'invalid_warning_id')
        return
    end

    MySQL.update('UPDATE lyxguard_warnings SET active = 0 WHERE id = ?', { warningId }, function(affected)
        if affected and affected > 0 then
            _InvalidatePanelQueryCache()
            BroadcastStatsRefresh()
            TriggerClientEvent('lyxguard:notify', src, 'success', 'Warning removido')
            _AuditGuardAction(src, 'guard_panel_remove_warning', 'allowed', nil, tostring(warningId),
                'WarningID:' .. tostring(warningId))
        else
            TriggerClientEvent('lyxguard:notify', src, 'error', 'No se pudo remover')
            _AuditGuardAction(src, 'guard_panel_remove_warning', 'blocked', 'remove_failed', tostring(warningId),
                'WarningID:' .. tostring(warningId))
        end
    end)
end)

RegisterNetEvent('lyxguard:panel:banPlayer', function(data)
    local src = source
    if not HasPanelAccess(src) then
        _AuditGuardAction(src, 'guard_panel_ban_player', 'blocked', 'no_panel_access')
        return
    end
    if not CanManageBans(src) then
        _AuditGuardAction(src, 'guard_panel_ban_player', 'blocked', 'no_permission')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Sin permisos')
    end
    if not data or not data.identifier then
        _AuditGuardAction(src, 'guard_panel_ban_player', 'blocked', 'missing_identifier')
        return
    end
    if _IsRateLimited(src, 'banPlayer', 1500) then
        _AuditGuardAction(src, 'guard_panel_ban_player', 'blocked', 'rate_limited')
        return
    end

    local identifier = tostring(data.identifier or ''):gsub('%s+', '')
    if not _IsValidIdentifier(identifier) then
        _AuditGuardAction(src, 'guard_panel_ban_player', 'blocked', 'invalid_identifier', identifier)
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Identifier invalido')
    end

    local reason = LyxGuardLib and LyxGuardLib.Sanitize and LyxGuardLib.Sanitize(data.reason or 'Ban desde panel', 200) or
        tostring(data.reason or 'Ban desde panel')
    local playerName = LyxGuardLib and LyxGuardLib.Sanitize and LyxGuardLib.Sanitize(data.playerName or 'Unknown', 100) or
        tostring(data.playerName or 'Unknown')

    local duration = data.duration
    if duration ~= nil then
        if type(duration) == 'string' then
            duration = duration:lower()
        end
        -- accept duration keys or 'permanent'/0; everything else falls back to permanent
        local ok = (duration == 0 or duration == 'permanent' or duration == 'short' or duration == 'medium' or duration ==
            'long' or duration == 'verylong' or type(duration) == 'number')
        if not ok then
            duration = 'permanent'
        end
    else
        duration = 'permanent'
    end

    -- Buscar si esta online
    local targetSource = nil
    for _, pid in ipairs(GetPlayers()) do
        for _, id in ipairs(GetPlayerIdentifiers(pid)) do
            if id == identifier then
                targetSource = tonumber(pid)
                break
            end
        end
        if targetSource then break end
    end

    if targetSource and exports['lyx-guard'] then
        exports['lyx-guard']:BanPlayer(targetSource, reason, duration, GetPlayerName(src))
    else
        -- Calculating Unban Time for Offline Ban
        local isPermanent = (not duration or duration == 'permanent' or duration == 0)
        local unbanTime = nil
        if not isPermanent and LyxGuardLib and LyxGuardLib.GetUnbanTime then
            unbanTime = LyxGuardLib.GetUnbanTime(duration)
        end

        MySQL.insert([[
            INSERT INTO lyxguard_bans (identifier, player_name, reason, unban_date, permanent, banned_by)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], {
            identifier,
            playerName,
            reason,
            unbanTime and os.date('%Y-%m-%d %H:%M:%S', unbanTime) or nil,
            isPermanent and 1 or 0,
            GetPlayerName(src)
        }, function()
            TriggerEvent('lyxguard:reloadBans')
            _InvalidatePanelQueryCache()
            BroadcastStatsRefresh()
        end)
    end

    BroadcastPanelEvent({ type = 'ban', player = playerName, reason = reason })
    TriggerClientEvent('lyxguard:notify', src, 'success', 'Ban aplicado')
    _AuditGuardAction(src, 'guard_panel_ban_player', 'allowed', reason, identifier, playerName, {
        duration = duration,
        online_target = targetSource and true or false
    })
end)

RegisterNetEvent('lyxguard:panel:clearDetections', function(data)
    local src = source
    if not HasPanelAccess(src) then
        _AuditGuardAction(src, 'guard_panel_clear_detections', 'blocked', 'no_panel_access')
        return
    end
    if not CanManageBans(src) then
        _AuditGuardAction(src, 'guard_panel_clear_detections', 'blocked', 'no_permission')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Sin permisos')
    end
    if _IsRateLimited(src, 'clearDetections', 30000) then
        _AuditGuardAction(src, 'guard_panel_clear_detections', 'blocked', 'rate_limited')
        return
    end

    MySQL.Async.execute('TRUNCATE TABLE lyxguard_detections', {}, function()
        -- Notify all admins
        _InvalidatePanelQueryCache()
        BroadcastStatsRefresh()
        BroadcastToPanelAdmins('refreshDetections', {})
        TriggerClientEvent('lyxguard:notify', src, 'success', 'Detecciones limpiadas')
        _AuditGuardAction(src, 'guard_panel_clear_detections', 'allowed')
    end)
end)

-- BROADCASTING
-- 

function BroadcastPanelEvent(event)
    event.time = os.date('%Y-%m-%d %H:%M:%S')
    for adminSource, _ in pairs(PanelAdmins) do
        if GetPlayerName(adminSource) then
            TriggerClientEvent('lyxguard:panel:newEvent', adminSource, event)
        else
            PanelAdmins[adminSource] = nil
        end
    end
end

-- Hooks
AddEventHandler('lyxguard:onDetection', function(src, detectionType, details, punishment)
    _InvalidatePanelQueryCache()
    BroadcastPanelEvent({
        type = 'detection',
        player = GetPlayerName(src) or 'Unknown',
        detectionType = detectionType,
        punishment = punishment
    })
end)

AddEventHandler('lyxguard:onRiskEscalation', function(src, snapshot)
    _InvalidatePanelQueryCache()
    BroadcastStatsRefresh()
    BroadcastPanelEvent({
        type = 'suspicious',
        player = (snapshot and snapshot.playerName) or GetPlayerName(src) or 'Unknown',
        score = snapshot and snapshot.score or 0,
        level = snapshot and snapshot.level or 'low',
        lastSignal = snapshot and snapshot.lastSignal or 'unknown',
        message = ('Risk score %s (%s)'):format(tostring(snapshot and snapshot.score or 0), tostring(snapshot and snapshot.level or 'low'))
    })
end)

AddEventHandler('lyxguard:onBan', function(src, reason, duration, bannedBy)
    _InvalidatePanelQueryCache()
    BroadcastPanelEvent({ type = 'ban', player = GetPlayerName(src) or 'Unknown', reason = reason, bannedBy = bannedBy })
end)

AddEventHandler('lyxguard:onWarning', function(src, reason, warnedBy)
    _InvalidatePanelQueryCache()
    BroadcastPanelEvent({
        type = 'warning',
        player = GetPlayerName(src) or 'Unknown',
        reason = reason,
        warnedBy = warnedBy
    })
end)

-- 
-- COMANDO
-- 

RegisterCommand('lyxguard', function(source)
    if source == 0 then return print('[LyxGuard] Solo para jugadores') end
    if not HasPanelAccess(source) then
        return TriggerClientEvent('lyxguard:notify', source, 'error', 'Sin acceso')
    end

    local security = _IssueGuardPanelActionSession(source, true)
    PanelAdmins[source] = true
    GetPanelStatsAsync(function(stats)
        GetRecentEventsAsync(20, function(recentEvents)
            TriggerClientEvent('lyxguard:panel:openUI', source, {
                config = { soundEnabled = true, autoRefresh = true },
                stats = stats or {},
                recentEvents = recentEvents or {},
                security = security or { enabled = false }
            })
        end)
    end)
end, false)

-- Cleanup on disconnect
AddEventHandler('playerDropped', function()
    local src = source
    PanelAdmins[src] = nil
    _PanelCooldowns[src] = nil
    _GuardPanelActionSecurityState.sessions[src] = nil
    _GuardPanelActionSecurityState.contexts[src] = nil
end)

-- 
-- LIMPIEZA DE LOGS
-- 

-- Limpiar todos los logs (global)
RegisterNetEvent('lyxguard:panel:clearAllLogs', function()
    local src = source
    if not HasPanelAccess(src) then
        _AuditGuardAction(src, 'guard_panel_clear_all_logs', 'blocked', 'no_panel_access')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Sin acceso al panel')
    end

    if not CanManageBans(src) then
        _AuditGuardAction(src, 'guard_panel_clear_all_logs', 'blocked', 'no_permission')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Sin permisos')
    end

    if _IsRateLimited(src, 'clearAllLogs', 60000) then
        _AuditGuardAction(src, 'guard_panel_clear_all_logs', 'blocked', 'rate_limited')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Cooldown activo')
    end

    MySQL.query('TRUNCATE TABLE lyxguard_detections', {}, function()
        MySQL.query('TRUNCATE TABLE lyxguard_warnings', {}, function()
            local adminName = GetPlayerName(src) or 'Unknown'
            print(string.format('^3[LyxGuard]^7 %s limpi TODOS los logs', adminName))

            _InvalidatePanelQueryCache()
            TriggerClientEvent('lyxguard:notify', src, 'success', 'Todos los logs han sido eliminados')
            BroadcastStatsRefresh()
            _AuditGuardAction(src, 'guard_panel_clear_all_logs', 'allowed')
        end)
    end)
end)

-- Limpiar logs de un jugador especfico
RegisterNetEvent('lyxguard:panel:clearPlayerLogs', function(identifier)
    local src = source
    if not HasPanelAccess(src) then
        _AuditGuardAction(src, 'guard_panel_clear_player_logs', 'blocked', 'no_panel_access')
        return
    end
    if not CanManageBans(src) then
        _AuditGuardAction(src, 'guard_panel_clear_player_logs', 'blocked', 'no_permission')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Sin permisos')
    end
    if _IsRateLimited(src, 'clearPlayerLogs', 5000) then
        _AuditGuardAction(src, 'guard_panel_clear_player_logs', 'blocked', 'rate_limited')
        return
    end

    if not identifier or identifier == '' then
        _AuditGuardAction(src, 'guard_panel_clear_player_logs', 'blocked', 'missing_identifier')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Identifier invalido')
    end

    identifier = tostring(identifier or ''):gsub('%s+', '')
    if not _IsValidIdentifier(identifier) then
        _AuditGuardAction(src, 'guard_panel_clear_player_logs', 'blocked', 'invalid_identifier')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Identifier invalido')
    end

    MySQL.query('DELETE FROM lyxguard_detections WHERE identifier = ?', { identifier }, function()
        MySQL.query('DELETE FROM lyxguard_warnings WHERE identifier = ?', { identifier }, function()
            local adminName = GetPlayerName(src) or 'Unknown'
            print(string.format('^3[LyxGuard]^7 %s limpi logs de: %s', adminName, identifier))

            _InvalidatePanelQueryCache({ identifier = identifier })
            TriggerClientEvent('lyxguard:notify', src, 'success', 'Logs del jugador limpiados')
            BroadcastStatsRefresh()
            _AuditGuardAction(src, 'guard_panel_clear_player_logs', 'allowed', nil, identifier, nil)
        end)
    end)
end)

-- Limpiar advertencias de un jugador
RegisterNetEvent('lyxguard:panel:clearPlayerWarnings', function(identifier)
    local src = source
    if not HasPanelAccess(src) then
        _AuditGuardAction(src, 'guard_panel_clear_player_warnings', 'blocked', 'no_panel_access')
        return
    end
    if not CanManageBans(src) then
        _AuditGuardAction(src, 'guard_panel_clear_player_warnings', 'blocked', 'no_permission')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Sin permisos')
    end
    if _IsRateLimited(src, 'clearPlayerWarnings', 5000) then
        _AuditGuardAction(src, 'guard_panel_clear_player_warnings', 'blocked', 'rate_limited')
        return
    end

    if not identifier or identifier == '' then
        _AuditGuardAction(src, 'guard_panel_clear_player_warnings', 'blocked', 'missing_identifier')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Identifier invalido')
    end

    identifier = tostring(identifier or ''):gsub('%s+', '')
    if not _IsValidIdentifier(identifier) then
        _AuditGuardAction(src, 'guard_panel_clear_player_warnings', 'blocked', 'invalid_identifier')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Identifier invalido')
    end

    MySQL.query('DELETE FROM lyxguard_warnings WHERE identifier = ?', { identifier }, function()
        local adminName = GetPlayerName(src) or 'Unknown'
        print(string.format('^3[LyxGuard]^7 %s limpi warnings de: %s', adminName, identifier))

        _InvalidatePanelQueryCache({ identifier = identifier })
        TriggerClientEvent('lyxguard:notify', src, 'success', 'Advertencias del jugador limpiadas')
        BroadcastStatsRefresh()
        _AuditGuardAction(src, 'guard_panel_clear_player_warnings', 'allowed', nil, identifier, nil)
    end)
end)

-- Limpiar detecciones antiguas (mas de X dias)
RegisterNetEvent('lyxguard:panel:clearOldLogs', function(days)
    local src = source
    if not HasPanelAccess(src) then
        _AuditGuardAction(src, 'guard_panel_clear_old_logs', 'blocked', 'no_panel_access')
        return
    end
    if not CanManageBans(src) then
        _AuditGuardAction(src, 'guard_panel_clear_old_logs', 'blocked', 'no_permission')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Sin permisos')
    end
    if _IsRateLimited(src, 'clearOldLogs', 10000) then
        _AuditGuardAction(src, 'guard_panel_clear_old_logs', 'blocked', 'rate_limited')
        return
    end

    days = tonumber(days) or 30
    if days < 1 then days = 1 end
    if days > 365 then days = 365 end

    MySQL.query('DELETE FROM lyxguard_detections WHERE detection_date < DATE_SUB(NOW(), INTERVAL ? DAY)', { days }, function()
        MySQL.query('DELETE FROM lyxguard_warnings WHERE warn_date < DATE_SUB(NOW(), INTERVAL ? DAY)', { days }, function()
            local adminName = GetPlayerName(src) or 'Unknown'
            print(string.format('^3[LyxGuard]^7 %s limpi logs de mas de %d dias', adminName, days))

            _InvalidatePanelQueryCache()
            TriggerClientEvent('lyxguard:notify', src, 'success', string.format('Logs de mas de %d dias limpiados', days))
            BroadcastStatsRefresh()
            _AuditGuardAction(src, 'guard_panel_clear_old_logs', 'allowed', nil, nil, nil, { days = days })
        end)
    end)
end)

-- Borrar una deteccion especifica por ID
RegisterNetEvent('lyxguard:panel:clearDetection', function(detectionId)
    local src = source
    if not HasPanelAccess(src) then
        _AuditGuardAction(src, 'guard_panel_clear_detection', 'blocked', 'no_panel_access')
        return
    end
    if not CanManageBans(src) then
        _AuditGuardAction(src, 'guard_panel_clear_detection', 'blocked', 'no_permission')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'Sin permisos')
    end
    if _IsRateLimited(src, 'clearDetection', 2000) then
        _AuditGuardAction(src, 'guard_panel_clear_detection', 'blocked', 'rate_limited')
        return
    end

    if not detectionId then
        _AuditGuardAction(src, 'guard_panel_clear_detection', 'blocked', 'missing_detection_id')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'ID de deteccion invalido')
    end

    detectionId = tonumber(detectionId)
    if not detectionId or detectionId <= 0 then
        _AuditGuardAction(src, 'guard_panel_clear_detection', 'blocked', 'invalid_detection_id')
        return TriggerClientEvent('lyxguard:notify', src, 'error', 'ID de deteccion invalido')
    end

    MySQL.query('DELETE FROM lyxguard_detections WHERE id = ?', { detectionId }, function(result)
        if result and result.affectedRows and result.affectedRows > 0 then
            _InvalidatePanelQueryCache()
            TriggerClientEvent('lyxguard:notify', src, 'success', 'Deteccion #' .. detectionId .. ' eliminada')
            BroadcastStatsRefresh()
            _AuditGuardAction(src, 'guard_panel_clear_detection', 'allowed', nil, tostring(detectionId),
                'DetectionID:' .. tostring(detectionId))
        else
            TriggerClientEvent('lyxguard:notify', src, 'error', 'No se pudo eliminar la deteccion')
            _AuditGuardAction(src, 'guard_panel_clear_detection', 'blocked', 'delete_failed', tostring(detectionId),
                'DetectionID:' .. tostring(detectionId))
        end
    end)

    local adminName = GetPlayerName(src) or 'Unknown'
    print(string.format('^3[LyxGuard]^7 %s elimino deteccion ID: %s', adminName, tostring(detectionId)))
end)

-- Comandos de consola para admins
RegisterCommand('lyxguard_clearlogs', function(source, args)
    if source ~= 0 then
        return print('[LyxGuard] Este comando es solo para consola')
    end

    local target = args[1]

    if not target or target == 'all' then
        MySQL.query('DELETE FROM lyxguard_detections')
        MySQL.query('DELETE FROM lyxguard_warnings')
        print('^2[LyxGuard]^7 Todos los logs han sido limpiados')
    else
        MySQL.query('DELETE FROM lyxguard_detections WHERE identifier LIKE ?', { '%' .. target .. '%' })
        MySQL.query('DELETE FROM lyxguard_warnings WHERE identifier LIKE ?', { '%' .. target .. '%' })
        print('^2[LyxGuard]^7 Logs limpiados para: ' .. target)
    end
end, true) -- Solo para consola/RCON

exports('HasPanelAccess', HasPanelAccess)
exports('CanManageBans', CanManageBans)
exports('ValidateGuardPanelActionEnvelope', ValidateGuardPanelActionEnvelope)
exports('GetGuardPanelActionSecurityForClient', GetGuardPanelActionSecurityForClient)

print('^2[LyxGuard]^7 Panel module loaded')


