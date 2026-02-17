--[[
    LyxGuard - Exhaustive File Logging

    Goals:
    - Centralized JSONL + text logs in lyx-guard/logs/
    - Track player/admin/system actions with correlation_id
    - Keep per-player timeline buffer for pre-ban context
]]

LyxGuard = LyxGuard or {}
LyxGuard.ExhaustiveLogs = LyxGuard.ExhaustiveLogs or {}

local ExhaustiveLogs = LyxGuard.ExhaustiveLogs
local RESOURCE_NAME = GetCurrentResourceName()

local DEFAULT_CFG = {
    enabled = true,
    directory = 'logs',
    flushIntervalMs = 2000,
    flushBatchSize = 30,
    maxFileBytes = 2 * 1024 * 1024,
    writeJsonl = true,
    writeText = true,
    timelineSeconds = 60,
    timelineRetentionSeconds = 15 * 60,
    timelineMaxEntries = 1200,
    throttleDefaultMs = 1500,
    compressRotated = false,
    compressionDeleteOriginal = false,
    compressionMinBytes = 64 * 1024,
}

local State = {
    cfg = nil,
    queue = {},
    lastFlushMs = 0,
    currentDay = nil,
    currentIndex = 1,
    jsonPath = nil,
    txtPath = nil,
    jsonContent = '',
    txtContent = '',
    throttle = {},       -- [key] = lastMs
    timeline = {},       -- [identifier] = { { entry }, ... }
    sourceToIdentifier = {}, -- [source] = identifier
    seeded = false,
}

local function _NowMs()
    return GetGameTimer()
end

local function _UtcIso()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local function _SafeJsonEncode(value)
    local ok, encoded = pcall(json.encode, value)
    if ok then
        return encoded
    end
    return '{}'
end

local function _NormalizeString(value, maxLen)
    if value == nil then return nil end
    local s = tostring(value)
    s = s:gsub('[\r\n\t]', ' ')
    if maxLen and #s > maxLen then
        s = s:sub(1, maxLen)
    end
    return s
end

local function _EnsureRandomSeed()
    if State.seeded then return end
    math.randomseed((os.time() or 0) + (_NowMs() or 0))
    for _ = 1, 10 do
        math.random()
    end
    State.seeded = true
end

local function _BuildCorrelationId()
    _EnsureRandomSeed()
    local ms = _NowMs()
    return ('lgx-%d-%06d'):format(ms, math.random(100000, 999999))
end

local function _NormalizeLevel(level)
    local l = tostring(level or 'info'):lower()
    if l == 'debug' or l == 'info' or l == 'warn' or l == 'high' or l == 'critical' then
        return l
    end
    if l == 'warning' then return 'warn' end
    if l == 'error' then return 'high' end
    return 'info'
end

local function _ResolveIdentifierFromSource(source)
    source = tonumber(source)
    if not source or source <= 0 then
        return nil
    end

    if State.sourceToIdentifier[source] then
        return State.sourceToIdentifier[source]
    end

    local identifier = nil
    if type(GetIdentifier) == 'function' then
        identifier = GetIdentifier(source, 'license') or GetIdentifier(source, 'steam') or GetIdentifier(source, 'discord')
    end

    if not identifier or identifier == '' then
        identifier = ('src:%d'):format(source)
    end

    State.sourceToIdentifier[source] = identifier
    return identifier
end

local function _GetCfg()
    local cfg = {}
    for k, v in pairs(DEFAULT_CFG) do
        cfg[k] = v
    end

    local userCfg = Config and Config.ExhaustiveLogs or nil
    if type(userCfg) == 'table' then
        for k, v in pairs(userCfg) do
            cfg[k] = v
        end
    end

    cfg.flushIntervalMs = math.max(tonumber(cfg.flushIntervalMs) or 2000, 500)
    cfg.flushBatchSize = math.max(tonumber(cfg.flushBatchSize) or 30, 5)
    cfg.maxFileBytes = math.max(tonumber(cfg.maxFileBytes) or (2 * 1024 * 1024), 200 * 1024)
    cfg.timelineSeconds = math.max(tonumber(cfg.timelineSeconds) or 60, 10)
    cfg.timelineRetentionSeconds = math.max(tonumber(cfg.timelineRetentionSeconds) or 900, cfg.timelineSeconds)
    cfg.timelineMaxEntries = math.max(tonumber(cfg.timelineMaxEntries) or 1200, 100)
    cfg.throttleDefaultMs = math.max(tonumber(cfg.throttleDefaultMs) or 1500, 0)
    cfg.compressionMinBytes = math.max(tonumber(cfg.compressionMinBytes) or (64 * 1024), 1024)

    return cfg
end

local function _BuildFilePath(ext, day, index)
    local dir = tostring((State.cfg and State.cfg.directory) or 'logs')
    local file = ('lyxguard_%s_%02d.%s'):format(day, index, ext)
    return dir .. '/' .. file
end

local function _LoadResourceText(path)
    local raw = LoadResourceFile(RESOURCE_NAME, path)
    if type(raw) ~= 'string' then
        return ''
    end
    return raw
end

local function _WriteResourceText(path, content)
    return SaveResourceFile(RESOURCE_NAME, path, content, -1) == true
end

local function _GetResourceRoot()
    local ok, root = pcall(GetResourcePath, RESOURCE_NAME)
    if not ok or type(root) ~= 'string' or root == '' then
        return nil
    end
    return root
end

local function _JoinPath(left, right)
    left = tostring(left or ''):gsub('\\', '/')
    right = tostring(right or ''):gsub('\\', '/')
    if left:sub(-1) == '/' then
        return left .. right
    end
    return left .. '/' .. right
end

local function _QuotePsSingle(value)
    return tostring(value or ''):gsub("'", "''")
end

local function _CompressFileIfNeeded(relPath, currentBytes)
    if State.cfg.compressRotated ~= true then return end
    if type(relPath) ~= 'string' or relPath == '' then return end

    local bytes = tonumber(currentBytes) or 0
    if bytes < (State.cfg.compressionMinBytes or 0) then
        return
    end

    local root = _GetResourceRoot()
    if not root then return end

    local abs = _JoinPath(root, relPath)
    local zipAbs = abs .. '.zip'
    local safeAbs = _QuotePsSingle(abs)
    local safeZip = _QuotePsSingle(zipAbs)

    local cmd = ("powershell -NoProfile -ExecutionPolicy Bypass -Command \"Compress-Archive -Path '%s' -DestinationPath '%s' -Force\""):format(
        safeAbs,
        safeZip
    )
    local ok = os.execute(cmd)
    if ok == true or ok == 0 then
        if State.cfg.compressionDeleteOriginal == true then
            pcall(os.remove, abs)
        end
    else
        print(('[LyxGuard][ExLogs] Failed to compress rotated log: %s'):format(relPath))
    end
end

local function _EnsureActiveFiles()
    local day = os.date('!%Y%m%d')
    if State.currentDay == day and State.jsonPath and State.txtPath then
        return
    end

    State.currentDay = day
    State.currentIndex = 1
    State.jsonPath = _BuildFilePath('jsonl', day, State.currentIndex)
    State.txtPath = _BuildFilePath('log', day, State.currentIndex)
    State.jsonContent = _LoadResourceText(State.jsonPath)
    State.txtContent = _LoadResourceText(State.txtPath)
end

local function _RotateFilesIfNeeded(nextJsonBytes, nextTextBytes)
    _EnsureActiveFiles()

    local maxBytes = State.cfg.maxFileBytes
    local jsonSize = #State.jsonContent
    local txtSize = #State.txtContent

    local needRotateJson = State.cfg.writeJsonl == true and (jsonSize + (nextJsonBytes or 0) > maxBytes)
    local needRotateTxt = State.cfg.writeText == true and (txtSize + (nextTextBytes or 0) > maxBytes)

    if not needRotateJson and not needRotateTxt then
        return
    end

    local oldJsonPath = State.jsonPath
    local oldTxtPath = State.txtPath
    local oldJsonSize = jsonSize
    local oldTxtSize = txtSize

    State.currentIndex = State.currentIndex + 1
    State.jsonPath = _BuildFilePath('jsonl', State.currentDay, State.currentIndex)
    State.txtPath = _BuildFilePath('log', State.currentDay, State.currentIndex)
    State.jsonContent = _LoadResourceText(State.jsonPath)
    State.txtContent = _LoadResourceText(State.txtPath)

    if needRotateJson then
        _CompressFileIfNeeded(oldJsonPath, oldJsonSize)
    end
    if needRotateTxt then
        _CompressFileIfNeeded(oldTxtPath, oldTxtSize)
    end
end

local function _BuildTextLine(entry)
    local actor = _NormalizeString(entry.actor_name or entry.actor_id or 'unknown', 120)
    local target = _NormalizeString(entry.target_name or entry.target_id or '-', 120)
    local action = _NormalizeString(entry.action or entry.event or 'unknown', 140)
    local reason = _NormalizeString(entry.reason or '-', 220)
    local cid = _NormalizeString(entry.correlation_id or '-', 80)
    return ('[%s] [%s] [%s] actor=%s target=%s action=%s result=%s reason=%s cid=%s'):format(
        tostring(entry.timestamp or _UtcIso()),
        tostring(entry.level or 'info'),
        tostring(entry.resource or 'lyx-guard'),
        actor,
        target,
        action,
        tostring(entry.result or 'allowed'),
        reason,
        cid
    )
end

local function _TrimTimeline(identifier)
    local bucket = State.timeline[identifier]
    if type(bucket) ~= 'table' then
        return
    end

    local nowSec = os.time()
    local retention = State.cfg.timelineRetentionSeconds
    local maxEntries = State.cfg.timelineMaxEntries

    local out = {}
    for i = 1, #bucket do
        local e = bucket[i]
        local ts = tonumber(e and e._ts) or nowSec
        if (nowSec - ts) <= retention then
            out[#out + 1] = e
        end
    end

    if #out > maxEntries then
        local startAt = #out - maxEntries + 1
        local sliced = {}
        for i = startAt, #out do
            sliced[#sliced + 1] = out[i]
        end
        out = sliced
    end

    State.timeline[identifier] = out
end

local function _TrackTimeline(entry)
    local actorType = tostring(entry.actor_type or '')
    local identifier = nil

    if actorType == 'player' or actorType == 'admin' then
        identifier = _NormalizeString(entry.actor_id, 128)
    end

    if not identifier or identifier == '' then
        return
    end

    if not State.timeline[identifier] then
        State.timeline[identifier] = {}
    end

    local safeEntry = {
        timestamp = entry.timestamp,
        _ts = entry._ts,
        level = entry.level,
        actor_type = entry.actor_type,
        actor_id = entry.actor_id,
        actor_name = entry.actor_name,
        target_id = entry.target_id,
        target_name = entry.target_name,
        resource = entry.resource,
        action = entry.action,
        event = entry.event,
        result = entry.result,
        reason = entry.reason,
        correlation_id = entry.correlation_id,
        metadata = entry.metadata,
    }

    local bucket = State.timeline[identifier]
    bucket[#bucket + 1] = safeEntry
    _TrimTimeline(identifier)
end

local function _NormalizeEntry(entry)
    if type(entry) ~= 'table' then
        return nil
    end

    local out = {
        timestamp = _NormalizeString(entry.timestamp, 40) or _UtcIso(),
        _ts = tonumber(entry._ts) or os.time(),
        level = _NormalizeLevel(entry.level),
        correlation_id = _NormalizeString(entry.correlation_id, 128) or _BuildCorrelationId(),
        actor_type = _NormalizeString(entry.actor_type, 24) or 'system',
        actor_id = _NormalizeString(entry.actor_id, 128),
        actor_name = _NormalizeString(entry.actor_name, 128),
        target_id = _NormalizeString(entry.target_id, 128),
        target_name = _NormalizeString(entry.target_name, 128),
        resource = _NormalizeString(entry.resource, 64) or 'lyx-guard',
        event = _NormalizeString(entry.event, 160),
        action = _NormalizeString(entry.action, 160),
        result = _NormalizeString(entry.result, 40) or 'allowed',
        reason = _NormalizeString(entry.reason, 280),
        metadata = type(entry.metadata) == 'table' and entry.metadata or {},
    }

    if out.actor_id and out.actor_id:sub(1, 4) == 'src:' then
        local src = tonumber(out.actor_id:sub(5))
        if src and src > 0 then
            local resolved = _ResolveIdentifierFromSource(src)
            if resolved then
                out.actor_id = resolved
            end
        end
    end

    return out
end

local function _FlushQueue()
    if State.cfg.enabled ~= true then
        State.queue = {}
        return
    end

    if #State.queue == 0 then
        return
    end

    _EnsureActiveFiles()

    local batch = State.queue
    State.queue = {}

    local jsonLines = {}
    local txtLines = {}
    for i = 1, #batch do
        local entry = batch[i]
        jsonLines[#jsonLines + 1] = _SafeJsonEncode(entry)
        txtLines[#txtLines + 1] = _BuildTextLine(entry)
    end

    local jsonChunk = table.concat(jsonLines, '\n')
    if #jsonChunk > 0 then
        jsonChunk = jsonChunk .. '\n'
    end
    local txtChunk = table.concat(txtLines, '\n')
    if #txtChunk > 0 then
        txtChunk = txtChunk .. '\n'
    end

    _RotateFilesIfNeeded(#jsonChunk, #txtChunk)

    if State.cfg.writeJsonl == true and #jsonChunk > 0 then
        State.jsonContent = State.jsonContent .. jsonChunk
        if not _WriteResourceText(State.jsonPath, State.jsonContent) then
            print(('[LyxGuard][ExLogs] Failed to write JSONL log file: %s'):format(State.jsonPath))
        end
    end

    if State.cfg.writeText == true and #txtChunk > 0 then
        State.txtContent = State.txtContent .. txtChunk
        if not _WriteResourceText(State.txtPath, State.txtContent) then
            print(('[LyxGuard][ExLogs] Failed to write text log file: %s'):format(State.txtPath))
        end
    end

    State.lastFlushMs = _NowMs()
end

function ExhaustiveLogs.Push(entry)
    if State.cfg.enabled ~= true then
        return false
    end

    local normalized = _NormalizeEntry(entry)
    if not normalized then
        return false
    end

    State.queue[#State.queue + 1] = normalized
    _TrackTimeline(normalized)

    if #State.queue >= State.cfg.flushBatchSize then
        _FlushQueue()
    end

    return true
end

function ExhaustiveLogs.TrackPlayerAction(source, action, metadata, level, opts)
    source = tonumber(source)
    if not source or source <= 0 then
        return false
    end

    local identifier = _ResolveIdentifierFromSource(source)
    local playerName = GetPlayerName(source) or ('Player %d'):format(source)
    local now = _NowMs()
    opts = type(opts) == 'table' and opts or {}

    local throttleKey = tostring(opts.throttleKey or (identifier .. '|' .. tostring(action or 'action')))
    local minInterval = tonumber(opts.minIntervalMs)
    if minInterval == nil then
        minInterval = State.cfg.throttleDefaultMs
    end
    if minInterval < 0 then
        minInterval = 0
    end

    local last = tonumber(State.throttle[throttleKey]) or 0
    if minInterval > 0 and (now - last) < minInterval then
        return false
    end
    State.throttle[throttleKey] = now

    return ExhaustiveLogs.Push({
        level = level or 'debug',
        actor_type = 'player',
        actor_id = identifier,
        actor_name = playerName,
        resource = opts.resource or 'lyx-guard',
        action = action or 'player_action',
        event = opts.event,
        result = opts.result or 'observed',
        reason = opts.reason,
        correlation_id = opts.correlation_id,
        metadata = metadata or {},
    })
end

function ExhaustiveLogs.GetTimeline(sourceOrIdentifier, seconds)
    local identifier = nil
    if type(sourceOrIdentifier) == 'number' then
        identifier = _ResolveIdentifierFromSource(sourceOrIdentifier)
    elseif type(sourceOrIdentifier) == 'string' then
        identifier = sourceOrIdentifier
    end

    if not identifier or identifier == '' then
        return {}
    end

    _TrimTimeline(identifier)

    local bucket = State.timeline[identifier]
    if type(bucket) ~= 'table' or #bucket == 0 then
        return {}
    end

    local windowSec = tonumber(seconds) or State.cfg.timelineSeconds
    if windowSec < 1 then windowSec = 1 end
    local cutoff = os.time() - windowSec

    local out = {}
    for i = 1, #bucket do
        local e = bucket[i]
        if (tonumber(e._ts) or 0) >= cutoff then
            out[#out + 1] = e
        end
    end
    return out
end

function ExhaustiveLogs.GetCurrentFiles()
    _EnsureActiveFiles()
    return {
        jsonl = State.jsonPath,
        text = State.txtPath,
    }
end

function ExhaustiveLogs.FlushNow()
    _FlushQueue()
    return true
end

local function _Init()
    State.cfg = _GetCfg()
    _EnsureActiveFiles()

    CreateThread(function()
        while true do
            Wait(500)
            if State.cfg.enabled == true then
                local now = _NowMs()
                if #State.queue >= State.cfg.flushBatchSize or (now - State.lastFlushMs) >= State.cfg.flushIntervalMs then
                    _FlushQueue()
                end
            end
        end
    end)

    AddEventHandler('playerDropped', function()
        local src = source
        State.sourceToIdentifier[src] = nil
    end)

    AddEventHandler('onResourceStop', function(resourceName)
        if resourceName ~= RESOURCE_NAME then return end
        _FlushQueue()
    end)

    print('[LyxGuard] Exhaustive logs loaded.')
end

exports('PushExhaustiveLog', function(entry)
    return ExhaustiveLogs.Push(entry)
end)

exports('TrackExhaustivePlayerAction', function(source, action, metadata, level, opts)
    return ExhaustiveLogs.TrackPlayerAction(source, action, metadata, level, opts)
end)

exports('GetExhaustiveTimeline', function(sourceOrIdentifier, seconds)
    return ExhaustiveLogs.GetTimeline(sourceOrIdentifier, seconds)
end)

exports('FlushExhaustiveLogs', function()
    return ExhaustiveLogs.FlushNow()
end)

_G.LyxGuardPushExhaustiveLog = function(entry)
    return ExhaustiveLogs.Push(entry)
end

_G.LyxGuardTrackPlayerAction = function(source, action, metadata, level, opts)
    return ExhaustiveLogs.TrackPlayerAction(source, action, metadata, level, opts)
end

_G.LyxGuardGetPlayerTimeline = function(sourceOrIdentifier, seconds)
    return ExhaustiveLogs.GetTimeline(sourceOrIdentifier, seconds)
end

_Init()
