--[[
    LyxGuard - Quarantine Escalation (Server-Side)

    Goal:
    - When suspicious signals are detected, warn the affected player with a 5-minute alert.
    - 2 warnings; on the 3rd strike, issue a 90-day ban for cheating.

    Notes:
    - This is meant to reduce false-positive bans on noisy servers.
    - Only "reasons" included in Config.Quarantine.reasons will generate strikes.
]]

LyxGuard = LyxGuard or {}
LyxGuard.Quarantine = LyxGuard.Quarantine or {}

local Q = LyxGuard.Quarantine

local State = {
    byIdentifier = {}, -- [identifier] = { strikes, lastStrikeMs, quarantineUntilMs, lastNotifyMs, lastReasonMs }
}

local function _Cfg()
    return Config and Config.Quarantine or nil
end

local function _NowMs()
    return GetGameTimer()
end

local function _GetIdentifierKey(source)
    source = tonumber(source)
    if not source or source <= 0 or not GetPlayerName(source) then return nil end

    if GetIdentifier then
        local id = GetIdentifier(source, 'license') or GetIdentifier(source, 'steam') or GetIdentifier(source, 'discord')
        if id and id ~= '' and id ~= 'unknown' then
            return id
        end
    end

    -- Fallback: still track, but less stable across reconnect.
    return ('src:%d'):format(source)
end

local function _IsReasonEnabled(reason)
    local cfg = _Cfg()
    if not cfg or cfg.enabled ~= true then return false end

    local reasons = cfg.reasons
    if reasons == true then return true end
    if type(reasons) ~= 'table' then return false end
    return reasons[reason] == true
end

local function _GetStrikeWeight(reason)
    local cfg = _Cfg()
    local weights = cfg and cfg.strikeWeights or nil
    if type(weights) ~= 'table' then return 1 end
    local w = tonumber(weights[reason])
    if not w or w < 1 then return 1 end
    return math.floor(w)
end

local function _GetReasonCooldownMs(cfg, reason)
    cfg = cfg or _Cfg()
    if not cfg then return 0 end

    local reasonMap = cfg.reasonCooldownMs
    if type(reasonMap) == 'table' then
        local v = tonumber(reasonMap[reason])
        if v and v > 0 then
            return math.floor(v)
        end
    end

    local def = tonumber(cfg.defaultReasonCooldownMs)
    if def and def > 0 then
        return math.floor(def)
    end

    return 0
end

---@param strikes number
---@param strikesToBan number
---@return string displayText
local function _WarnCounterText(strikes, strikesToBan)
    local warnMax = math.max(0, (tonumber(strikesToBan) or 3) - 1)
    if warnMax <= 0 then
        return tostring(strikes)
    end
    local warnCount = math.min(tonumber(strikes) or 0, warnMax)
    return ('%d/%d'):format(warnCount, warnMax)
end

---@param source number
---@param reason string
---@param details table|nil
---@return boolean didHandle
function Q.Strike(source, reason, details)
    local cfg = _Cfg()
    if not cfg or cfg.enabled ~= true then return false end

    if not _IsReasonEnabled(reason) then
        return false
    end

    source = tonumber(source)
    if not source or source <= 0 then return false end
    if not GetPlayerName(source) then return false end

    if IsPlayerImmune and IsPlayerImmune(source) then
        return false
    end

    local key = _GetIdentifierKey(source)
    if not key then return false end

    local now = _NowMs()
    local strikeWindowMs = tonumber(cfg.strikeWindowMs) or (30 * 60 * 1000)
    local alertDurationMs = tonumber(cfg.alertDurationMs) or (5 * 60 * 1000)
    local strikesToBan = tonumber(cfg.strikesToBan) or 3
    local banSeconds = tonumber(cfg.banSeconds) or (90 * 24 * 3600)
    local minNotifyIntervalMs = tonumber(cfg.minNotifyIntervalMs) or 3000

    local e = State.byIdentifier[key]
    if not e then
        e = { strikes = 0, lastStrikeMs = 0, quarantineUntilMs = 0, lastNotifyMs = 0, lastReasonMs = {} }
    elseif type(e.lastReasonMs) ~= 'table' then
        e.lastReasonMs = {}
    end

    -- Reset strikes after idle time (avoid bans from 3 unrelated events hours later).
    if e.lastStrikeMs and e.lastStrikeMs > 0 and strikeWindowMs > 0 and (now - e.lastStrikeMs) > strikeWindowMs then
        e.strikes = 0
    end

    -- Avoid repeated strike accumulation for the same reason during short windows
    -- (e.g. transient heartbeat jitter). We still refresh quarantine alert duration.
    local reasonCooldownMs = _GetReasonCooldownMs(cfg, reason)
    local lastReason = tonumber(e.lastReasonMs[reason]) or 0
    if reasonCooldownMs > 0 and lastReason > 0 and (now - lastReason) < reasonCooldownMs then
        e.quarantineUntilMs = math.max(tonumber(e.quarantineUntilMs) or 0, now + alertDurationMs)
        State.byIdentifier[key] = e
        return true
    end

    local add = _GetStrikeWeight(reason)
    e.strikes = (tonumber(e.strikes) or 0) + add
    e.lastStrikeMs = now
    e.quarantineUntilMs = math.max(tonumber(e.quarantineUntilMs) or 0, now + alertDurationMs)
    e.lastReasonMs[reason] = now
    State.byIdentifier[key] = e

    -- Log (structured logger is optional)
    if StructuredLogger and StructuredLogger.Warn then
        pcall(function()
            StructuredLogger.Warn('QUARANTINE', 'Strike added', {
                source = source,
                identifier = key,
                reason = reason,
                strikes = e.strikes,
                details = details
            })
        end)
    end

    -- Warn 1/2 and 2/2; on >= strikesToBan => ban.
    if e.strikes < strikesToBan then
        if (now - (e.lastNotifyMs or 0)) >= minNotifyIntervalMs then
            e.lastNotifyMs = now
            State.byIdentifier[key] = e

            TriggerClientEvent('lyxguard:quarantine:set', source, {
                durationMs = alertDurationMs,
                strikes = e.strikes,
                strikesToBan = strikesToBan,
                reason = reason,
            })

            local days = math.floor((banSeconds or 0) / 86400)
            local counter = _WarnCounterText(e.strikes, strikesToBan)
            TriggerClientEvent('lyxguard:notify', source, {
                type = 'warning',
                message = ('Actividad sospechosa detectada (%s). Advertencia %s. Si se repite: BAN %d dias.'):format(
                    tostring(reason),
                    counter,
                    days
                )
            })
        end

        return true
    end

    local banReason = cfg.banReason
    if type(banReason) ~= 'string' or banReason == '' then
        banReason = ('Cheating (Quarantine): %s'):format(tostring(reason))
    end

    if StructuredLogger and StructuredLogger.Critical then
        pcall(function()
            StructuredLogger.Critical('QUARANTINE', 'Ban threshold reached', {
                source = source,
                identifier = key,
                reason = reason,
                strikes = e.strikes,
            })
        end)
    end

    -- Use LyxGuard's ban function (hours). This will DropPlayer.
    if BanPlayer then
        BanPlayer(source, banReason, banSeconds, 'LyxGuard')
    else
        DropPlayer(source, banReason)
    end

    return true
end

function Q.GetState(sourceOrIdentifier)
    local key
    if type(sourceOrIdentifier) == 'number' then
        key = _GetIdentifierKey(sourceOrIdentifier)
    else
        key = tostring(sourceOrIdentifier or '')
        if key == '' then key = nil end
    end

    if not key then return nil end
    local e = State.byIdentifier[key]
    if not e then return nil end

    local now = _NowMs()
    local untilMs = tonumber(e.quarantineUntilMs) or 0
    local remaining = untilMs - now
    if remaining < 0 then remaining = 0 end

    return {
        identifier = key,
        strikes = tonumber(e.strikes) or 0,
        remainingMs = remaining,
        quarantineUntilMs = untilMs,
        lastStrikeMs = tonumber(e.lastStrikeMs) or 0,
    }
end

-- Periodic cleanup to avoid unbounded memory.
CreateThread(function()
    while true do
        Wait(10 * 60 * 1000) -- 10 min
        local cfg = _Cfg()
        local strikeWindowMs = cfg and tonumber(cfg.strikeWindowMs) or (30 * 60 * 1000)
        local maxIdleMs = math.max(strikeWindowMs, 60 * 60 * 1000) -- keep at least 1 hour

        local now = _NowMs()
        for id, e in pairs(State.byIdentifier) do
            local last = e and tonumber(e.lastStrikeMs) or 0
            if last == 0 or (now - last) > maxIdleMs then
                State.byIdentifier[id] = nil
            end
        end
    end
end)

exports('GetQuarantineState', function(sourceOrIdentifier)
    return Q.GetState(sourceOrIdentifier)
end)

print('^2[LyxGuard]^7 quarantine escalation loaded')
