--[[
    LyxGuard - Secure Event Bridge (SERVER)

    License: MIT

    Intercomunicador seguro cliente -> servidor con firma HMAC-SHA256 + nonce
    anti-replay por jugador. Inspirado en el enfoque anti-trigger de GoblinAC, pero
    endurecido: el secreto (playerKey) NUNCA viaja dentro de un evento; solo se emite
    una vez (servidor -> cliente) al validar la sesion. Un executor que intente
    re-triggerear un evento no puede forjar la firma sin la key, ni reusar un nonce.

    Como se usa (opt-in por evento):
        -- server:
        RegisterSecureEvent('mi_recurso:hazAlgo', function(source, a, b) ... end)
        -- client:
        exports['lyx-guard']:TriggerSecureServerEvent('mi_recurso:hazAlgo', a, b)

    Firma:  HMAC(playerKey, eventName .. '|' .. seq .. '|' .. nonce .. '|' .. ts .. '|' .. sha256(argsJson))
]]

local Bridge = {}

-- -----------------------------------------------------------------------------
-- CONFIG
-- -----------------------------------------------------------------------------

local function _GetCfg()
    local root = Config and Config.SecureBridge or {}
    return {
        enabled = root.enabled ~= false,
        keyTtlMs = tonumber(root.keyTtlMs) or (10 * 60 * 1000),
        nonceTtlMs = tonumber(root.nonceTtlMs) or (5 * 60 * 1000),
        maxUsedNonces = tonumber(root.maxUsedNonces) or 4096,
        maxClockSkewMs = tonumber(root.maxClockSkewMs) or (5 * 60 * 1000),
        punishOnInvalid = root.punishOnInvalid ~= false,
        punishment = tostring(root.punishment or 'kick'),
        tolerance = tonumber(root.tolerance) or 1,
    }
end

-- -----------------------------------------------------------------------------
-- SESSIONS (per player)
-- -----------------------------------------------------------------------------

local _Sessions = {}      -- [source] = { key, issuedAtMs, expiresAtMs, consumedNonces, nonceQueue, seq }
local _RandSeeded = false

local function _NowMs()
    return GetGameTimer()
end

local function _EpochMs()
    return (os.time() or 0) * 1000
end

local function _EnsureSeed()
    if _RandSeeded then return end
    local base = (os.time() or 0) + (_NowMs() or 0) + math.floor((os.clock() or 0) * 1000)
    math.randomseed(base)
    for _ = 1, 10 do math.random() end
    _RandSeeded = true
end

local function _GenerateKey()
    _EnsureSeed()
    local chunks = {}
    for _ = 1, 32 do
        chunks[#chunks + 1] = string.format('%02x', math.random(0, 255))
    end
    return table.concat(chunks)
end

local function _GetSession(source, create)
    source = tonumber(source)
    if not source or source <= 0 then return nil end

    local s = _Sessions[source]
    if s then return s end
    if create ~= true then return nil end

    s = {
        key = nil,
        issuedAtMs = 0,
        expiresAtMs = 0,
        consumedNonces = {},
        nonceQueue = {},
        seq = 0,
    }
    _Sessions[source] = s
    return s
end

local function _CleanupNonces(session, nowMs, cfg)
    if type(session) ~= 'table' then return end
    session.nonceQueue = session.nonceQueue or {}
    session.consumedNonces = session.consumedNonces or {}

    local queue = session.nonceQueue
    local ttl = cfg.nonceTtlMs
    local maxNonces = cfg.maxUsedNonces

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

---Issue (or renew) a player's bridge key. Returned to the client to store locally.
local function _IssueKey(source, forceRenew)
    local cfg = _GetCfg()
    local now = _NowMs()
    local session = _GetSession(source, true)
    if not session then return nil end

    local expired = (tonumber(session.expiresAtMs) or 0) <= now
    if forceRenew == true or expired or type(session.key) ~= 'string' then
        session.key = _GenerateKey()
        session.issuedAtMs = now
        session.expiresAtMs = now + cfg.keyTtlMs
        session.consumedNonces = {}
        session.nonceQueue = {}
        session.seq = 0
    else
        session.expiresAtMs = math.max(session.expiresAtMs or 0, now + cfg.keyTtlMs)
    end

    return {
        enabled = cfg.enabled == true,
        key = session.key,
        keyTtlMs = cfg.keyTtlMs,
        maxClockSkewMs = cfg.maxClockSkewMs,
    }
end

-- -----------------------------------------------------------------------------
-- SIGNATURE
-- -----------------------------------------------------------------------------

-- Canonical string the client and server both sign.
local function _BuildSigningString(eventName, seq, nonce, ts, args)
    local ok, argsJson = pcall(json.encode, args or {})
    if not ok or type(argsJson) ~= 'string' then
        argsJson = ''
    end
    local argsHash = LyxSHA2.sha256(argsJson)
    return table.concat({ tostring(eventName), tostring(seq), tostring(nonce), tostring(ts), argsHash }, '|')
end

local function _ExtractEnvelope(argsTable)
    if type(argsTable) ~= 'table' then return nil, argsTable end
    local n = #argsTable
    if n <= 0 then return nil, argsTable end

    local last = argsTable[n]
    if type(last) ~= 'table' or type(last.__lyxbridge) ~= 'table' then
        return nil, argsTable
    end

    -- Strip envelope from the payload the handler will receive.
    local payload = {}
    for i = 1, n - 1 do payload[i] = argsTable[i] end
    return last.__lyxbridge, payload
end

---Validate a secure event. Returns ok, reason, payloadArgs.
local function _Validate(source, eventName, rawArgs)
    local cfg = _GetCfg()
    if cfg.enabled ~= true then
        -- Bridge disabled: pass through untouched.
        return true, nil, rawArgs
    end

    local env, payload = _ExtractEnvelope(rawArgs)
    if type(env) ~= 'table' then
        return false, 'bridge_envelope_missing', payload
    end

    local now = _NowMs()
    local session = _GetSession(source, false)
    if not session or type(session.key) ~= 'string' or (tonumber(session.expiresAtMs) or 0) <= now then
        return false, 'bridge_session_missing_or_expired', payload
    end

    local nonce = tostring(env.nonce or '')
    local sig = tostring(env.sig or '')
    local ts = tonumber(env.ts) or 0
    local seq = tonumber(env.seq) or 0

    if #nonce < 8 or #nonce > 128 or not nonce:match('^[%w%-%_%.:]+$') then
        return false, 'bridge_nonce_bad_format', payload
    end
    if #sig ~= 64 or not sig:match('^%x+$') then
        return false, 'bridge_sig_bad_format', payload
    end

    -- Clock skew (client ts is optional; only enforced if provided).
    if ts > 0 then
        if math.abs(_EpochMs() - ts) > cfg.maxClockSkewMs then
            return false, 'bridge_timestamp_out_of_window', payload
        end
    end

    -- Anti-replay.
    _CleanupNonces(session, now, cfg)
    if session.consumedNonces[nonce] then
        return false, 'bridge_nonce_replay', payload
    end

    -- Recompute HMAC over the payload (NOT including the envelope).
    local expected = LyxSHA2.hmac_sha256(session.key, _BuildSigningString(eventName, seq, nonce, ts, payload))

    -- Constant-time-ish compare (length already fixed at 64).
    local diff = 0
    for i = 1, 64 do
        diff = diff | (string.byte(sig, i) ~ string.byte(expected, i))
    end
    if diff ~= 0 then
        return false, 'bridge_sig_mismatch', payload
    end

    -- Accept: consume nonce, bump seq.
    session.seq = (tonumber(session.seq) or 0) + 1
    session.consumedNonces[nonce] = now
    session.nonceQueue[#session.nonceQueue + 1] = { nonce = nonce, ts = now }
    _CleanupNonces(session, now, cfg)

    return true, nil, payload
end

-- -----------------------------------------------------------------------------
-- PUBLIC API
-- -----------------------------------------------------------------------------

---Register a server event that only accepts properly signed client triggers.
function RegisterSecureEvent(eventName, handler)
    if type(eventName) ~= 'string' or eventName == '' then
        print('^1[LyxGuard]^7 RegisterSecureEvent: invalid event name')
        return false
    end
    if type(handler) ~= 'function' then
        print('^1[LyxGuard]^7 RegisterSecureEvent: handler must be a function')
        return false
    end

    RegisterNetEvent(eventName, function(...)
        local src = source
        if not src or src <= 0 then return end

        -- Immune players still must sign (prevents spoof), but never get punished here.
        local immune = IsPlayerImmune and IsPlayerImmune(src)

        local ok, reason, payload = _Validate(src, eventName, { ... })
        if not ok then
            if MarkPlayerSuspicious then
                MarkPlayerSuspicious(src, 'secure_bridge_invalid', {
                    event = eventName,
                    reason = reason
                })
            end

            local cfg = _GetCfg()
            if cfg.punishOnInvalid and not immune and ApplyPunishment then
                ApplyPunishment(src, 'secure_bridge_invalid',
                    { punishment = cfg.punishment, tolerance = cfg.tolerance }, {
                        reason = 'Secure bridge: firma/nonce invalido',
                        event = eventName,
                        bridgeReason = reason
                    })
            end
            return
        end

        return handler(src, table.unpack(payload))
    end)

    return true
end

exports('RegisterSecureEvent', RegisterSecureEvent)

-- -----------------------------------------------------------------------------
-- KEY DELIVERY
-- -----------------------------------------------------------------------------

-- Client asks for (or refreshes) its bridge key. This is the only channel where
-- the key travels, and only server -> client.
RegisterNetEvent('lyxguard:bridge:requestKey', function()
    local src = source
    if not src or src <= 0 then return end

    local issued = _IssueKey(src, false)
    if issued and issued.enabled then
        TriggerClientEvent('lyxguard:bridge:key', src, {
            key = issued.key,
            keyTtlMs = issued.keyTtlMs,
            maxClockSkewMs = issued.maxClockSkewMs
        })
    else
        TriggerClientEvent('lyxguard:bridge:key', src, { enabled = false })
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if src then _Sessions[src] = nil end
end)

-- Periodic key rotation + stale session cleanup.
CreateThread(function()
    while true do
        Wait(60000)
        local cfg = _GetCfg()
        local now = _NowMs()
        for src, session in pairs(_Sessions) do
            if type(session) ~= 'table' or (tonumber(session.expiresAtMs) or 0) <= now then
                -- Expired: re-issue and push to client if still connected.
                if GetPlayerName(src) then
                    local issued = _IssueKey(src, true)
                    if issued and issued.enabled then
                        TriggerClientEvent('lyxguard:bridge:key', src, {
                            key = issued.key,
                            keyTtlMs = issued.keyTtlMs,
                            maxClockSkewMs = issued.maxClockSkewMs
                        })
                    end
                else
                    _Sessions[src] = nil
                end
            end
        end
    end
end)

Bridge.Validate = _Validate
Bridge.IssueKey = _IssueKey
_G.LyxSecureBridge = Bridge

print('^2[LyxGuard]^7 Secure Event Bridge loaded (HMAC + nonce, Server-Side)')
