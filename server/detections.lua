--[[
    
                   LYXGUARD v4.0 - SERVER-SIDE DETECTIONS                         
                      Event validation, money tracking, etc.                      
    
]]

-- Use ESX global from @es_extended/imports.lua when available.
local ESX = ESX
local PlayerEventCounts = {}  -- Track event triggers per player
local PlayerMoneyHistory = {} -- Track money changes per player
local SuspiciousPlayers = {}  -- Players flagged for manual review
local _YankValidateCooldown = {}
local _RiskScores = {}        -- [identifier] = { score, lastDecay, lastAction }
local _ServerAnomalySnapshots = {}
local _ServerAnomalyCooldowns = {}
local _BurstSignals = {}      -- [identifier] = { windowStartMs, total, byReason, lastEscalationMs }

local function _PushExLog(entry)
    if type(LyxGuardPushExhaustiveLog) == 'function' then
        pcall(LyxGuardPushExhaustiveLog, entry)
    end
end

-- 
-- PLAYER SAFE STATE (Grace Period System)
-- Prevents anticheat from detecting admin/txAdmin actions as cheats
-- 
PlayerSafeState = {}

-- Mark player safe from specific detections for a duration
function SetPlayerSafe(playerId, types, durationMs)
    if not PlayerSafeState[playerId] then
        PlayerSafeState[playerId] = {}
    end

    local expireTime = GetGameTimer() + (durationMs or 5000)

    if type(types) == 'table' then
        for _, t in ipairs(types) do
            PlayerSafeState[playerId][t] = expireTime
        end
    else
        PlayerSafeState[playerId][types] = expireTime
    end
end

-- Check if player is safe from a detection type
function IsPlayerSafe(playerId, detectionType)
    if not PlayerSafeState[playerId] then return false end

    local expireTime = PlayerSafeState[playerId][detectionType]
    if expireTime and GetGameTimer() < expireTime then
        return true
    end

    -- Also check "all" which gives full immunity
    local allExpire = PlayerSafeState[playerId]["all"]
    if allExpire and GetGameTimer() < allExpire then
        return true
    end

    return false
end

-- Export for use by lyx-panel and other scripts
exports('SetPlayerSafe', SetPlayerSafe)
exports('IsPlayerSafe', IsPlayerSafe)
exports('GetRiskScore', function(sourceOrIdentifier)
    local identifier = nil
    if type(sourceOrIdentifier) == 'number' then
        if sourceOrIdentifier > 0 and GetPlayerName(sourceOrIdentifier) then
            identifier = GetIdentifier(sourceOrIdentifier, 'license')
        end
    elseif type(sourceOrIdentifier) == 'string' then
        identifier = sourceOrIdentifier
    end

    if not identifier or identifier == '' or identifier == 'unknown' then
        return { identifier = identifier or 'unknown', score = 0 }
    end

    local r = _RiskScores[identifier]
    if not r then
        return { identifier = identifier, score = 0 }
    end

    return {
        identifier = identifier,
        score = tonumber(r.score) or 0,
        lastDecay = r.lastDecay,
        lastAction = r.lastAction
    }
end)

-- Get ESX (bounded wait, unified with bootstrap.lua)
CreateThread(function()
    if LyxGuard and LyxGuard.WaitForESX then
        ESX = LyxGuard.WaitForESX(15000)
    end
    ESX = ESX or _G.ESX

    if not ESX then
        print('^1[LyxGuard]^7 detections: ESX no disponible (timeout).')
        return
    end

    _G.ESX = _G.ESX or ESX
end)

-- Helper function to get player identifier
local function GetIdentifier(source, idType)
    idType = idType or 'license'
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.find(id, idType .. ':') then
            return id
        end
    end
    return 'unknown'
end

-- 
-- EVENT RATE LIMITING
-- 

local EventRateLimits = {
    ['lyx*'] = { maxPerMinute = 60, banOnExceed = false },
    ['esx:*'] = { maxPerMinute = 120, banOnExceed = false },
    ['default'] = { maxPerMinute = 200, banOnExceed = false }
}


local function GetEventConfig(eventName)
    for pattern, config in pairs(EventRateLimits) do
        if pattern:sub(-1) == '*' then
            if eventName:sub(1, #pattern - 1) == pattern:sub(1, -2) then
                return config
            end
        elseif eventName == pattern then
            return config
        end
    end
    return EventRateLimits['default']
end

local function TrackPlayerEvent(source, eventName)
    if not PlayerEventCounts[source] then
        PlayerEventCounts[source] = {}
    end

    local now = os.time()
    local events = PlayerEventCounts[source]

    if not events[eventName] then
        events[eventName] = { count = 0, firstTrigger = now }
    end

    local eventData = events[eventName]

    -- Reset counter every minute
    if now - eventData.firstTrigger >= 60 then
        eventData.count = 0
        eventData.firstTrigger = now
    end

    eventData.count = eventData.count + 1

    -- Check limits
    local config = GetEventConfig(eventName)
    if eventData.count > config.maxPerMinute then
        return false, config.banOnExceed
    end

    return true, false
end

local _ExplosionHistory = {}
local _PtfxHistory = {}
local _ClearPedTasksHistory = {}
local _EntityVehicleHistory = {}
local _EntityPedHistory = {}
local _EntityFirewallState = {} -- [source] = { windowStart, counts, models, strikes, lastStrike }

local function _GetMinuteCounter(tbl, source)
    local now = os.time()
    local t = tbl[source]
    if not t or (now - (t.first or 0)) >= 60 then
        t = { first = now, count = 0 }
        tbl[source] = t
    end
    return t
end

local function _GetEntityFirewallStateFor(source, cfg, nowMs)
    nowMs = nowMs or GetGameTimer()
    local windowMs = tonumber(cfg and cfg.windowMs) or 10000
    local strikesCfg = cfg and cfg.strikes or {}
    local decayMs = tonumber(strikesCfg.decayMs) or 60000

    local st = _EntityFirewallState[source]
    if not st then
        st = {
            windowStart = nowMs,
            counts = { vehicles = 0, peds = 0, objects = 0 },
            models = {},
            strikes = 0,
            lastStrike = 0,
        }
        _EntityFirewallState[source] = st
    end

    if (nowMs - (st.windowStart or 0)) >= windowMs then
        st.windowStart = nowMs
        st.counts.vehicles = 0
        st.counts.peds = 0
        st.counts.objects = 0
        st.models = {}
    end

    -- Decay strikes over time (avoid permanent escalation from old infractions)
    if decayMs > 0 and st.strikes and st.strikes > 0 and st.lastStrike and st.lastStrike > 0 then
        if (nowMs - st.lastStrike) >= decayMs then
            st.strikes = math.max(0, (st.strikes or 0) - 1)
            st.lastStrike = nowMs
        end
    end

    return st
end

local function _AddEntityStrike(st, nowMs, add)
    add = tonumber(add) or 1
    if add < 1 then add = 1 end
    st.strikes = (st.strikes or 0) + add
    st.lastStrike = nowMs or GetGameTimer()
end

local function _IsSourceValid(source)
    return source and source > 0 and GetPlayerName(source) ~= nil
end

local function _IsPlayerImmuneOrSafe(source, safeType)
    if IsPlayerImmune and IsPlayerImmune(source) then
        return true
    end
    if IsPlayerSafe and safeType and IsPlayerSafe(source, safeType) then
        return true
    end
    return false
end

local function _GetPlayerCoords(source)
    local ped = GetPlayerPed(source)
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        return GetEntityCoords(ped)
    end
    return nil
end

local function _BuildHashLookup(list)
    local lookup = {}
    if type(list) == 'table' then
        for _, name in ipairs(list) do
            if type(name) == 'string' and name ~= '' then
                lookup[GetHashKey(name)] = true
            end
        end
    end
    return lookup
end

local _BlacklistedVehicleModels = _BuildHashLookup(Config and Config.Blacklists and Config.Blacklists.vehicles and Config.Blacklists.vehicles.list)
local _UltraVehicleBlacklist = _BuildHashLookup(Config and Config.Ultra and Config.Ultra.vehicleSpawn and Config.Ultra.vehicleSpawn.blacklistedVehicles)
for k, v in pairs(_UltraVehicleBlacklist) do
    _BlacklistedVehicleModels[k] = v
end

local _BlacklistedPedModels = _BuildHashLookup(Config and Config.Ultra and Config.Ultra.modelExploit and Config.Ultra.modelExploit.blacklistedModels)
local _BlacklistedWeaponHashes = _BuildHashLookup(Config and Config.Blacklists and Config.Blacklists.weapons and Config.Blacklists.weapons.list)

AddEventHandler('explosionEvent', function(sender, ev)
    if not _IsSourceValid(sender) then return end
    if _IsPlayerImmuneOrSafe(sender, 'explosion') then return end

    local cfg = Config and Config.Entities and Config.Entities.explosion or nil
    if not cfg or cfg.enabled == false then return end

    local explosionType = ev and (ev.explosionType or ev.type) or nil
    local ex = ev and (ev.posX or ev.x) or 0.0
    local ey = ev and (ev.posY or ev.y) or 0.0
    local ez = ev and (ev.posZ or ev.z) or 0.0
    if ev and type(ev.pos) == 'table' then
        ex = ev.pos.x or ex
        ey = ev.pos.y or ey
        ez = ev.pos.z or ez
    end

    local inProtectedZone = false
    if type(cfg.protectedZones) == 'table' then
        for _, z in ipairs(cfg.protectedZones) do
            local zx, zy, zz, zr = z.x or 0.0, z.y or 0.0, z.z or 0.0, z.radius or 0.0
            local dx, dy, dz = (ex - zx), (ey - zy), (ez - zz)
            if (dx * dx + dy * dy + dz * dz) <= (zr * zr) then
                inProtectedZone = true
                break
            end
        end
    end

    local isBlacklistedType = false
    if explosionType ~= nil and type(cfg.blacklistedTypes) == 'table' then
        for _, t in ipairs(cfg.blacklistedTypes) do
            if t == explosionType then
                isBlacklistedType = true
                break
            end
        end
    end

    local counter = _GetMinuteCounter(_ExplosionHistory, sender)
    counter.count = (counter.count or 0) + 1

    local shouldBlock = false
    if inProtectedZone then
        shouldBlock = true
    end
    if isBlacklistedType then
        shouldBlock = true
    end
    if cfg.maxPerMinute and counter.count > (cfg.maxPerMinute or 3) then
        shouldBlock = true
    end

    if shouldBlock then
        CancelEvent()

        MarkPlayerSuspicious(sender, 'explosion_event', {
            explosionType = explosionType,
            count = counter.count,
            protectedZone = inProtectedZone
        })

        if ApplyPunishment then
            ApplyPunishment(sender, 'explosion', cfg, {
                reason = 'Explosin bloqueada (server-side)',
                explosionType = explosionType,
                count = counter.count,
                protectedZone = inProtectedZone
            }, vector3(ex, ey, ez))
        end
    end
end)

AddEventHandler('ptFxEvent', function(sender, data)
    if not _IsSourceValid(sender) then return end
    if _IsPlayerImmuneOrSafe(sender, 'ptfx') then return end

    local cfg = Config and Config.Entities and Config.Entities.ptfx or nil
    if not cfg or cfg.enabled ~= true then return end

    local counter = _GetMinuteCounter(_PtfxHistory, sender)
    counter.count = (counter.count or 0) + 1

    local maxPerMinute = tonumber(cfg.maxPerMinute) or 0
    if maxPerMinute > 0 and counter.count > maxPerMinute then
        CancelEvent()

        MarkPlayerSuspicious(sender, 'ptfx_event', {
            count = counter.count,
            maxPerMinute = maxPerMinute
        })

        if ApplyPunishment then
            ApplyPunishment(sender, 'ptfx', cfg, {
                reason = 'PTFX spam bloqueado (server-side)',
                count = counter.count,
                maxPerMinute = maxPerMinute
            }, _GetPlayerCoords(sender))
        end
    end
end)

AddEventHandler('clearPedTasksEvent', function(sender, data)
    if not _IsSourceValid(sender) then return end
    if _IsPlayerImmuneOrSafe(sender, 'tasks') then return end

    local cfg = Config and Config.Entities and Config.Entities.clearPedTasks or nil
    if not cfg or cfg.enabled ~= true then return end

    local counter = _GetMinuteCounter(_ClearPedTasksHistory, sender)
    counter.count = (counter.count or 0) + 1

    local maxPerMinute = tonumber(cfg.maxPerMinute) or 0
    if maxPerMinute > 0 and counter.count > maxPerMinute then
        CancelEvent()

        MarkPlayerSuspicious(sender, 'clear_ped_tasks_event', {
            count = counter.count,
            maxPerMinute = maxPerMinute
        })

        if ApplyPunishment then
            ApplyPunishment(sender, 'clear_ped_tasks', cfg, {
                reason = 'clearPedTasksEvent spam bloqueado (server-side)',
                count = counter.count,
                maxPerMinute = maxPerMinute
            }, _GetPlayerCoords(sender))
        end
    end
end)

AddEventHandler('entityCreating', function(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    if type(NetworkGetEntityOwner) ~= 'function' then return end

    local owner = NetworkGetEntityOwner(entity)
    if not _IsSourceValid(owner) then return end
    if _IsPlayerImmuneOrSafe(owner, 'entity') then return end

    local entType = GetEntityType(entity)
    local model = GetEntityModel(entity)
    local coords = GetEntityCoords(entity)

    if entType ~= 1 and entType ~= 2 and entType ~= 3 then
        return
    end

    local fwCfg = Config and Config.Entities and Config.Entities.entityFirewall or nil
    local nowMs = GetGameTimer()

    -- Legacy checks (per-minute) for vehicles/peds (backwards compatibility)
    local legacyShouldBlock = false
    local legacyCount = nil
    local det = (entType == 2 and 'vehicle_spawn') or (entType == 1 and 'model_exploit') or 'entity_spawn'
    local detCfg = nil
    local isBlacklisted = false

    if entType == 2 then
        detCfg = (Config and Config.Ultra and Config.Ultra.vehicleSpawn) or { enabled = true, punishment = 'warn', tolerance = 1 }
        local counter = _GetMinuteCounter(_EntityVehicleHistory, owner)
        counter.count = (counter.count or 0) + 1
        legacyCount = counter.count

        if _BlacklistedVehicleModels[model] then
            isBlacklisted = true
            legacyShouldBlock = true
        end
        if detCfg and detCfg.maxVehiclesPerMinute and counter.count > (detCfg.maxVehiclesPerMinute or 3) then
            legacyShouldBlock = true
        end
    elseif entType == 1 then
        detCfg = (Config and Config.Ultra and Config.Ultra.modelExploit) or { enabled = true, punishment = 'kick', tolerance = 1 }
        local counter = _GetMinuteCounter(_EntityPedHistory, owner)
        counter.count = (counter.count or 0) + 1
        legacyCount = counter.count

        if _BlacklistedPedModels[model] then
            isBlacklisted = true
            legacyShouldBlock = true
        end
        if detCfg and detCfg.maxModelChangesPerMinute and counter.count > (detCfg.maxModelChangesPerMinute or 3) then
            legacyShouldBlock = true
        end
    end

    -- Firewall v2: budgets per window + repeated model detection + progressive escalation.
    local fwViolation = nil
    local fwTypeKey = nil
    local fwCount = nil
    local sameModelCount = nil
    local fwState = nil
    local fwBudgetLimit = nil

    if fwCfg and fwCfg.enabled == true then
        fwTypeKey = (entType == 2 and 'vehicles') or (entType == 1 and 'peds') or 'objects'
        fwState = _GetEntityFirewallStateFor(owner, fwCfg, nowMs)
        fwState.counts[fwTypeKey] = (fwState.counts[fwTypeKey] or 0) + 1
        fwCount = fwState.counts[fwTypeKey]

        local budgets = fwCfg.budgets or {}
        fwBudgetLimit = tonumber(budgets[fwTypeKey])
        if fwBudgetLimit and fwCount > fwBudgetLimit then
            fwViolation = 'budget_exceeded'
        end

        local maxSame = tonumber(fwCfg.maxSameModel) or 0
        if maxSame > 0 then
            fwState.models[model] = (fwState.models[model] or 0) + 1
            sameModelCount = fwState.models[model]
            if not fwViolation and sameModelCount and sameModelCount > maxSame then
                fwViolation = 'repeated_model'
            end
        end

        if not fwViolation and isBlacklisted then
            fwViolation = 'blacklisted_model'
        end
    end

    local shouldBlock = legacyShouldBlock or (fwViolation ~= nil)
    if not shouldBlock then
        return
    end

    -- Build punishment config
    local punishCfg = detCfg or { enabled = true, punishment = 'notify', tolerance = 1 }
    local reason = 'Spawn de entidad bloqueado'

    if fwCfg and fwCfg.enabled == true and fwState then
        local strikesCfg = fwCfg.strikes or {}
        local add = 1
        if isBlacklisted then add = 2 end
        if fwViolation == 'budget_exceeded' and fwBudgetLimit and fwCount and fwCount > (fwBudgetLimit * 2) then
            add = math.max(add, 2)
        end

        _AddEntityStrike(fwState, nowMs, add)

        local kickAt = tonumber(strikesCfg.kickAt) or 2
        local tempAt = tonumber(strikesCfg.tempBanAt) or 4
        local permAt = tonumber(strikesCfg.permBanAt) or 6
        local tempDur = strikesCfg.tempBanDuration or 'long'

        local punishment = 'notify'
        if fwState.strikes >= permAt then
            punishment = 'ban_perm'
        elseif fwState.strikes >= tempAt then
            punishment = 'ban_temp'
        elseif fwState.strikes >= kickAt then
            punishment = 'kick'
        end

        punishCfg = { enabled = true, punishment = punishment, tolerance = 1, banDuration = tempDur }

        if fwViolation == 'budget_exceeded' then
            reason = ('Entity budget excedido (%s %d/%d)'):format(fwTypeKey, fwCount or 0, fwBudgetLimit or 0)
        elseif fwViolation == 'repeated_model' then
            reason = ('Modelo repetido demasiado (%d/%d)'):format(sameModelCount or 0, tonumber(fwCfg.maxSameModel) or 0)
        elseif fwViolation == 'blacklisted_model' then
            reason = 'Modelo blacklisted'
        else
            reason = 'Spawn de entidad bloqueado (firewall)'
        end
    else
        reason = 'Spawn de entidad bloqueado (legacy)'
    end

    if not fwCfg or fwCfg.cancelOnViolation ~= false or legacyShouldBlock then
        CancelEvent()
    end

    MarkPlayerSuspicious(owner, 'entity_firewall', {
        entityType = entType,
        model = model,
        legacyCount = legacyCount,
        windowCount = fwCount,
        sameModelCount = sameModelCount,
        violation = fwViolation,
        strikes = fwState and fwState.strikes or nil
    })

    if ApplyPunishment then
        ApplyPunishment(owner, det, punishCfg, {
            reason = reason,
            entityType = entType,
            model = model,
            legacyCount = legacyCount,
            windowCount = fwCount,
            sameModelCount = sameModelCount,
            violation = fwViolation,
            strikes = fwState and fwState.strikes or nil
        }, coords)
    end
end)

AddEventHandler('giveWeaponEvent', function(sender, data)
    if not _IsSourceValid(sender) then return end
    if _IsPlayerImmuneOrSafe(sender, 'weapon') then return end

    local weaponType = nil
    if type(data) == 'table' then
        weaponType = data.weaponType or data.weaponHash or data.weapon
    end

    local weaponHash = weaponType
    if type(weaponHash) ~= 'number' then
        weaponHash = tonumber(weaponHash)
    end

    if weaponHash and _BlacklistedWeaponHashes[weaponHash] then
        CancelEvent()

        MarkPlayerSuspicious(sender, 'give_weapon', {
            weapon = weaponHash
        })

        if ApplyPunishment then
            ApplyPunishment(sender, 'blacklist_weapon', { punishment = 'ban_perm', tolerance = 1 }, {
                reason = 'GiveWeaponEvent bloqueado (arma prohibida)',
                weapon = weaponHash
            }, _GetPlayerCoords(sender))
        end
    end
end)

-- 
-- MONEY TRACKING
-- 

local MoneyConfig = {
    maxChangePerMinute = 1000000,  -- Max money change per minute
    maxTransactionsPerMinute = 30, -- Max transactions per minute
    logAllTransactions = true
}

local function TrackMoneyChange(source, account, amount, reason)
    local identifier = GetIdentifier(source, 'license')

    if not PlayerMoneyHistory[identifier] then
        PlayerMoneyHistory[identifier] = {
            transactions = {},
            totalChange = 0,
            lastReset = os.time()
        }
    end

    local history = PlayerMoneyHistory[identifier]
    local now = os.time()

    -- Reset every minute
    if now - history.lastReset >= 60 then
        history.transactions = {}
        history.totalChange = 0
        history.lastReset = now
    end

    -- Add transaction
    table.insert(history.transactions, {
        account = account,
        amount = amount,
        reason = reason or 'unknown',
        time = now
    })

    history.totalChange = history.totalChange + math.abs(amount)

    -- Check limits
    if history.totalChange > MoneyConfig.maxChangePerMinute then
        MarkPlayerSuspicious(source, 'money_exploit', {
            totalChange = history.totalChange,
            maxAllowed = MoneyConfig.maxChangePerMinute
        })
        return false
    end

    if #history.transactions > MoneyConfig.maxTransactionsPerMinute then
        MarkPlayerSuspicious(source, 'transaction_spam', {
            transactions = #history.transactions,
            maxAllowed = MoneyConfig.maxTransactionsPerMinute
        })
        return false
    end

    -- Log if enabled
    if MoneyConfig.logAllTransactions and math.abs(amount) >= 10000 then
        LogMoneyTransaction(source, account, amount, reason)
    end

    return true
end

function LogMoneyTransaction(source, account, amount, reason)
    if not ESX then return end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    MySQL.insert([[
        INSERT INTO lyxguard_money_logs
        (identifier, player_name, account, amount, reason, log_date)
        VALUES (?, ?, ?, ?, ?, NOW())
    ]], {
        xPlayer.identifier,
        GetPlayerName(source),
        account,
        amount,
        reason or 'unknown'
    })

    if type(LyxGuardTrackPlayerAction) == 'function' then
        pcall(LyxGuardTrackPlayerAction, source, 'money_transaction', {
            account = account,
            amount = amount,
            reason = reason or 'unknown'
        }, 'debug', {
            resource = 'lyx-guard',
            throttleKey = ('money:%s:%s'):format(tostring(source), tostring(account)),
            minIntervalMs = 500
        })
    end
end

-- 
-- SUSPICIOUS PLAYER FLAGGING
-- 

local function _GetBurstCfg()
    local cfg = Config and Config.BurstPattern or nil
    if type(cfg) ~= 'table' or cfg.enabled ~= true then
        return { enabled = false }
    end

    local out = {
        enabled = true,
        windowMs = math.max(tonumber(cfg.windowMs) or 45000, 10000),
        signalThreshold = math.max(math.floor(tonumber(cfg.signalThreshold) or 10), 3),
        uniqueReasonThreshold = math.max(math.floor(tonumber(cfg.uniqueReasonThreshold) or 3), 1),
        escalationCooldownMs = math.max(tonumber(cfg.escalationCooldownMs) or 45000, 5000),
        addRiskPoints = math.max(math.floor(tonumber(cfg.addRiskPoints) or 35), 0),
    }
    return out
end

local function _ApplyBurstPattern(source, identifier, reason, details)
    local cfg = _GetBurstCfg()
    if cfg.enabled ~= true then
        return nil
    end
    if reason == 'burst_pattern' then
        return nil
    end
    if not identifier or identifier == '' or identifier == 'unknown' then
        return nil
    end

    local nowMs = GetGameTimer()
    local state = _BurstSignals[identifier]
    if not state then
        state = {
            windowStartMs = nowMs,
            total = 0,
            byReason = {},
            lastEscalationMs = 0,
        }
    end

    if (nowMs - (state.windowStartMs or nowMs)) > cfg.windowMs then
        state.windowStartMs = nowMs
        state.total = 0
        state.byReason = {}
    end

    state.total = (tonumber(state.total) or 0) + 1
    state.byReason[reason] = (tonumber(state.byReason[reason]) or 0) + 1

    local uniqueReasons = 0
    for _, count in pairs(state.byReason) do
        if (tonumber(count) or 0) > 0 then
            uniqueReasons = uniqueReasons + 1
        end
    end

    local burstTriggered = state.total >= cfg.signalThreshold and uniqueReasons >= cfg.uniqueReasonThreshold
    local canEscalate = (nowMs - (tonumber(state.lastEscalationMs) or 0)) >= cfg.escalationCooldownMs

    local burstMeta = {
        window_ms = cfg.windowMs,
        total_signals = state.total,
        unique_reasons = uniqueReasons,
        current_reason_count = state.byReason[reason] or 0
    }

    if burstTriggered and canEscalate then
        state.lastEscalationMs = nowMs
        burstMeta.triggered = true

        if cfg.addRiskPoints > 0 then
            local r = _RiskScores[identifier]
            if not r then
                r = { score = 0, lastDecay = nowMs, lastAction = 0 }
            end
            r.score = (tonumber(r.score) or 0) + cfg.addRiskPoints
            _RiskScores[identifier] = r
            burstMeta.risk_bonus = cfg.addRiskPoints
            burstMeta.risk_score_after_bonus = r.score
        end

        _PushExLog({
            level = 'high',
            actor_type = 'player',
            actor_id = identifier,
            actor_name = GetPlayerName(source),
            resource = 'lyx-guard',
            action = 'burst_pattern',
            event = tostring(reason),
            result = 'observed',
            reason = 'burst_pattern_detected',
            correlation_id = details and (details.correlation_id or details.correlationId) or nil,
            metadata = {
                source = source,
                burst = burstMeta
            }
        })
    end

    _BurstSignals[identifier] = state
    return burstMeta
end

function MarkPlayerSuspicious(source, reason, details)
    local identifier = GetIdentifier(source, 'license')
    local playerName = GetPlayerName(source)

    -- Normalize details to a JSON-safe table (best-effort).
    if type(details) ~= 'table' then
        details = { value = tostring(details) }
    end

    local burstMeta = _ApplyBurstPattern(source, identifier, reason, details)
    if burstMeta and burstMeta.triggered == true then
        details._burst = burstMeta
        if LyxGuard and LyxGuard.Quarantine and LyxGuard.Quarantine.Strike then
            pcall(function()
                LyxGuard.Quarantine.Strike(source, 'burst_pattern', {
                    reason = reason,
                    burst = burstMeta
                })
            end)
        end
    end

    if not SuspiciousPlayers[identifier] then
        SuspiciousPlayers[identifier] = { flags = {}, firstFlag = os.time() }
    end

    table.insert(SuspiciousPlayers[identifier].flags, {
        reason = reason,
        details = details,
        time = os.time()
    })

    _PushExLog({
        level = 'warn',
        actor_type = 'player',
        actor_id = identifier,
        actor_name = playerName,
        resource = 'lyx-guard',
        action = 'suspicious_signal',
        event = tostring(reason),
        result = 'observed',
        reason = tostring(reason),
        metadata = {
            source = source,
            details = details
        }
    })

    -- -----------------------------------------------------------------------
    -- Risk score accumulator (weak-signal correlation)
    -- -----------------------------------------------------------------------

    local riskCfg = Config and Config.Risk or nil
    if riskCfg and riskCfg.enabled == true and identifier and identifier ~= 'unknown' then
        local nowMs = GetGameTimer()
        local r = _RiskScores[identifier]
        if not r then
            r = { score = 0, lastDecay = nowMs, lastAction = 0 }
            _RiskScores[identifier] = r
        end

        local decayMs = tonumber(riskCfg.decayMs) or (5 * 60 * 1000)
        local decayPoints = tonumber(riskCfg.decayPoints) or 15
        if decayMs > 0 and decayPoints > 0 then
            local elapsed = nowMs - (r.lastDecay or nowMs)
            if elapsed >= decayMs then
                local steps = math.floor(elapsed / decayMs)
                r.score = math.max(0, (r.score or 0) - (steps * decayPoints))
                r.lastDecay = nowMs
            end
        end

        local pts = tonumber((riskCfg.points and riskCfg.points[reason]) or riskCfg.defaultPoints) or 10
        r.score = (r.score or 0) + pts
        _RiskScores[identifier] = r

        details._risk = {
            score = r.score,
            added = pts
        }

        local thr = riskCfg.thresholds or {}
        local kickAt = tonumber(thr.kick) or 80
        local tempAt = tonumber(thr.tempBan) or 140
        local permAt = tonumber(thr.permBan) or 220
        local cooldownMs = tonumber(riskCfg.actionCooldownMs) or (60 * 1000)

        if riskCfg.enforcePunishments == true and ApplyPunishment and GetPlayerName(source) and
            (nowMs - (r.lastAction or 0)) >= cooldownMs then
            local punishment = nil
            local cfg = nil

            if r.score >= permAt then
                punishment = 'ban_perm'
                cfg = { enabled = true, punishment = punishment, tolerance = 1 }
            elseif r.score >= tempAt then
                punishment = 'ban_temp'
                cfg = {
                    enabled = true,
                    punishment = punishment,
                    tolerance = 1,
                    banDuration = thr.tempBanDuration or 'long'
                }
            elseif r.score >= kickAt then
                punishment = 'kick'
                cfg = { enabled = true, punishment = punishment, tolerance = 1 }
            end

            if punishment and cfg then
                r.lastAction = nowMs
                _RiskScores[identifier] = r

                ApplyPunishment(source, 'risk_score', cfg, {
                    reason = 'Risk score threshold alcanzado',
                    score = r.score,
                    lastSignal = reason,
                    lastSignalPoints = pts
                }, _GetPlayerCoords(source))
            end
        end
    end

    -- -----------------------------------------------------------------------
    -- Quarantine escalation (warn -> warn -> ban)
    -- -----------------------------------------------------------------------

    if LyxGuard and LyxGuard.Quarantine and LyxGuard.Quarantine.Strike then
        pcall(function()
            LyxGuard.Quarantine.Strike(source, reason, details)
        end)
    end

    -- Log to database
    MySQL.insert([[
        INSERT INTO lyxguard_detections
        (identifier, player_name, detection_type, details, punishment, detection_date)
        VALUES (?, ?, ?, ?, 'flagged', NOW())
    ]], {
        identifier,
        playerName,
        'suspicious_' .. reason,
        json.encode(details)
    })

    -- Notify admins
    TriggerEvent('lyxguard:notifyAdmins', source, 'suspicious_' .. reason, details)

    -- Broadcast to panel
    TriggerEvent('lyxguard:onDetection', source, 'suspicious_' .. reason, details, 'flagged')

    -- Send webhook - use SendDiscordAlert if available
    if SendDiscordAlert then
        SendDiscordAlert('suspicious', playerName, reason, json.encode(details))
    elseif Config and Config.Discord and Config.Discord.webhooks and Config.Discord.webhooks.alerts then
        local webhookUrl = Config.Discord.webhooks.alerts
        if webhookUrl and webhookUrl ~= '' then
            PerformHttpRequest(webhookUrl, function() end, 'POST', json.encode({
                embeds = { {
                    title = 'Jugador Sospechoso',
                    description = string.format('**Jugador:** %s\n**Razon:** %s\n**Detalles:** %s',
                        playerName, reason, json.encode(details)),
                    color = 16744448
                } }
            }), { ['Content-Type'] = 'application/json' })
        end
    end
end

--
-- SERVER ANOMALY DETECTION (economy / inventory / player state)
--

local function _CanFlagAnomaly(identifier, reason, cooldownMs)
    if not identifier or identifier == '' then
        return false
    end

    local now = GetGameTimer()
    _ServerAnomalyCooldowns[identifier] = _ServerAnomalyCooldowns[identifier] or {}
    local last = tonumber(_ServerAnomalyCooldowns[identifier][reason]) or 0
    if (now - last) < (cooldownMs or 0) then
        return false
    end

    _ServerAnomalyCooldowns[identifier][reason] = now
    return true
end

local function _BuildAnomalySnapshot(source, xPlayer)
    if not xPlayer then return nil end

    local money = tonumber(xPlayer.getMoney and xPlayer.getMoney() or 0) or 0
    local bank = 0
    local black = 0

    do
        local acc = xPlayer.getAccount and xPlayer.getAccount('bank')
        if acc and acc.money then bank = tonumber(acc.money) or 0 end
    end
    do
        local acc = xPlayer.getAccount and xPlayer.getAccount('black_money')
        if acc and acc.money then black = tonumber(acc.money) or 0 end
    end

    local totalItems = 0
    local maxItemCount = 0
    local distinctItems = 0
    if xPlayer.getInventory then
        for _, item in pairs(xPlayer.getInventory() or {}) do
            local c = tonumber(item and item.count) or 0
            if c > 0 then
                totalItems = totalItems + c
                distinctItems = distinctItems + 1
                if c > maxItemCount then
                    maxItemCount = c
                end
            end
        end
    end

    local health, armor, speed = 0, 0, 0.0
    local ped = GetPlayerPed(source)
    if ped and ped ~= 0 then
        health = tonumber(GetEntityHealth(ped)) or 0
        armor = tonumber(GetPedArmour(ped)) or 0
        speed = tonumber(GetEntitySpeed(ped)) or 0.0
    end

    return {
        ts = os.time(),
        money = money,
        bank = bank,
        black = black,
        totalItems = totalItems,
        maxItemCount = maxItemCount,
        distinctItems = distinctItems,
        health = health,
        armor = armor,
        speed = speed,
    }
end

CreateThread(function()
    while true do
        local cfg = Config and Config.ServerAnomaly or nil
        local enabled = cfg and cfg.enabled == true
        local intervalMs = tonumber(cfg and cfg.intervalMs) or 12000
        if intervalMs < 2000 then intervalMs = 2000 end

        Wait(intervalMs)

        if not enabled then
            goto continue
        end

        if not ESX then
            ESX = (LyxGuard and LyxGuard.GetESX and LyxGuard.GetESX()) or ESX
        end
        if not ESX then
            goto continue
        end

        local ecoCfg = cfg.economy or {}
        local invCfg = cfg.inventory or {}
        local stateCfg = cfg.state or {}
        local flagCooldownMs = tonumber(cfg.flagCooldownMs) or 30000

        for _, playerId in ipairs(GetPlayers()) do
            local source = tonumber(playerId)
            if not source or source <= 0 or not GetPlayerName(source) then
                goto next_player
            end

            if IsPlayerImmune and IsPlayerImmune(source) then
                goto next_player
            end

            local xPlayer = ESX.GetPlayerFromId(source)
            if not xPlayer then
                goto next_player
            end

            local identifier = GetIdentifier(source, 'license') or ('src:' .. tostring(source))
            local current = _BuildAnomalySnapshot(source, xPlayer)
            if not current then
                goto next_player
            end

            local previous = _ServerAnomalySnapshots[identifier]
            _ServerAnomalySnapshots[identifier] = current
            if not previous then
                goto next_player
            end

            if ecoCfg.enabled == true then
                local dm = math.abs((current.money or 0) - (previous.money or 0))
                local db = math.abs((current.bank or 0) - (previous.bank or 0))
                local dk = math.abs((current.black or 0) - (previous.black or 0))

                local violated = (
                    (tonumber(ecoCfg.maxDeltaMoney) and dm > tonumber(ecoCfg.maxDeltaMoney)) or
                    (tonumber(ecoCfg.maxDeltaBank) and db > tonumber(ecoCfg.maxDeltaBank)) or
                    (tonumber(ecoCfg.maxDeltaBlack) and dk > tonumber(ecoCfg.maxDeltaBlack)) or
                    (tonumber(ecoCfg.maxAbsMoney) and current.money > tonumber(ecoCfg.maxAbsMoney)) or
                    (tonumber(ecoCfg.maxAbsBank) and current.bank > tonumber(ecoCfg.maxAbsBank)) or
                    (tonumber(ecoCfg.maxAbsBlack) and current.black > tonumber(ecoCfg.maxAbsBlack))
                )

                if violated and _CanFlagAnomaly(identifier, 'economy_anomaly', flagCooldownMs) then
                    MarkPlayerSuspicious(source, 'economy_anomaly', {
                        money = current.money,
                        bank = current.bank,
                        black = current.black,
                        deltaMoney = dm,
                        deltaBank = db,
                        deltaBlack = dk
                    })
                end
            end

            if invCfg.enabled == true then
                local violated = (
                    (tonumber(invCfg.maxTotalItems) and current.totalItems > tonumber(invCfg.maxTotalItems)) or
                    (tonumber(invCfg.maxDistinctItems) and current.distinctItems > tonumber(invCfg.maxDistinctItems)) or
                    (tonumber(invCfg.maxSingleItemCount) and current.maxItemCount > tonumber(invCfg.maxSingleItemCount))
                )

                if violated and _CanFlagAnomaly(identifier, 'inventory_anomaly', flagCooldownMs) then
                    MarkPlayerSuspicious(source, 'inventory_anomaly', {
                        totalItems = current.totalItems,
                        distinctItems = current.distinctItems,
                        maxItemCount = current.maxItemCount
                    })
                end
            end

            if stateCfg.enabled == true then
                local violated = (
                    (tonumber(stateCfg.maxHealth) and current.health > tonumber(stateCfg.maxHealth)) or
                    (tonumber(stateCfg.maxArmor) and current.armor > tonumber(stateCfg.maxArmor)) or
                    (tonumber(stateCfg.maxSpeed) and current.speed > tonumber(stateCfg.maxSpeed))
                )

                if violated and _CanFlagAnomaly(identifier, 'state_anomaly', flagCooldownMs) then
                    MarkPlayerSuspicious(source, 'state_anomaly', {
                        health = current.health,
                        armor = current.armor,
                        speed = current.speed
                    })
                end
            end

            ::next_player::
        end

        ::continue::
    end
end)

AddEventHandler('playerDropped', function()
    local source = source
    local identifier = GetIdentifier(source, 'license') or ('src:' .. tostring(source))
    _ServerAnomalySnapshots[identifier] = nil
    _ServerAnomalyCooldowns[identifier] = nil
end)

-- 
-- DAMAGE VALIDATION
-- 

local DamageConfig = {
    maxDamagePerHit = 500,     -- Max damage per single hit
    maxDamagePerSecond = 1000, -- Max damage dealt per second
    trackingWindow = 5000      -- 5 seconds window
}

local PlayerDamageHistory = {}

AddEventHandler('entityDamaged', function(victim, attacker, weapon, baseDamage)
    if attacker and DoesEntityExist(attacker) then
        local attackerPedId = GetPedSourceFromEntity(attacker)

        if attackerPedId and attackerPedId > 0 then
            local now = GetGameTimer()

            if not PlayerDamageHistory[attackerPedId] then
                PlayerDamageHistory[attackerPedId] = { damages = {}, totalDamage = 0 }
            end

            local history = PlayerDamageHistory[attackerPedId]

            -- Clean old entries
            local validDamages = {}
            for _, dmg in ipairs(history.damages) do
                if now - dmg.time < DamageConfig.trackingWindow then
                    table.insert(validDamages, dmg)
                end
            end
            history.damages = validDamages

            -- Add new damage
            table.insert(history.damages, { damage = baseDamage, time = now })

            -- Calculate total
            history.totalDamage = 0
            for _, dmg in ipairs(history.damages) do
                history.totalDamage = history.totalDamage + dmg.damage
            end

            -- Check limits
            if baseDamage > DamageConfig.maxDamagePerHit then
                MarkPlayerSuspicious(attackerPedId, 'damage_mod', {
                    damage = baseDamage,
                    weapon = weapon,
                    maxAllowed = DamageConfig.maxDamagePerHit
                })
            end

            local dps = history.totalDamage / (DamageConfig.trackingWindow / 1000)
            if dps > DamageConfig.maxDamagePerSecond then
                MarkPlayerSuspicious(attackerPedId, 'dps_exploit', {
                    dps = dps,
                    maxAllowed = DamageConfig.maxDamagePerSecond
                })
            end
        end
    end
end)

-- 
-- POSITION VALIDATION
-- 

local PlayerPositions = {}

CreateThread(function()
    while true do
        Wait(2000) -- Check every 2 seconds

        for _, playerId in ipairs(GetPlayers()) do
            local playerIdNum = tonumber(playerId)

            -- SKIP: Immune players (admins, staff, etc.)
            -- SKIP: Players in grace period (being teleported by admin/txAdmin)
            if (IsPlayerImmune and IsPlayerImmune(playerIdNum))
                or IsPlayerSafe(playerIdNum, 'teleport')
                or IsPlayerSafe(playerIdNum, 'movement')
            then
                -- Still track position for reference but don't flag
                local ped = GetPlayerPed(playerId)
                if ped and DoesEntityExist(ped) then
                    local coords = GetEntityCoords(ped)
                    PlayerPositions[playerId] = { coords = coords, time = GetGameTimer() }
                end
            else
                local ped = GetPlayerPed(playerId)
                if ped and DoesEntityExist(ped) then
                    local coords = GetEntityCoords(ped)
                    local lastPos = PlayerPositions[playerId]

                    if lastPos then
                        local dist = #(coords - lastPos.coords)
                        local timeDiff = (GetGameTimer() - lastPos.time) / 1000

                        if timeDiff > 0 then
                            local speed = dist / timeDiff -- m/s

                            -- v4.1 HOTFIX: Much higher thresholds to prevent false positives
                            -- Require BOTH high speed AND significant distance
                            -- 800 m/s threshold AND minimum 100m distance
                            if speed > 800 and dist > 100 and not IsPlayerInVehicle(playerId) then
                                -- Only flag, don't kick/ban - let client detection handle punishment
                                MarkPlayerSuspicious(playerId, 'teleport_server', {
                                    distance = dist,
                                    time = timeDiff,
                                    speed = speed
                                })
                            end
                        end
                    end

                    PlayerPositions[playerId] = { coords = coords, time = GetGameTimer() }
                end
            end
        end
    end
end)

-- 
-- HELPER: Get ped source from entity
-- 

function GetPedSourceFromEntity(entity)
    for _, playerId in ipairs(GetPlayers()) do
        if GetPlayerPed(playerId) == entity then
            return tonumber(playerId)
        end
    end
    return nil
end

function IsPlayerInVehicle(playerId)
    local ped = GetPlayerPed(playerId)
    return ped and GetVehiclePedIsIn(ped, false) ~= 0
end

-- 
-- CLEANUP
-- 

AddEventHandler('playerDropped', function()
    local source = source
    local identifier = GetIdentifier(source, 'license')
    PlayerEventCounts[source] = nil
    PlayerPositions[source] = nil
    PlayerDamageHistory[source] = nil
    PlayerSafeState[source] = nil

    _ExplosionHistory[source] = nil
    _PtfxHistory[source] = nil
    _ClearPedTasksHistory[source] = nil
    _EntityVehicleHistory[source] = nil
    _EntityPedHistory[source] = nil
    _EntityFirewallState[source] = nil
    _YankValidateCooldown[source] = nil

    if identifier and identifier ~= 'unknown' then
        _RiskScores[identifier] = nil
        SuspiciousPlayers[identifier] = nil
        _BurstSignals[identifier] = nil
    end
end)

-- 
-- MONEY LOGS TABLE
-- 
-- Table is created/updated by versioned migrations (server/migrations.lua).

-- 
-- ANTI-YANK SERVER VALIDATION
-- Client reports suspected vehicle yank, server validates attacker job/permissions
-- 

RegisterNetEvent('lyxguard:validateYank', function(attackerSource, data)
    local victim = source
    if not _IsSourceValid(victim) then return end

    local cfg = Config and Config.Entities and Config.Entities.antiYank or nil
    if not cfg or cfg.enabled ~= true then return end

    local now = GetGameTimer()
    local last = _YankValidateCooldown[victim] or 0
    if (now - last) < 2000 then return end
    _YankValidateCooldown[victim] = now

    attackerSource = tonumber(attackerSource)
    if not attackerSource or attackerSource <= 0 or not GetPlayerName(attackerSource) then
        return
    end

    if _IsPlayerImmuneOrSafe(attackerSource, 'entity') then
        return
    end

    if not ESX then
        ESX = (LyxGuard and LyxGuard.GetESX and LyxGuard.GetESX()) or ESX
    end
    if not ESX then
        return
    end

    local xA = ESX.GetPlayerFromId(attackerSource)
    local jobName = (xA and xA.getJob and xA.getJob().name) or 'unknown'

    local allowed = false
    if type(cfg.allowedJobs) == 'table' then
        for _, j in ipairs(cfg.allowedJobs) do
            if tostring(j) == tostring(jobName) then
                allowed = true
                break
            end
        end
    end

    if allowed then
        return
    end

    MarkPlayerSuspicious(attackerSource, 'anti_yank', {
        victim = GetPlayerName(victim) or 'Unknown',
        attacker = GetPlayerName(attackerSource) or 'Unknown',
        attackerJob = jobName,
        seat = type(data) == 'table' and data.seat or nil,
        doorLock = type(data) == 'table' and data.doorLock or nil
    })

    if ApplyPunishment then
        ApplyPunishment(attackerSource, 'anti_yank', cfg, {
            reason = 'Anti-Yank: remocin de vehculo no autorizada',
            victim = GetPlayerName(victim) or 'Unknown',
            attackerJob = jobName,
            seat = type(data) == 'table' and data.seat or nil,
            doorLock = type(data) == 'table' and data.doorLock or nil
        }, _GetPlayerCoords(attackerSource))
    end
end)

-- 
-- SERVER-SIDE VERIFICATION (DUAL LAYER PROTECTION)
-- El cliente enva datos, el servidor verifica
-- 

local ServerPlayerData = {}

-- Recibir datos de health/ammo del cliente para verificacin
RegisterNetEvent('lyxguard:sync:playerData', function(data)
    local source = source

    -- Verificar que el jugador existe
    if not GetPlayerName(source) then return end

    -- Verificar inmunidad
    if IsPlayerImmune and IsPlayerImmune(source) then return end

    local identifier = GetIdentifier(source, 'license')

    if not ServerPlayerData[identifier] then
        ServerPlayerData[identifier] = {
            health = data.health or 200,
            armor = data.armor or 0,
            ammo = data.ammo or {},
            weapons = data.weapons or {},
            lastUpdate = os.time()
        }
        return
    end

    local stored = ServerPlayerData[identifier]
    local now = os.time()
    local timeDiff = now - stored.lastUpdate

    --  VERIFICAR HEALTH ANORMAL 
    if data.health then
        local healthGain = data.health - (stored.health or 0)

        -- Skip if player is in safe state (being healed by admin/txAdmin)
        local isSafe = IsPlayerSafe and IsPlayerSafe(source, 'health') or false

        -- Regeneracin de vida imposible (mas de 100 HP en menos de 2 segundos)
        -- v4.1 HOTFIX: Increased threshold from 50 to 100H
        if healthGain > 100 and timeDiff < 2 and not isSafe then
            MarkPlayerSuspicious(source, 'health_hack_server', {
                healthGained = healthGain,
                timeSeconds = timeDiff,
                type = 'INSTANT_HEAL_SERVER'
            })

            -- Punishment - only warn, don't ban
            if ApplyPunishment then
                ApplyPunishment(source, 'healthhack', { punishment = 'warn', tolerance = 1 }, {
                    reason = 'Regeneracin de vida sospechosa (server-verified)'
                }, _GetPlayerCoords(source))
            end
        end

        stored.health = data.health
    end

    --  VERIFICAR ARMOR ANORMAL 
    if data.armor and data.armor > 100 then
        MarkPlayerSuspicious(source, 'armor_hack_server', {
            armor = data.armor,
            type = 'EXCESSIVE_ARMOR_SERVER'
        })
    end

    --  VERIFICAR AMMO 
    if data.ammo and data.weaponHash then
        local weaponHash = tostring(data.weaponHash)
        local currentAmmo = type(data.ammo) == 'number' and data.ammo or 0
        local shotsFired = data.shotsFired or 0

        -- Ensure stored.ammo is a table
        if type(stored.ammo) ~= 'table' then
            stored.ammo = {}
        end

        if stored.ammo[weaponHash] and type(stored.ammo[weaponHash]) == 'table' then
            local lastAmmo = stored.ammo[weaponHash].amount or 0
            local lastShots = stored.ammo[weaponHash].shots or 0

            -- v4.1 HOTFIX: Increased threshold to 10 shots, only mark suspicious, don't ban
            if shotsFired > lastShots + 10 and currentAmmo >= lastAmmo then
                MarkPlayerSuspicious(source, 'infinite_ammo_server', {
                    weapon = data.weaponHash,
                    shots = shotsFired - lastShots,
                    ammoChange = currentAmmo - lastAmmo,
                    type = 'INFINITE_AMMO_SERVER'
                })
                -- v4.1: Removed auto-ban - only mark as suspicious for manual review
            end
        end

        stored.ammo[weaponHash] = {
            amount = currentAmmo,
            shots = shotsFired
        }
    end

    stored.lastUpdate = now
end)

-- Verificar armas blacklisted desde servidor
RegisterNetEvent('lyxguard:sync:weapons', function(weapons)
    local source = source
    if not GetPlayerName(source) then return end
    if IsPlayerImmune and IsPlayerImmune(source) then return end

    local blacklisted = {
        [GetHashKey('WEAPON_MINIGUN')] = true,
        [GetHashKey('WEAPON_RAILGUN')] = true,
        [GetHashKey('WEAPON_RPG')] = true,
        [GetHashKey('WEAPON_HOMINGLAUNCHER')] = true,
        [GetHashKey('WEAPON_RAYMINIGUN')] = true,
        [GetHashKey('WEAPON_RAYCARBINE')] = true,
        [GetHashKey('WEAPON_EMPLAUNCHER')] = true
    }

    for _, weapon in ipairs(weapons or {}) do
        local w = weapon
        if type(w) ~= 'number' then w = tonumber(w) end
        if w and blacklisted[w] then
            MarkPlayerSuspicious(source, 'blacklisted_weapon_server', {
                weapon = w,
                type = 'BLACKLISTED_WEAPON_SERVER'
            })

            if ApplyPunishment then
                ApplyPunishment(source, 'blacklist_weapon', { punishment = 'ban_perm', tolerance = 1 }, {
                    reason = 'Arma ilegal detectada (server-verified): ' .. tostring(w),
                    weapon = w
                }, _GetPlayerCoords(source))
            end
        end
    end
end)

-- Cliente sincroniza datos peridicamente
CreateThread(function()
    while true do
        Wait(5000) -- Cada 5 segundos

        -- Solicitar sincronizacin a todos los jugadores
        for _, playerId in ipairs(GetPlayers()) do
            TriggerClientEvent('lyxguard:requestSync', playerId)
        end
    end
end)

-- Cleanup cuando el jugador se desconecta
AddEventHandler('playerDropped', function()
    local source = source
    local identifier = GetIdentifier(source, 'license')
    ServerPlayerData[identifier] = nil
end)

print('^2[LyxGuard]^7 Server-side detections loaded (DUAL LAYER PROTECTION)')


