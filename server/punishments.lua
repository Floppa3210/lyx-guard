--[[
    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║                           LYXGUARD v4.0 PROFESSIONAL                         ║
    ║                            Punishment System                                  ║
    ╠═══════════════════════════════════════════════════════════════════════════════╣
    ║  Author: LyxDev                                                               ║
    ║  License: Commercial                                                          ║
    ║  Purpose: Modular punishment handler with rate limiting and logging          ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- MODULE INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════════

---@class PunishmentModule
local PunishmentModule = {}

-- Private state
local State = {
    handlers = {},      -- Registered punishment handlers
    rateLimits = {},    -- Rate limit tracking [source_detection] = timestamp
    lastPunishment = {} -- Last punishment per player [source] = {type, time}
}

-- Configuration
local RATE_LIMIT_MS = 5000 -- Minimum time between same punishment type
local MAX_HANDLERS = 50    -- Maximum registered handlers (safety)
local _FNV32_PRIME = 16777619
local _FNV32_OFFSET = 2166136261
local _U32_MOD = 4294967296

-- Legacy compatibility - reference global tables
PlayerData = PlayerData or {}
BannedPlayers = BannedPlayers or {}
Warnings = Warnings or {}

local function _GetTimelineForSource(source, seconds)
    if type(LyxGuardGetPlayerTimeline) == 'function' then
        local ok, data = pcall(LyxGuardGetPlayerTimeline, source, seconds)
        if ok and type(data) == 'table' then
            return data
        end
    end
    return {}
end

local function _PushExLog(entry)
    if type(LyxGuardPushExhaustiveLog) == 'function' then
        pcall(LyxGuardPushExhaustiveLog, entry)
    end
end

local function _HashFNV1a(value)
    value = tostring(value or '')
    local hash = _FNV32_OFFSET
    for i = 1, #value do
        hash = (hash ~ value:byte(i))
        hash = (hash * _FNV32_PRIME) % _U32_MOD
    end
    return string.format('%08x', hash)
end

local function _NormalizeValue(value)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    if value == '' then return nil end
    return value:lower()
end

local function _BuildTokenHashes(tokens)
    if type(tokens) ~= 'table' then return {} end
    local out, seen = {}, {}
    for _, token in ipairs(tokens) do
        if type(token) == 'string' and token ~= '' then
            local h = _HashFNV1a(token)
            if not seen[h] then
                seen[h] = true
                out[#out + 1] = h
            end
        end
    end
    table.sort(out)
    return out
end

local function _BuildIdentifierFingerprint(pd, tokenHashes)
    if type(pd) ~= 'table' then return nil end

    local fields = {
        _NormalizeValue(pd.license),
        _NormalizeValue(pd.steam),
        _NormalizeValue(pd.discord),
        _NormalizeValue(pd.fivem),
        _NormalizeValue(pd.identifier)
    }

    local parts = {}
    for _, field in ipairs(fields) do
        if field then
            parts[#parts + 1] = field
        end
    end

    if type(tokenHashes) == 'table' then
        local limit = math.min(#tokenHashes, 6)
        for i = 1, limit do
            parts[#parts + 1] = tostring(tokenHashes[i])
        end
    end

    if #parts == 0 then
        return nil
    end

    local seed = table.concat(parts, '|')
    return _HashFNV1a(seed .. '|lyxguard_fp_v2_a') .. _HashFNV1a(seed .. '|lyxguard_fp_v2_b')
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- RATE LIMITING
-- ═══════════════════════════════════════════════════════════════════════════════

---Check if action is rate limited
---@param source number
---@param detectionType string
---@return boolean isLimited
local function IsRateLimited(source, detectionType)
    local key = tostring(source) .. '_' .. detectionType
    local now = GetGameTimer()
    local lastTime = State.rateLimits[key]

    if lastTime and (now - lastTime) < RATE_LIMIT_MS then
        return true
    end

    State.rateLimits[key] = now
    return false
end

---Clean up old rate limit entries (called periodically)
---@private
local function CleanupRateLimits()
    local now = GetGameTimer()
    local expired = {}

    for key, timestamp in pairs(State.rateLimits) do
        if (now - timestamp) > RATE_LIMIT_MS * 3 then
            table.insert(expired, key)
        end
    end

    for _, key in ipairs(expired) do
        State.rateLimits[key] = nil
    end
end

-- Periodic cleanup
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        CleanupRateLimits()
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- PUNISHMENT HANDLER REGISTRY
-- ═══════════════════════════════════════════════════════════════════════════════

---Register a punishment handler
---@param punishmentType string Type identifier
---@param handler function Handler function(source, reason, config)
---@return boolean success
function PunishmentModule.RegisterHandler(punishmentType, handler)
    -- Validation
    if not punishmentType or type(punishmentType) ~= 'string' then
        LyxGuardLib.Error('RegisterHandler: Invalid punishment type')
        return false
    end

    if type(handler) ~= 'function' then
        LyxGuardLib.Error('RegisterHandler: Handler must be a function')
        return false
    end

    -- Safety limit
    local count = 0
    for _ in pairs(State.handlers) do count = count + 1 end
    if count >= MAX_HANDLERS then
        LyxGuardLib.Error('RegisterHandler: Maximum handlers reached')
        return false
    end

    State.handlers[punishmentType] = handler
    LyxGuardLib.Debug('Punishment handler registered: %s', punishmentType)
    return true
end

-- Global compatibility
RegisterPunishment = PunishmentModule.RegisterHandler

-- ═══════════════════════════════════════════════════════════════════════════════
-- LOGGING
-- ═══════════════════════════════════════════════════════════════════════════════

---Log detection to database
---@param source number
---@param detectionType string
---@param details table|nil
---@param coords vector3|nil
---@param punishment string
function PunishmentModule.LogDetection(source, detectionType, details, coords, punishment)
    local pd = PlayerData[source]
    if not pd then
        LyxGuardLib.Warn('LogDetection: No player data for source %d', source)
        return
    end

    -- Sanitize inputs
    local playerName = LyxGuardLib.Sanitize(pd.name or 'Unknown', 100)
    local identifier = pd.identifier or 'unknown'
    local steam = pd.steam or nil
    local discord = pd.discord or nil

    -- Format coords
    local coordsStr = nil
    if coords then
        coordsStr = string.format('%.2f,%.2f,%.2f', coords.x or 0, coords.y or 0, coords.z or 0)
    end

    -- Format details as JSON
    local detailsJson = nil
    if details then
        local success, json = pcall(json.encode, details)
        detailsJson = success and json or nil
    end

    -- Insert to database
    local query = [[
        INSERT INTO lyxguard_detections
        (player_name, identifier, steam, discord, detection_type, details, coords, punishment)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]]

    MySQL.Async.execute(query, {
        playerName,
        identifier,
        steam,
        discord,
        detectionType,
        detailsJson,
        coordsStr,
        punishment
    })

    LyxGuardLib.Debug('Detection logged: %s - %s - %s', playerName, detectionType, punishment)

    _PushExLog({
        level = 'warn',
        actor_type = 'player',
        actor_id = identifier,
        actor_name = playerName,
        resource = 'lyx-guard',
        action = 'detection_logged',
        event = detectionType,
        result = 'flagged',
        reason = tostring(punishment or 'none'),
        metadata = {
            punishment = punishment,
            coords = coordsStr,
            details = details,
            source = source
        }
    })
end

-- Global compatibility
LogDetection = PunishmentModule.LogDetection

-- ═══════════════════════════════════════════════════════════════════════════════
-- CORE PUNISHMENT LOGIC
-- ═══════════════════════════════════════════════════════════════════════════════

---Apply punishment to player
---@param source number Player source
---@param detectionType string Type of detection
---@param config table Detection configuration
---@param details table|nil Additional details
---@param coords vector3|nil Player coordinates
function PunishmentModule.Apply(source, detectionType, config, details, coords)
    -- Validate source
    if not source or source <= 0 then
        LyxGuardLib.Debug('ApplyPunishment: Invalid source')
        return
    end

    -- Get player data
    local pd = PlayerData[source]
    if not pd then
        -- Try to initialize if not exists
        if InitPlayerData then
            InitPlayerData(source)
            pd = PlayerData[source]
        end

        if not pd then
            LyxGuardLib.Warn('ApplyPunishment: No player data for source %d', source)
            return
        end
    end

    -- Check immunity
    if pd.immune then
        LyxGuardLib.Debug('Detection ignored (immune): %s - %s', pd.name, detectionType)
        return
    end

    -- Check rate limit
    if IsRateLimited(source, detectionType) then
        LyxGuardLib.Debug('Detection rate limited: %s - %s', pd.name, detectionType)
        return
    end

    -- Determine punishment type
    local punishment = config.punishment or LyxGuardLib.PUNISHMENTS.NOTIFY
    if punishment == 'ban' then
        punishment = LyxGuardLib.PUNISHMENTS.BAN_TEMP
    end

    -- Log detection
    local success, err = pcall(PunishmentModule.LogDetection, source, detectionType, details, coords, punishment)
    if not success then
        LyxGuardLib.Error('Failed to log detection: %s', tostring(err))
    end

    -- Get and execute handler
    local handler = State.handlers[punishment]
    if handler then
        local handlerReason = detectionType
        if type(details) == 'table' and type(details.reason) == 'string' and details.reason ~= '' then
            handlerReason = details.reason
        end

        local handlerSuccess, handlerErr = pcall(handler, source, handlerReason, config)
        if not handlerSuccess then
            LyxGuardLib.Error('Punishment handler error (%s): %s', punishment, tostring(handlerErr))
        end
    else
        LyxGuardLib.Warn('No handler for punishment type: %s', punishment)
    end

    -- Send Discord webhook
    if SendDiscordDetection then
        pcall(SendDiscordDetection, source, detectionType, details, coords, punishment)
    end

    -- Track last punishment
    State.lastPunishment[source] = {
        type = punishment,
        detection = detectionType,
        time = os.time()
    }
end

-- Global compatibility
ApplyPunishment = PunishmentModule.Apply

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEFAULT PUNISHMENT HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════════

-- None: No action
PunishmentModule.RegisterHandler(LyxGuardLib.PUNISHMENTS.NONE, function(source, reason, config)
    LyxGuardLib.Debug('Punishment NONE for %s: %s', tostring(source), reason)
end)

-- Notify: Alert admins
PunishmentModule.RegisterHandler(LyxGuardLib.PUNISHMENTS.NOTIFY, function(source, reason, config)
    local pd = PlayerData[source]
    if not pd then return end

    -- Notify online admins (only if ESX is available)
    if ESX and ESX.GetExtendedPlayers then
        for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
            local group = xPlayer.getGroup()
            if Config.Permissions and LyxGuardLib.Contains(Config.Permissions.immuneGroups or {}, group) then
                TriggerClientEvent('lyxguard:adminNotify', xPlayer.source, {
                    type = 'detection',
                    playerName = pd.name,
                    playerId = source,
                    detection = reason
                })
            end
        end
    end
end)

-- Screenshot: Take player screenshot
PunishmentModule.RegisterHandler(LyxGuardLib.PUNISHMENTS.SCREENSHOT, function(source, reason, config)
    if GetResourceState('screenshot-basic') ~= 'started' or not exports['screenshot-basic'] then
        LyxGuardLib.Warn('Screenshot punishment requested but screenshot-basic is not installed/running')
        local notifyHandler = State.handlers[LyxGuardLib.PUNISHMENTS.NOTIFY]
        if notifyHandler then
            notifyHandler(source, reason, config)
        end
        return
    end

    exports['screenshot-basic']:requestClientScreenshot(source, {
        encoding = 'png',
        quality = 0.8
    }, function(err, data)
        if not err then
            if SendScreenshotWebhook then
                SendScreenshotWebhook(source, reason, data)
            end
            LyxGuardLib.Debug('Screenshot taken for %d: %s', source, reason)
        else
            LyxGuardLib.Error('Screenshot failed: %s', tostring(err))
        end
    end)
end)

-- Warn: Add warning to player
PunishmentModule.RegisterHandler(LyxGuardLib.PUNISHMENTS.WARN, function(source, reason, config)
    local pd = PlayerData[source]
    if not pd then return end

    local wCfg = Config and Config.Punishments and Config.Punishments.warnings or nil
    local warningsEnabled = wCfg and wCfg.enabled == true

    local maxWarnings = tonumber(wCfg and wCfg.maxWarnings) or 3
    if maxWarnings < 1 then maxWarnings = 1 end

    reason = LyxGuardLib.Sanitize(reason or 'Unknown', 250)

    local function _Notify(count)
        TriggerClientEvent('lyxguard:notify', source, {
            type = 'warning',
            message = string.format(
                LyxGuardLib.L('warning_received') or 'Advertencia %d/%d: %s',
                tonumber(count) or 1,
                maxWarnings,
                reason
            )
        })
    end

    -- Respect config: when warnings are disabled, do NOT write to DB and do NOT auto-ban.
    if not warningsEnabled then
        _Notify(1)
        TriggerEvent('lyxguard:onWarning', source, reason, 'LyxGuard')
        if SendDiscordWarning then
            pcall(SendDiscordWarning, source, reason, 1, maxWarnings)
        end
        _PushExLog({
            level = 'warn',
            actor_type = 'player',
            actor_id = pd.identifier,
            actor_name = pd.name,
            resource = 'lyx-guard',
            action = 'warning_issued',
            result = 'warning',
            reason = reason,
            metadata = {
                warning_count = 1,
                warning_limit = maxWarnings,
                warnings_enabled = false,
                timeline_60s = _GetTimelineForSource(source, 60)
            }
        })
        return
    end

    local identifier = pd.identifier
    local playerName = pd.name
    local expiryHours = tonumber(wCfg and wCfg.expiryHours) or 0

    -- Insert warning
    if expiryHours > 0 then
        MySQL.Async.execute(
            'INSERT INTO lyxguard_warnings (identifier, player_name, reason, warned_by, expires_at) VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))',
            { identifier, playerName, reason, 'LyxGuard', expiryHours }
        )
    else
        MySQL.Async.execute(
            'INSERT INTO lyxguard_warnings (identifier, player_name, reason, warned_by) VALUES (?, ?, ?, ?)',
            { identifier, playerName, reason, 'LyxGuard' }
        )
    end

    -- Get warning count
    MySQL.Async.fetchScalar(
        expiryHours > 0 and
        'SELECT COUNT(*) FROM lyxguard_warnings WHERE identifier = ? AND active = 1 AND (expires_at IS NULL OR expires_at > NOW())' or
        'SELECT COUNT(*) FROM lyxguard_warnings WHERE identifier = ? AND active = 1',
        { identifier },
        function(count)
            -- Notify player
            count = tonumber(count) or 1
            _Notify(count)
            TriggerEvent('lyxguard:onWarning', source, reason, 'LyxGuard')

            -- Send webhook
            if SendDiscordWarning then
                pcall(SendDiscordWarning, source, reason, count, maxWarnings)
            end

            _PushExLog({
                level = 'warn',
                actor_type = 'player',
                actor_id = identifier,
                actor_name = playerName,
                resource = 'lyx-guard',
                action = 'warning_issued',
                result = 'warning',
                reason = reason,
                metadata = {
                    warning_count = count,
                    warning_limit = maxWarnings,
                    warnings_enabled = true,
                    timeline_60s = _GetTimelineForSource(source, 60)
                }
            })

            -- Check if max warnings reached
            if count >= maxWarnings then
                local actionOnMax = tostring(wCfg and wCfg.actionOnMax or 'ban_temp')
                local banDuration = tostring((wCfg and (wCfg.banDurationOnMax or wCfg.autoBanDuration)) or 'short')
                local maxReason = 'Maximo de advertencias alcanzado'

                if actionOnMax == 'ban_perm' then
                    if BanPlayer then
                        BanPlayer(source, maxReason, 0, 'LyxGuard')
                    end
                elseif actionOnMax == 'kick' then
                    DropPlayer(source, maxReason)
                elseif actionOnMax == 'none' then
                    -- no-op
                else
                    -- Default: temporary ban
                    if BanPlayer then
                        BanPlayer(source, maxReason, banDuration, 'LyxGuard')
                    end
                end
            end
        end
    )
end)

-- Kick: Remove player from server
PunishmentModule.RegisterHandler(LyxGuardLib.PUNISHMENTS.KICK, function(source, reason, config)
    local pd = PlayerData[source]
    local playerName = pd and pd.name or 'Unknown'

    -- Send webhook before kick
    if SendDiscordKick then
        pcall(SendDiscordKick, source, reason, playerName)
    end

    local kickMessage = string.format(
        Config.Punishments and Config.Punishments.messages and Config.Punishments.messages.kick or '🚫 Expulsado: %s',
        reason
    )

    _PushExLog({
        level = 'high',
        actor_type = 'player',
        actor_id = pd and pd.identifier or ('src:' .. tostring(source)),
        actor_name = playerName,
        resource = 'lyx-guard',
        action = 'player_kicked',
        result = 'sanctioned',
        reason = reason,
        metadata = {
            source = source,
            timeline_60s = _GetTimelineForSource(source, 60)
        }
    })

    DropPlayer(source, kickMessage)
    LyxGuardLib.Info('Player kicked: %s - %s', playerName, reason)
end)

-- Temporary Ban
PunishmentModule.RegisterHandler(LyxGuardLib.PUNISHMENTS.BAN_TEMP, function(source, reason, config)
    local duration = config.banDuration or 'short'
    if BanPlayer then
        BanPlayer(source, reason, duration, 'LyxGuard')
    end
end)

-- Permanent Ban
PunishmentModule.RegisterHandler(LyxGuardLib.PUNISHMENTS.BAN_PERM, function(source, reason, config)
    if BanPlayer then
        BanPlayer(source, reason, 0, 'LyxGuard') -- 0 = permanent
    end
end)

-- Teleport: Move player to spawn
PunishmentModule.RegisterHandler(LyxGuardLib.PUNISHMENTS.TELEPORT, function(source, reason, config)
    local spawnPoint = Config.Punishments and Config.Punishments.spawnPoint or { x = 0, y = 0, z = 0 }
    TriggerClientEvent('lyxguard:teleport', source, spawnPoint.x, spawnPoint.y, spawnPoint.z)
    TriggerClientEvent('lyxguard:notify', source, {
        type = 'warning',
        message = 'Has sido teleportado por actividad sospechosa'
    })
end)

-- Freeze: Lock player movement
PunishmentModule.RegisterHandler(LyxGuardLib.PUNISHMENTS.FREEZE, function(source, reason, config)
    local duration = Config.Punishments and Config.Punishments.freezeDuration or 30
    TriggerClientEvent('lyxguard:freeze', source, duration)
    TriggerClientEvent('lyxguard:notify', source, {
        type = 'warning',
        message = string.format('Has sido congelado por %d segundos', duration)
    })
end)

-- Kill: Set player health to 0
PunishmentModule.RegisterHandler(LyxGuardLib.PUNISHMENTS.KILL, function(source, reason, config)
    TriggerClientEvent('lyxguard:kill', source)
    TriggerClientEvent('lyxguard:notify', source, {
        type = 'error',
        message = 'Has sido eliminado por actividad sospechosa'
    })
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- BAN PLAYER FUNCTION
-- ═══════════════════════════════════════════════════════════════════════════════

---Ban a player
---@param source number Player source
---@param reason string Ban reason
---@param duration string|number Duration key or seconds (0 = permanent)
---@param bannedBy string Admin name
---@return boolean success
function BanPlayer(source, reason, duration, bannedBy)
    local pd = PlayerData[source]
    if not pd then
        LyxGuardLib.Error('BanPlayer: No player data for source %d', source)
        return false
    end

    -- Calculate unban time
    local unbanTime = nil
    local isPermanent = false

    if duration == 0 or duration == 'permanent' then
        isPermanent = true
    else
        unbanTime = LyxGuardLib.GetUnbanTime(duration)
    end

    -- Sanitize inputs
    reason = LyxGuardLib.Sanitize(reason or 'No reason provided', 500)
    bannedBy = LyxGuardLib.Sanitize(bannedBy or 'LyxGuard', 100)

    -- Capture player tokens (HWID-like) for stronger bans.
    local tokens = {}
    local tokensJson = nil
    if type(GetNumPlayerTokens) == 'function' and type(GetPlayerToken) == 'function' then
        local n = GetNumPlayerTokens(source)
        for i = 0, (n or 0) - 1 do
            local tok = GetPlayerToken(source, i)
            if tok and tok ~= '' then
                tokens[#tokens + 1] = tok
            end
        end
        if #tokens > 0 then
            tokensJson = json.encode(tokens)
        end
    end

    local tokenHashes = _BuildTokenHashes(tokens)
    local tokenHashesJson = (#tokenHashes > 0) and json.encode(tokenHashes) or nil
    local identifierFingerprint = _BuildIdentifierFingerprint(pd, tokenHashes)

    -- Insert ban record (hardened: token hashes + identifier fingerprint)
    local query = [[
        INSERT INTO lyxguard_bans
        (identifier, steam, discord, license, fivem, ip, tokens, token_hashes, identifier_fingerprint, player_name, reason, unban_date, permanent, banned_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]

    MySQL.Async.execute(query, {
        pd.identifier,
        pd.steam,
        pd.discord,
        pd.license,
        pd.fivem,
        pd.ip,
        tokensJson,
        tokenHashesJson,
        identifierFingerprint,
        pd.name,
        reason,
        unbanTime and os.date('%Y-%m-%d %H:%M:%S', unbanTime) or nil,
        isPermanent and 1 or 0,
        bannedBy
    }, function(insertId)
        if insertId and insertId > 0 then
            -- Add to cache
            local banData = {
                id = insertId,
                reason = reason,
                permanent = isPermanent,
                unbanTime = unbanTime,
                bannedBy = bannedBy
            }

            BannedPlayers[pd.identifier] = banData
            if pd.license then BannedPlayers[pd.license] = banData end
            if pd.steam then BannedPlayers[pd.steam] = banData end
            if pd.discord then BannedPlayers[pd.discord] = banData end
            if pd.fivem then BannedPlayers[pd.fivem] = banData end

            LyxGuardLib.Info('Player banned: %s - %s (by %s)', pd.name, reason, bannedBy)
        end
    end)

    -- Send webhook
    if SendDiscordBan then
        pcall(SendDiscordBan, source, reason, duration, pd.name, bannedBy)
    end

    TriggerEvent('lyxguard:onBan', source, reason, duration, bannedBy)

    _PushExLog({
        level = 'critical',
        actor_type = 'player',
        actor_id = pd.identifier,
        actor_name = pd.name,
        resource = 'lyx-guard',
        action = 'player_banned',
        result = 'sanctioned',
        reason = reason,
        metadata = {
            source = source,
            duration = duration,
            banned_by = bannedBy,
            permanent = isPermanent,
            unban_time = unbanTime,
            token_hash_count = #tokenHashes,
            timeline_60s = _GetTimelineForSource(source, 60)
        }
    })

    -- Kick player
    local banMessage = string.format(
        Config.Punishments and Config.Punishments.messages and Config.Punishments.messages.ban or
        'Baneado: %s\nDuracion: %s',
        reason,
        isPermanent and 'Permanente' or LyxGuardLib.FormatDuration(unbanTime and (unbanTime - os.time()) or 0)
    )

    DropPlayer(source, banMessage)

    return true
end

-- Export
exports('BanPlayer', BanPlayer)
exports('LogDetection', LogDetection)

-- ═══════════════════════════════════════════════════════════════════════════════
-- MODULE EXPORT
-- ═══════════════════════════════════════════════════════════════════════════════

return PunishmentModule
