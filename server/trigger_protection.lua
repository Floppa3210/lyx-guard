--[[
    LyxGuard v4.1 - Trigger Spam Protection (Server-Side)

    Extracted concepts from: FIREAC, SecureServe
    Rewritten from scratch with LyxGuard architecture

    Features:
    - Event rate limiting per player
    - Blacklisted event detection
    - Suspicious event pattern detection
]]
-- -----------------------------------------------------------------------------
-- BLACKLISTED EVENTS (From FIREAC - Money exploits, admin bypasses, etc)
-- -----------------------------------------------------------------------------

local BlacklistedEvents = {
    -- Admin menu exploits
    'AdminMenu:giveDirtyMoney',
    'AdminMenu:giveBank',
    'AdminMenu:giveCash',
    'adminmenu:setsalary',
    'adminmenu:allowall',

    -- Revive exploits
    'ems:revive',
    'paramedic:revive',
    'ambulancier:selfRespawn',

    -- Job exploits
    'NB:recruterplayer',
    'NB:destituerplayer',

    -- Jail bypasses
    'JailUpdate',

    -- Known cheats/trainers
    'llotrainer:adminKick',
    'hentailover:xdlol',

    -- Obfuscated events (suspicious by nature)
    'f0ba1292-b68d-4d95-8823-6230cdf282b6',
    '265df2d8-421b-4727-b01d-b92fd6503f5e',
    'c65a46c5-5485-4404-bacf-06a106900258',
}

-- Convert to lookup table for O(1) access
local BlacklistedEventLookup = {}
for _, event in ipairs(BlacklistedEvents) do
    BlacklistedEventLookup[event] = true
end

local function _MergeConfigBlacklistedEvents()
    local extra = Config and Config.TriggerProtection and Config.TriggerProtection.blacklistedEvents or nil
    if type(extra) ~= 'table' then
        return
    end

    for k, v in pairs(extra) do
        local ev = nil
        if type(k) == 'number' and type(v) == 'string' then
            ev = v
        elseif type(k) == 'string' and v == true then
            ev = k
        end

        if ev and ev ~= '' then
            BlacklistedEventLookup[ev] = true
        end
    end
end

_MergeConfigBlacklistedEvents()

-- ---------------------------------------------------------------------------
-- RESTRICTED EVENTS (sensitive events often abused by executors)
-- ---------------------------------------------------------------------------

local RestrictedEventDefaults = {
    -- High-confidence cheat/admin backdoor events.
    ['adminmenu:allowall'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Evento adminmenu malicioso bloqueado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['adminmenu:setsalary'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Evento adminmenu malicioso bloqueado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['adminmenu:givedirtymoney'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Evento adminmenu malicioso bloqueado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['adminmenu:givebank'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Evento adminmenu malicioso bloqueado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['adminmenu:givecash'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Evento adminmenu malicioso bloqueado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['mellotrainer:adminkick'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Evento de trainer bloqueado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['mellotrainer:admintempban'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Evento de trainer bloqueado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['hentailover:xdlol'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Evento de cheat conocido bloqueado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['banfuncreturntruzz:banac'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Evento de ban remoto malicioso bloqueado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['hcheat:tempdisabledetection'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Intento de desactivar detecciones bloqueado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['antilynx8:anticheat'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Firma de cheat menu (antilynx) detectada',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['antilynx8r4a:anticheat'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Firma de cheat menu (antilynx) detectada',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['antilynxr6:detection'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Firma de cheat menu (antilynx) detectada',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['antilynxr4:detect'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Firma de cheat menu (antilynx) detectada',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['antilynxr4:kick'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Firma de cheat menu (antilynx) detectada',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['antilynxr4:log'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Firma de cheat menu (antilynx) detectada',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['ynx8:anticheat'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Firma de cheat menu (ynx/lynx) detectada',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['lynx8:anticheat'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Firma de cheat menu (ynx/lynx) detectada',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['js:jailuser'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Evento de menu malicioso (js:jailuser) detectado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['js:jadfwmiluser'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Evento ofuscado (dfwm) detectado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['xk3ly-barbasz:getfukingmony'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Evento de money exploit conocido detectado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },
    ['xk3ly-farmer:paycheck'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Evento de money exploit conocido detectado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
    },

    -- Privileged economy/job mutation events.
    ['esx:setjob'] = {
        block = true,
        punish = false,
        detection = 'restricted_event_spoof',
        reason = 'Mutacion de job no autorizada',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
        allowPermissionLevels = { 'full' },
    },
    ['esx_society:setjob'] = {
        block = true,
        punish = false,
        detection = 'restricted_event_spoof',
        reason = 'Mutacion de job no autorizada',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
        allowPermissionLevels = { 'full' },
    },
    ['esx_society:setjobsalary'] = {
        block = true,
        punish = false,
        detection = 'restricted_event_spoof',
        reason = 'Cambio de salario no autorizado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
        allowPermissionLevels = { 'full' },
    },
    ['nb:recruterplayer'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Evento de reclutamiento no autorizado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
        allowPermissionLevels = { 'full' },
    },
    ['nb:destituerplayer'] = {
        block = true,
        punish = true,
        detection = 'restricted_event_spoof_high',
        reason = 'Evento de destitucion no autorizado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
        allowPermissionLevels = { 'full' },
    },

    -- Revive abuse (allow only medics/admin-level).
    ['esx_ambulancejob:revive'] = {
        block = true,
        punish = false,
        detection = 'restricted_event_spoof',
        reason = 'Revive no autorizado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
        allowJobs = { 'ambulance', 'ems', 'paramedic' },
        allowGroups = { 'superadmin', 'admin', 'mod', 'helper', 'master', 'owner' },
        allowPermissionLevels = { 'full', 'vip' },
    },
    ['paramedic:revive'] = {
        block = true,
        punish = false,
        detection = 'restricted_event_spoof',
        reason = 'Revive no autorizado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
        allowJobs = { 'ambulance', 'ems', 'paramedic' },
        allowGroups = { 'superadmin', 'admin', 'mod', 'helper', 'master', 'owner' },
        allowPermissionLevels = { 'full', 'vip' },
    },
    ['ems:revive'] = {
        block = true,
        punish = false,
        detection = 'restricted_event_spoof',
        reason = 'Revive no autorizado',
        allowPanelAccess = true,
        allowGuardPanelAccess = true,
        allowJobs = { 'ambulance', 'ems', 'paramedic' },
        allowGroups = { 'superadmin', 'admin', 'mod', 'helper', 'master', 'owner' },
        allowPermissionLevels = { 'full', 'vip' },
    },
}

local RestrictedEventRules = {}

local function _NormalizeRestrictedEventName(eventName)
    if type(eventName) ~= 'string' then
        return nil
    end

    local normalized = eventName:gsub('^%s+', ''):gsub('%s+$', ''):lower()
    if normalized == '' then
        return nil
    end

    return normalized
end

local function _CloneTableDeep(value)
    if type(value) ~= 'table' then
        return value
    end

    local out = {}
    for k, v in pairs(value) do
        out[k] = _CloneTableDeep(v)
    end
    return out
end

local function _NormalizeStringLookup(value)
    local lookup = {}
    if type(value) ~= 'table' then
        return lookup
    end

    for k, v in pairs(value) do
        local raw = nil
        if type(k) == 'number' and type(v) == 'string' then
            raw = v
        elseif type(k) == 'string' and v == true then
            raw = k
        end

        if raw then
            local key = tostring(raw):lower()
            if key ~= '' then
                lookup[key] = true
            end
        end
    end

    return lookup
end

local function _BuildRestrictedRule(baseRule, overrideRule)
    local base = type(baseRule) == 'table' and _CloneTableDeep(baseRule) or {}
    local src = type(overrideRule) == 'table' and overrideRule or {}

    if src.enabled ~= nil then
        base.enabled = src.enabled == true
    elseif base.enabled == nil then
        base.enabled = true
    end

    if src.block ~= nil then
        base.block = src.block ~= false
    elseif base.block == nil then
        base.block = true
    end

    if src.allowPanelAccess ~= nil then
        base.allowPanelAccess = src.allowPanelAccess ~= false
    elseif base.allowPanelAccess == nil then
        base.allowPanelAccess = true
    end

    if src.allowGuardPanelAccess ~= nil then
        base.allowGuardPanelAccess = src.allowGuardPanelAccess == true
    elseif base.allowGuardPanelAccess == nil then
        base.allowGuardPanelAccess = true
    end

    if src.detection ~= nil then
        base.detection = tostring(src.detection)
    elseif type(base.detection) ~= 'string' then
        base.detection = 'restricted_event_spoof'
    end

    if src.reason ~= nil then
        base.reason = tostring(src.reason)
    elseif type(base.reason) ~= 'string' then
        base.reason = 'Evento restringido no autorizado'
    end

    local punishEnabled = nil
    local punishPermanent = nil
    local punishDuration = nil
    local punishCooldown = nil
    local punishBy = nil

    if type(src.punish) == 'boolean' then
        punishEnabled = src.punish
    elseif type(src.punish) == 'table' then
        punishEnabled = src.punish.enabled
        punishPermanent = src.punish.permanent
        punishDuration = src.punish.durationSeconds
        punishCooldown = src.punish.cooldownMs
        punishBy = src.punish.by
    end

    if src.punishEnabled ~= nil then
        punishEnabled = src.punishEnabled
    end
    if src.punishPermanent ~= nil then
        punishPermanent = src.punishPermanent
    end
    if src.punishDurationSeconds ~= nil then
        punishDuration = src.punishDurationSeconds
    end
    if src.punishCooldownMs ~= nil then
        punishCooldown = src.punishCooldownMs
    end
    if src.punishBy ~= nil then
        punishBy = src.punishBy
    end

    if punishEnabled ~= nil then
        base.punishEnabled = punishEnabled == true
    elseif base.punishEnabled == nil then
        base.punishEnabled = false
    end

    if punishPermanent ~= nil then
        base.punishPermanent = punishPermanent ~= false
    elseif base.punishPermanent == nil then
        base.punishPermanent = true
    end

    if punishDuration ~= nil then
        base.punishDurationSeconds = tonumber(punishDuration) or 0
    elseif type(base.punishDurationSeconds) ~= 'number' then
        base.punishDurationSeconds = 0
    end

    if punishCooldown ~= nil then
        base.punishCooldownMs = math.max(tonumber(punishCooldown) or 0, 0)
    elseif type(base.punishCooldownMs) ~= 'number' then
        base.punishCooldownMs = 15000
    end

    if punishBy ~= nil then
        base.punishBy = tostring(punishBy)
    elseif type(base.punishBy) ~= 'string' or base.punishBy == '' then
        base.punishBy = 'LyxGuard TriggerProtection'
    end

    if src.allowAce ~= nil then
        base.allowAce = _NormalizeStringLookup(src.allowAce)
    elseif type(base.allowAce) ~= 'table' then
        base.allowAce = _NormalizeStringLookup(base.allowAce)
    end

    if src.allowJobs ~= nil then
        base.allowJobs = _NormalizeStringLookup(src.allowJobs)
    elseif type(base.allowJobs) ~= 'table' then
        base.allowJobs = _NormalizeStringLookup(base.allowJobs)
    end

    if src.allowGroups ~= nil then
        base.allowGroups = _NormalizeStringLookup(src.allowGroups)
    elseif type(base.allowGroups) ~= 'table' then
        base.allowGroups = _NormalizeStringLookup(base.allowGroups)
    end

    if src.allowPermissionLevels ~= nil then
        base.allowPermissionLevels = _NormalizeStringLookup(src.allowPermissionLevels)
    elseif type(base.allowPermissionLevels) ~= 'table' then
        base.allowPermissionLevels = _NormalizeStringLookup(base.allowPermissionLevels)
    end

    return base
end

local function _RefreshRestrictedEventRules()
    local merged = {}

    for eventName, rule in pairs(RestrictedEventDefaults) do
        local normalized = _NormalizeRestrictedEventName(eventName)
        if normalized then
            merged[normalized] = _BuildRestrictedRule(nil, rule)
        end
    end

    local custom = Config and Config.TriggerProtection and Config.TriggerProtection.restrictedEvents or nil
    if type(custom) == 'table' then
        for k, v in pairs(custom) do
            local eventName = nil
            if type(k) == 'number' and type(v) == 'string' then
                eventName = v
                v = true
            elseif type(k) == 'string' then
                eventName = k
            end

            local normalized = _NormalizeRestrictedEventName(eventName)
            if normalized then
                if v == false then
                    merged[normalized] = nil
                elseif v == true then
                    local fallback = merged[normalized]
                    merged[normalized] = _BuildRestrictedRule(fallback, {})
                elseif type(v) == 'table' then
                    local fallback = merged[normalized]
                    merged[normalized] = _BuildRestrictedRule(fallback, v)
                end
            end
        end
    end

    RestrictedEventRules = merged
end

_RefreshRestrictedEventRules()

-- ---------------------------------------------------------------------------
-- HONEYPOT COMMANDS (chat commands commonly used by cheat menus/executors)
-- ---------------------------------------------------------------------------

local HoneypotCommandLookup = {}

local function _NormalizeCommandName(raw)
    if type(raw) ~= 'string' then
        return nil
    end
    local cmd = raw:lower():gsub('^%s*/+', ''):gsub('%s+', '')
    if cmd == '' then
        return nil
    end
    if not cmd:match('^[%w_%.:%-]+$') then
        return nil
    end
    return cmd
end

local function _RefreshHoneypotCommands()
    HoneypotCommandLookup = {}

    local cfg = Config and Config.Advanced and Config.Advanced.honeypotCommands or nil
    if type(cfg) ~= 'table' or cfg.enabled ~= true then
        return
    end

    local list = cfg.commands
    if type(list) ~= 'table' then
        return
    end

    for k, v in pairs(list) do
        local cmd = nil
        if type(k) == 'number' and type(v) == 'string' then
            cmd = _NormalizeCommandName(v)
        elseif type(k) == 'string' and v == true then
            cmd = _NormalizeCommandName(k)
        end

        if cmd then
            HoneypotCommandLookup[cmd] = true
        end
    end
end

_RefreshHoneypotCommands()
-- -----------------------------------------------------------------------------
-- SPAM-CHECKED EVENTS (Rate-limited events)
-- -----------------------------------------------------------------------------

local SpamCheckedEvents = {
    ['esx_policejob:handcuff'] = { maxPerSecond = 2, window = 4000 },
    ['esx:giveInventoryItem'] = { maxPerSecond = 3, window = 4000 },
    ['esx_billing:sendBill'] = { maxPerSecond = 2, window = 3000 },
    ['chatEvent'] = { maxPerSecond = 3, window = 2000 },
    ['_chat:messageEntered'] = { maxPerSecond = 3, window = 2000 },
    ['gcPhone:_internalAddMessage'] = { maxPerSecond = 3, window = 4000 },
    ['ServerValidEmote'] = { maxPerSecond = 3, window = 4000 },
    ['esx:confiscatePlayerItem'] = { maxPerSecond = 2, window = 4000 },
    ['esx_vehicleshop:setVehicleOwned'] = { maxPerSecond = 1, window = 10000 },
    ['LegacyFuel:PayFuel'] = { maxPerSecond = 2, window = 4000 },
    ['CarryPeople:sync'] = { maxPerSecond = 2, window = 3000 },

    -- LyxGuard internal events (avoid DB/CPU spam)
    ['lyxguard:detection'] = { maxPerSecond = 6, window = 2000 },
    ['lyxguard:sync:playerData'] = { maxPerSecond = 2, window = 2000 },
    ['lyxguard:sync:weapons'] = { maxPerSecond = 2, window = 2000 },
}
-- -----------------------------------------------------------------------------
-- EVENT FIREWALL (Allowlist + payload anomaly checks)
-- -----------------------------------------------------------------------------

local FirewallConfig = {
    enabled = true,

    -- Only allow known lyxguard:* client -> server events.
    strictLyxGuardAllowlist = true,

    -- Very high thresholds to avoid breaking normal ESX traffic; only blocks obvious crash payloads.
    maxArgs = 24,
    maxDepth = 8,
    maxKeysPerTable = 200,
    maxTotalKeys = 2000,
    maxStringLen = 4096,
    maxTotalStringLen = 20000,
}

if Config and Config.EventFirewall then
    for k, v in pairs(Config.EventFirewall) do
        FirewallConfig[k] = v
    end
end

local AllowedLyxGuardEvents = {
    -- Core client -> server
    ['lyxguard:detection'] = true,
    ['lyxguard:heartbeat'] = true,
    ['lyxguard:sync:playerData'] = true,
    ['lyxguard:sync:weapons'] = true,
    ['lyxguard:validateYank'] = true,

    -- Guard panel
    ['lyxguard:panel:open'] = true,
    ['lyxguard:panel:close'] = true,
    ['lyxguard:panel:unban'] = true,
    ['lyxguard:panel:removeWarning'] = true,
    ['lyxguard:panel:banPlayer'] = true,
    ['lyxguard:panel:saveWebhooks'] = true,
    ['lyxguard:panel:clearDetections'] = true,
    ['lyxguard:panel:addWhitelist'] = true,
    ['lyxguard:panel:removeWhitelist'] = true,
    ['lyxguard:panel:clearAllLogs'] = true,
    ['lyxguard:panel:clearPlayerLogs'] = true,
    ['lyxguard:panel:clearPlayerWarnings'] = true,
    ['lyxguard:panel:clearOldLogs'] = true,
    ['lyxguard:panel:clearDetection'] = true,
}

local _GuardPanelWebhookKeys = {
    detections = true,
    bans = true,
    kicks = true,
    warnings = true,
    logs = true,
    screenshots = true,
    alerts = true,
}

local _GuardPanelDurationKeys = {
    short = true,
    medium = true,
    long = true,
    verylong = true,
    permanent = true,
}

local _GuardPanelIdentifierPrefixes = {
    license = true,
    steam = true,
    discord = true,
    fivem = true,
    xbl = true,
    live = true,
    ip = true,
}

local function _IsLikelyIdentifier(identifier)
    if type(identifier) ~= 'string' then
        return false
    end

    local s = identifier:gsub('%s+', '')
    if #s < 6 or #s > 128 then
        return false
    end

    local prefix, value = s:match('^(%w+):(.+)$')
    if not prefix or not value then
        return false
    end

    prefix = tostring(prefix):lower()
    if _GuardPanelIdentifierPrefixes[prefix] ~= true then
        return false
    end

    return value:match('^[%w%._%-]+$') ~= nil
end

local function _ValidateGuardPanelWebhooksPayload(data)
    if type(data) ~= 'table' then
        return false, 'schema_webhooks_not_table', { actual = type(data) }
    end

    local count = 0
    for k, v in pairs(data) do
        count = count + 1
        if count > 12 then
            return false, 'schema_webhooks_too_many_keys', { count = count }
        end

        if type(k) ~= 'string' then
            return false, 'schema_webhooks_bad_key_type', { keyType = type(k) }
        end

        if _GuardPanelWebhookKeys[k] ~= true then
            return false, 'schema_webhooks_key_not_allowed', { key = k }
        end

        if v ~= nil and type(v) ~= 'string' then
            return false, 'schema_webhooks_bad_value_type', { key = k, valueType = type(v) }
        end

        if type(v) == 'string' then
            local value = (v:gsub('%s+$', ''))
            if #value > 512 then
                return false, 'schema_webhooks_url_too_long', { key = k, len = #value, maxLen = 512 }
            end

            if value ~= '' then
                local okUrl = value:match('^https://discord%.com/api/webhooks/') or
                    value:match('^https://discordapp%.com/api/webhooks/')
                if not okUrl then
                    return false, 'schema_webhooks_url_not_allowed', { key = k }
                end
            end
        end
    end

    return true, nil, nil
end

local function _ValidateGuardPanelIdPayload(data, idField)
    if type(data) ~= 'table' then
        return false, ('schema_%s_not_table'):format(idField), { actual = type(data) }
    end

    local id = tonumber(data[idField])
    if not id then
        return false, ('schema_%s_not_number'):format(idField), { actual = type(data[idField]) }
    end
    if math.floor(id) ~= id then
        return false, ('schema_%s_not_integer'):format(idField), { value = id }
    end
    if id <= 0 or id > 2147483647 then
        return false, ('schema_%s_out_of_range'):format(idField), { value = id }
    end

    return true, nil, nil
end

local function _ValidateGuardPanelBanPayload(data)
    if type(data) ~= 'table' then
        return false, 'schema_ban_payload_not_table', { actual = type(data) }
    end

    local identifier = data.identifier
    if not _IsLikelyIdentifier(identifier) then
        return false, 'schema_ban_identifier_invalid', { identifierType = type(identifier) }
    end

    local reason = data.reason
    if reason ~= nil then
        if type(reason) ~= 'string' then
            return false, 'schema_ban_reason_bad_type', { reasonType = type(reason) }
        end
        if #reason < 1 or #reason > 200 then
            return false, 'schema_ban_reason_bad_len', { len = #reason, minLen = 1, maxLen = 200 }
        end
    end

    local playerName = data.playerName
    if playerName ~= nil then
        if type(playerName) ~= 'string' then
            return false, 'schema_ban_playerName_bad_type', { playerNameType = type(playerName) }
        end
        if #playerName < 1 or #playerName > 100 then
            return false, 'schema_ban_playerName_bad_len', { len = #playerName, minLen = 1, maxLen = 100 }
        end
    end

    local duration = data.duration
    if duration ~= nil then
        if type(duration) == 'number' then
            if math.floor(duration) ~= duration or duration < 0 or duration > 315360000 then
                return false, 'schema_ban_duration_number_out_of_range', { duration = duration }
            end
        elseif type(duration) == 'string' then
            local key = duration:lower()
            if _GuardPanelDurationKeys[key] ~= true then
                return false, 'schema_ban_duration_string_invalid', { duration = duration }
            end
        else
            return false, 'schema_ban_duration_bad_type', { durationType = type(duration) }
        end
    end

    return true, nil, nil
end

local function _ValidateGuardPanelWhitelistPayload(data, requirePlayerName)
    if type(data) ~= 'table' then
        return false, 'schema_whitelist_payload_not_table', { actual = type(data) }
    end

    if not _IsLikelyIdentifier(data.identifier) then
        return false, 'schema_whitelist_identifier_invalid', { identifierType = type(data.identifier) }
    end

    local playerName = data.playerName
    if requirePlayerName == true and (type(playerName) ~= 'string' or #playerName < 1) then
        return false, 'schema_whitelist_playerName_required', { playerNameType = type(playerName) }
    end

    if playerName ~= nil then
        if type(playerName) ~= 'string' then
            return false, 'schema_whitelist_playerName_bad_type', { playerNameType = type(playerName) }
        end
        if #playerName > 100 then
            return false, 'schema_whitelist_playerName_too_long', { len = #playerName, maxLen = 100 }
        end
    end

    return true, nil, nil
end

local function _ValidateHeartbeatPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'schema_heartbeat_payload_not_table', { actual = type(payload) }
    end

    local ver = payload.ver
    if ver ~= nil and type(ver) ~= 'string' then
        return false, 'schema_heartbeat_ver_bad_type', { actual = type(ver) }
    end
    if type(ver) == 'string' and #ver > 64 then
        return false, 'schema_heartbeat_ver_too_long', { len = #ver }
    end

    local function _CheckNumber(name, minV, maxV, integerOnly)
        local value = payload[name]
        if value == nil then return true, nil, nil end
        local num = tonumber(value)
        if not num then
            return false, ('schema_heartbeat_%s_not_number'):format(name), { actual = type(value) }
        end
        if integerOnly and math.floor(num) ~= num then
            return false, ('schema_heartbeat_%s_not_integer'):format(name), { value = num }
        end
        if minV and num < minV then
            return false, ('schema_heartbeat_%s_too_small'):format(name), { value = num, min = minV }
        end
        if maxV and num > maxV then
            return false, ('schema_heartbeat_%s_too_large'):format(name), { value = num, max = maxV }
        end
        return true, nil, nil
    end

    local checks = {
        { 'detections', 0, 2000, true },
        { 'protections', 0, 2000, true },
        { 'detHash', 0, 2147483647, true },
        { 'protHash', 0, 2147483647, true },
    }
    for _, c in ipairs(checks) do
        local ok, reason, meta = _CheckNumber(c[1], c[2], c[3], c[4])
        if not ok then return false, reason, meta end
    end

    local function _CheckNameList(fieldName)
        local arr = payload[fieldName]
        if arr == nil then return true, nil, nil end
        if type(arr) ~= 'table' then
            return false, ('schema_heartbeat_%s_not_table'):format(fieldName), { actual = type(arr) }
        end
        local count = 0
        for _, item in ipairs(arr) do
            count = count + 1
            if count > 128 then
                return false, ('schema_heartbeat_%s_too_many_items'):format(fieldName), { count = count }
            end
            if type(item) ~= 'string' then
                return false, ('schema_heartbeat_%s_item_bad_type'):format(fieldName), { itemType = type(item) }
            end
            if #item > 64 then
                return false, ('schema_heartbeat_%s_item_too_long'):format(fieldName), { len = #item }
            end
        end
        return true, nil, nil
    end

    do
        local ok, reason, meta = _CheckNameList('detNames')
        if not ok then return false, reason, meta end
    end
    do
        local ok, reason, meta = _CheckNameList('protNames')
        if not ok then return false, reason, meta end
    end

    return true, nil, nil
end

local function _ValidateDetectionPayload(args)
    local detectionType = tostring(args[1] or '')
    if detectionType == '' then
        return false, 'schema_detection_type_empty', {}
    end
    if #detectionType < 2 or #detectionType > 96 then
        return false, 'schema_detection_type_bad_len', { len = #detectionType }
    end
    if not detectionType:match('^[%w_%-%:]+$') then
        return false, 'schema_detection_type_bad_format', {}
    end

    local details = args[2]
    if details ~= nil and type(details) ~= 'table' then
        return false, 'schema_detection_details_bad_type', { actual = type(details) }
    end

    local coords = args[3]
    if coords ~= nil then
        if type(coords) ~= 'table' then
            return false, 'schema_detection_coords_bad_type', { actual = type(coords) }
        end
        if type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then
            return false, 'schema_detection_coords_bad_values', {}
        end
    end

    return true, nil, nil
end

local function _ValidateSyncPlayerDataPayload(args)
    local data = args[1]
    if type(data) ~= 'table' then
        return false, 'schema_sync_playerData_not_table', { actual = type(data) }
    end

    local function _CheckNumber(name, minV, maxV, integerOnly)
        local value = data[name]
        if value == nil then return true, nil, nil end
        local num = tonumber(value)
        if not num then
            return false, ('schema_sync_playerData_%s_not_number'):format(name), { actual = type(value) }
        end
        if integerOnly and math.floor(num) ~= num then
            return false, ('schema_sync_playerData_%s_not_integer'):format(name), { value = num }
        end
        if minV and num < minV then
            return false, ('schema_sync_playerData_%s_too_small'):format(name), { value = num, min = minV }
        end
        if maxV and num > maxV then
            return false, ('schema_sync_playerData_%s_too_large'):format(name), { value = num, max = maxV }
        end
        return true, nil, nil
    end

    local checks = {
        { 'health', 0, 300, true },
        { 'armor', 0, 300, true },
        { 'ammo', 0, 20000, true },
        { 'shotsFired', 0, 50000, true },
    }
    for _, c in ipairs(checks) do
        local ok, reason, meta = _CheckNumber(c[1], c[2], c[3], c[4])
        if not ok then return false, reason, meta end
    end

    if data.weaponHash ~= nil and type(data.weaponHash) ~= 'number' and type(data.weaponHash) ~= 'string' then
        return false, 'schema_sync_playerData_weaponHash_bad_type', { actual = type(data.weaponHash) }
    end

    return true, nil, nil
end

local function _ValidateSyncWeaponsPayload(args)
    local weapons = args[1]
    if type(weapons) ~= 'table' then
        return false, 'schema_sync_weapons_not_table', { actual = type(weapons) }
    end
    local count = 0
    for _, weapon in ipairs(weapons) do
        count = count + 1
        if count > 256 then
            return false, 'schema_sync_weapons_too_many_items', { count = count }
        end
        if type(weapon) ~= 'number' and type(weapon) ~= 'string' then
            return false, 'schema_sync_weapons_bad_item_type', { itemType = type(weapon) }
        end
    end
    return true, nil, nil
end

local function _ValidateYankPayload(args)
    local attackerSource = tonumber(args[1])
    if not attackerSource or attackerSource <= 0 or attackerSource > 4096 then
        return false, 'schema_validate_yank_attacker_invalid', { value = args[1] }
    end

    if args[2] ~= nil and type(args[2]) ~= 'table' then
        return false, 'schema_validate_yank_data_bad_type', { actual = type(args[2]) }
    end

    return true, nil, nil
end

local _GuardPanelDefaultSchemas = {
    ['lyxguard:panel:open'] = {
        minArgs = 0,
        maxArgs = 0
    },
    ['lyxguard:panel:close'] = {
        minArgs = 0,
        maxArgs = 0
    },
    ['lyxguard:panel:saveWebhooks'] = {
        minArgs = 1,
        maxArgs = 1,
        types = { [1] = 'table' },
        validate = function(args)
            return _ValidateGuardPanelWebhooksPayload(args[1])
        end
    },
    ['lyxguard:panel:unban'] = {
        minArgs = 1,
        maxArgs = 1,
        types = { [1] = 'table' },
        validate = function(args)
            return _ValidateGuardPanelIdPayload(args[1], 'banId')
        end
    },
    ['lyxguard:panel:removeWarning'] = {
        minArgs = 1,
        maxArgs = 1,
        types = { [1] = 'table' },
        validate = function(args)
            return _ValidateGuardPanelIdPayload(args[1], 'warningId')
        end
    },
    ['lyxguard:panel:banPlayer'] = {
        minArgs = 1,
        maxArgs = 1,
        types = { [1] = 'table' },
        validate = function(args)
            return _ValidateGuardPanelBanPayload(args[1])
        end
    },
    ['lyxguard:panel:clearDetections'] = {
        minArgs = 0,
        maxArgs = 1,
        types = { [1] = { 'table', 'nil' } }
    },
    ['lyxguard:panel:addWhitelist'] = {
        minArgs = 1,
        maxArgs = 1,
        types = { [1] = 'table' },
        validate = function(args)
            return _ValidateGuardPanelWhitelistPayload(args[1], false)
        end
    },
    ['lyxguard:panel:removeWhitelist'] = {
        minArgs = 1,
        maxArgs = 1,
        types = { [1] = 'table' },
        validate = function(args)
            return _ValidateGuardPanelWhitelistPayload(args[1], false)
        end
    },
    ['lyxguard:panel:clearAllLogs'] = {
        minArgs = 0,
        maxArgs = 0
    },
    ['lyxguard:panel:clearPlayerLogs'] = {
        minArgs = 1,
        maxArgs = 1,
        types = { [1] = 'string' },
        stringRules = { [1] = { minLen = 6, maxLen = 128 } },
        validate = function(args)
            if not _IsLikelyIdentifier(args[1]) then
                return false, 'schema_clear_player_logs_identifier_invalid', { valueType = type(args[1]) }
            end
            return true, nil, nil
        end
    },
    ['lyxguard:panel:clearPlayerWarnings'] = {
        minArgs = 1,
        maxArgs = 1,
        types = { [1] = 'string' },
        stringRules = { [1] = { minLen = 6, maxLen = 128 } },
        validate = function(args)
            if not _IsLikelyIdentifier(args[1]) then
                return false, 'schema_clear_player_warnings_identifier_invalid', { valueType = type(args[1]) }
            end
            return true, nil, nil
        end
    },
    ['lyxguard:panel:clearOldLogs'] = {
        minArgs = 1,
        maxArgs = 1,
        types = { [1] = 'number' },
        numberRanges = { [1] = { integer = true, min = 1, max = 365 } }
    },
    ['lyxguard:panel:clearDetection'] = {
        minArgs = 1,
        maxArgs = 1,
        types = { [1] = 'number' },
        numberRanges = { [1] = { integer = true, min = 1, max = 2147483647 } }
    },
}

local _GuardCoreDefaultSchemas = {
    ['lyxguard:heartbeat'] = {
        minArgs = 1,
        maxArgs = 1,
        types = { [1] = 'table' },
        validate = function(args)
            return _ValidateHeartbeatPayload(args[1])
        end
    },
    ['lyxguard:detection'] = {
        minArgs = 1,
        maxArgs = 3,
        types = { [1] = 'string', [2] = { 'table', 'nil' }, [3] = { 'table', 'nil' } },
        stringRules = { [1] = { minLen = 2, maxLen = 96 } },
        validate = _ValidateDetectionPayload
    },
    ['lyxguard:sync:playerData'] = {
        minArgs = 1,
        maxArgs = 1,
        types = { [1] = 'table' },
        validate = _ValidateSyncPlayerDataPayload
    },
    ['lyxguard:sync:weapons'] = {
        minArgs = 1,
        maxArgs = 1,
        types = { [1] = 'table' },
        validate = _ValidateSyncWeaponsPayload
    },
    ['lyxguard:validateYank'] = {
        minArgs = 2,
        maxArgs = 2,
        types = { [1] = 'number', [2] = { 'table', 'nil' } },
        numberRanges = { [1] = { integer = true, min = 1, max = 4096 } },
        validate = _ValidateYankPayload
    },
}

local _GuardPanelSchemasCache = nil
local _GuardPanelSchemasCacheRef = nil

local function _BuildGuardPanelSchemaMap(customSchemas)
    if type(customSchemas) ~= 'table' then
        local mergedDefaults = {}
        for eventName, schema in pairs(_GuardCoreDefaultSchemas) do
            mergedDefaults[eventName] = schema
        end
        for eventName, schema in pairs(_GuardPanelDefaultSchemas) do
            mergedDefaults[eventName] = schema
        end
        return mergedDefaults
    end

    if _GuardPanelSchemasCache ~= nil and _GuardPanelSchemasCacheRef == customSchemas then
        return _GuardPanelSchemasCache
    end

    local merged = {}
    for eventName, schema in pairs(_GuardCoreDefaultSchemas) do
        merged[eventName] = schema
    end
    for eventName, schema in pairs(_GuardPanelDefaultSchemas) do
        merged[eventName] = schema
    end

    for eventName, schema in pairs(customSchemas) do
        if schema == false then
            merged[eventName] = nil
        elseif type(schema) == 'table' then
            merged[eventName] = schema
        end
    end

    _GuardPanelSchemasCacheRef = customSchemas
    _GuardPanelSchemasCache = merged
    return merged
end

local function _SchemaTypeMatches(value, expected)
    local actual = type(value)
    if type(expected) == 'string' then
        return actual == expected
    end

    if type(expected) == 'table' then
        for _, item in ipairs(expected) do
            if actual == item then
                return true
            end
        end
        return false
    end

    return true
end

local function _HasSecurityEnvelopeArg(value)
    return type(value) == 'table' and type(value.__lyxsec) == 'table'
end

local function _GetEffectiveArgCount(eventData)
    if type(eventData) ~= 'table' then
        return 0
    end
    local argCount = #eventData
    if argCount > 0 and _HasSecurityEnvelopeArg(eventData[argCount]) then
        return argCount - 1
    end
    return argCount
end

local function _ValidateGuardPanelEventSchema(eventName, eventData, cfg)
    if type(cfg) ~= 'table' or cfg.schemaValidation ~= true then
        return true, nil, nil
    end

    local schema = cfg.schemas and cfg.schemas[eventName]
    if type(schema) ~= 'table' then
        return true, nil, nil
    end

    if type(eventData) ~= 'table' then
        return false, 'schema_payload_not_table', { payloadType = type(eventData) }
    end

    local argCount = _GetEffectiveArgCount(eventData)
    local minArgs = tonumber(schema.minArgs)
    local maxArgs = tonumber(schema.maxArgs)

    if minArgs and argCount < minArgs then
        return false, 'schema_too_few_args', { argCount = argCount, minArgs = minArgs }
    end
    if maxArgs and argCount > maxArgs then
        return false, 'schema_too_many_args', { argCount = argCount, maxArgs = maxArgs }
    end

    local types = schema.types
    if type(types) == 'table' then
        for rawIndex, expectedType in pairs(types) do
            local idx = tonumber(rawIndex)
            if idx and idx >= 1 then
                local value = eventData[idx]
                if not _SchemaTypeMatches(value, expectedType) then
                    return false, 'schema_bad_type', {
                        argIndex = idx,
                        expected = expectedType,
                        actual = type(value)
                    }
                end
            end
        end
    end

    local numberRanges = schema.numberRanges
    if type(numberRanges) == 'table' then
        for rawIndex, rules in pairs(numberRanges) do
            local idx = tonumber(rawIndex)
            if idx and idx >= 1 and type(rules) == 'table' then
                local value = eventData[idx]
                if value ~= nil then
                    local num = tonumber(value)
                    if not num then
                        return false, 'schema_number_expected', { argIndex = idx, actual = type(value) }
                    end

                    if rules.integer == true and math.floor(num) ~= num then
                        return false, 'schema_integer_expected', { argIndex = idx, value = num }
                    end

                    local minV = tonumber(rules.min)
                    local maxV = tonumber(rules.max)
                    if minV and num < minV then
                        return false, 'schema_number_too_small', { argIndex = idx, value = num, min = minV }
                    end
                    if maxV and num > maxV then
                        return false, 'schema_number_too_large', { argIndex = idx, value = num, max = maxV }
                    end
                end
            end
        end
    end

    local stringRules = schema.stringRules
    if type(stringRules) == 'table' then
        for rawIndex, rules in pairs(stringRules) do
            local idx = tonumber(rawIndex)
            if idx and idx >= 1 and type(rules) == 'table' then
                local value = eventData[idx]
                if value ~= nil and type(value) ~= 'string' then
                    return false, 'schema_string_expected', { argIndex = idx, actual = type(value) }
                end

                if type(value) == 'string' then
                    local minLen = tonumber(rules.minLen)
                    local maxLen = tonumber(rules.maxLen)
                    if minLen and #value < minLen then
                        return false, 'schema_string_too_short', { argIndex = idx, len = #value, minLen = minLen }
                    end
                    if maxLen and #value > maxLen then
                        return false, 'schema_string_too_long', { argIndex = idx, len = #value, maxLen = maxLen }
                    end
                end
            end
        end
    end

    if type(schema.validate) == 'function' then
        local ok, valid, reason, meta = pcall(schema.validate, eventData)
        if not ok then
            return false, 'schema_custom_validator_error', { error = tostring(valid) }
        end
        if valid ~= true then
            return false, tostring(reason or 'schema_custom_validator_failed'), meta
        end
    end

    return true, nil, nil
end

local function _InspectPayload(value, depth, stats)
    if stats.tooDeep or stats.tooManyKeys or stats.tooMuchString or stats.badType then
        return
    end

    if depth > FirewallConfig.maxDepth then
        stats.tooDeep = true
        return
    end

    local t = type(value)
    if t == 'string' then
        local len = #value
        stats.totalStringLen = stats.totalStringLen + len
        if len > stats.maxStringLen then
            stats.maxStringLen = len
        end
        if len > FirewallConfig.maxStringLen or stats.totalStringLen > FirewallConfig.maxTotalStringLen then
            stats.tooMuchString = true
        end
        return
    end

    if t == 'number' or t == 'boolean' or t == 'nil' then
        return
    end

    if t == 'table' then
        local keys = 0
        for k, v in pairs(value) do
            keys = keys + 1
            stats.totalKeys = stats.totalKeys + 1

            if keys > FirewallConfig.maxKeysPerTable or stats.totalKeys > FirewallConfig.maxTotalKeys then
                stats.tooManyKeys = true
                return
            end

            local kt = type(k)
            if kt ~= 'string' and kt ~= 'number' then
                stats.badType = true
                stats.badTypeName = 'bad_key_' .. kt
                return
            end

            _InspectPayload(v, depth + 1, stats)
            if stats.tooDeep or stats.tooManyKeys or stats.tooMuchString or stats.badType then
                return
            end
        end
        return
    end

    -- function / userdata / thread etc => always suspicious in event payload
    stats.badType = true
    stats.badTypeName = t
end
-- -----------------------------------------------------------------------------
-- PLAYER EVENT TRACKING
-- -----------------------------------------------------------------------------

local PlayerEventHistory = {}

local function _GetTriggerCfg()
    return (Config and Config.TriggerProtection) or {}
end

local function _GetSpamScale()
    local cfg = _GetTriggerCfg()
    local scale = tonumber(cfg.spamScale) or 1.0
    if scale < 1.0 then scale = 1.0 end

    local adaptive = cfg.adaptiveBaseline
    if type(adaptive) == 'table' and adaptive.enabled == true then
        local players = #GetPlayers()
        local basePlayers = tonumber(adaptive.basePlayers) or 32
        if basePlayers < 1 then basePlayers = 1 end

        local playerStep = tonumber(adaptive.playerStep) or 16
        if playerStep < 1 then playerStep = 1 end

        local maxPlayerBonus = tonumber(adaptive.maxPlayerBonus) or 2.0
        if maxPlayerBonus < 0 then maxPlayerBonus = 0 end

        local playerBonus = 0
        if players > basePlayers then
            playerBonus = (players - basePlayers) / playerStep
            if playerBonus > maxPlayerBonus then
                playerBonus = maxPlayerBonus
            end
        end

        local useUtc = adaptive.useUtc == true
        local hour = tonumber(os.date(useUtc and '!%H' or '%H')) or 0
        if hour < 0 then hour = 0 end
        if hour > 23 then hour = 23 end

        local peakStart = tonumber(adaptive.peakStartHour) or 18
        local peakEnd = tonumber(adaptive.peakEndHour) or 23
        local peakMultiplier = tonumber(adaptive.peakMultiplier) or 1.15
        local offPeakMultiplier = tonumber(adaptive.offPeakMultiplier) or 1.0

        local inPeak = false
        if peakStart <= peakEnd then
            inPeak = (hour >= peakStart and hour <= peakEnd)
        else
            inPeak = (hour >= peakStart or hour <= peakEnd)
        end

        scale = scale * (1.0 + playerBonus)
        scale = scale * (inPeak and peakMultiplier or offPeakMultiplier)

        local maxScale = tonumber(adaptive.maxScale) or 12.0
        if maxScale >= 1.0 and scale > maxScale then
            scale = maxScale
        end
    end

    if scale < 1.0 then scale = 1.0 end
    return scale
end

local function _GetSpamFlagCooldownMs()
    local cfg = _GetTriggerCfg()
    local v = tonumber(cfg.spamFlagCooldownMs) or 5000
    if v < 1000 then v = 1000 end
    return v
end

local function _GetMassiveFlagCooldownMs()
    local cfg = _GetTriggerCfg()
    local v = tonumber(cfg.massiveFlagCooldownMs) or 15000
    if v < 1000 then v = 1000 end
    return v
end

local function _GetMinSessionForSpamMs()
    local cfg = _GetTriggerCfg()
    local sec = tonumber(cfg.minSessionSecondsForSpamFlag) or 30
    if sec < 0 then sec = 0 end
    return sec * 1000
end

local function _CanFlagByCooldown(lastFlagMs, cooldownMs, now)
    return (now - (tonumber(lastFlagMs) or 0)) >= (cooldownMs or 0)
end

local function _ShouldFlagSpam(history, spamDetails, now)
    if not history then return true end
    local minSessionMs = _GetMinSessionForSpamMs()
    if minSessionMs <= 0 then return true end

    local firstSeen = tonumber(history.firstSeenMs) or now
    local sessionMs = now - firstSeen
    if sessionMs >= minSessionMs then
        return true
    end

    -- During first seconds after join, only flag if clearly above threshold.
    local maxAllowed = tonumber(spamDetails and spamDetails.maxAllowed) or 0
    local count = tonumber(spamDetails and spamDetails.count) or 0
    local severeFactor = 2.5
    return maxAllowed > 0 and count >= (maxAllowed * severeFactor)
end

local function GetPlayerEventHistory(source)
    if not PlayerEventHistory[source] then
        PlayerEventHistory[source] = {
            events = {},
            totalTriggers = 0,
            lastReset = os.time(),
            firstSeenMs = GetGameTimer(),
            lastMassiveFlagMs = 0,
        }
    end
    return PlayerEventHistory[source]
end

local function TrackEvent(source, eventName)
    local history = GetPlayerEventHistory(source)
    local now = GetGameTimer()

    -- Reset if too old
    if os.time() - history.lastReset > 60 then
        history.events = {}
        history.totalTriggers = 0
        history.lastReset = os.time()
    end

    -- Track this event
    if not history.events[eventName] then
        history.events[eventName] = {
            triggers = {},
            count = 0
        }
    end

    local eventHistory = history.events[eventName]
    table.insert(eventHistory.triggers, now)
    eventHistory.count = eventHistory.count + 1
    history.totalTriggers = history.totalTriggers + 1

    if type(LyxGuardTrackPlayerAction) == 'function' then
        pcall(LyxGuardTrackPlayerAction, source, 'server_event_triggered', {
            event = eventName,
            count_for_event = eventHistory.count,
            total_triggers = history.totalTriggers
        }, 'debug', {
            resource = 'lyx-guard',
            event = eventName,
            result = 'observed',
            throttleKey = ('event:%s:%s'):format(tostring(source), tostring(eventName)),
            minIntervalMs = 1500
        })
    end

    -- Cleanup old triggers (keep last 5 seconds)
    local validTriggers = {}
    for _, triggerTime in ipairs(eventHistory.triggers) do
        if now - triggerTime < 10000 then
            table.insert(validTriggers, triggerTime)
        end
    end
    eventHistory.triggers = validTriggers

    return eventHistory
end
-- -----------------------------------------------------------------------------
-- SPAM CHECK FUNCTION
-- -----------------------------------------------------------------------------

local function CheckEventSpam(source, eventName)
    local spamConfig = SpamCheckedEvents[eventName]
    if not spamConfig then return false end

    local history = GetPlayerEventHistory(source)
    local eventHistory = history.events[eventName]
    if not eventHistory then return false end

    local now = GetGameTimer()
    local recentCount = 0

    -- Count triggers within window
    for _, triggerTime in ipairs(eventHistory.triggers) do
        if now - triggerTime < spamConfig.window then
            recentCount = recentCount + 1
        end
    end

    -- Check if exceeds limit
    local scale = _GetSpamScale()
    local maxAllowed = (spamConfig.maxPerSecond * (spamConfig.window / 1000)) * scale
    return recentCount > maxAllowed, {
        count = recentCount,
        maxAllowed = maxAllowed,
        window = spamConfig.window,
        scale = scale
    }
end

local function _StartsWith(value, prefix)
    return type(value) == 'string' and type(prefix) == 'string' and value:sub(1, #prefix) == prefix
end

local function _GetTxAdminProtectCfg()
    local root = Config and Config.TriggerProtection and Config.TriggerProtection.txAdminEventProtection or {}
    local punish = type(root.punish) == 'table' and root.punish or {}

    local ace = root.allowedAce
    if type(ace) ~= 'table' then
        ace = {}
    end

    return {
        enabled = root.enabled ~= false,
        eventPrefix = tostring(root.eventPrefix or 'txsv:'),
        allowedAce = ace,
        punishEnabled = punish.enabled ~= false,
        permanent = punish.permanent ~= false,
        durationSeconds = tonumber(punish.durationSeconds) or 0,
        reason = tostring(punish.reason or 'Cheating detected (txAdmin event spoof)'),
        by = tostring(punish.by or 'LyxGuard TriggerProtection')
    }
end

local function _GetPanelAdminProtectCfg()
    local root = Config and Config.TriggerProtection and Config.TriggerProtection.panelAdminEventProtection or {}
    local punish = type(root.punish) == 'table' and root.punish or {}

    local ace = root.allowedAce
    if type(ace) ~= 'table' then
        ace = {}
    end

    local protectedEvents = {}
    local defaults = {
        ['lyxpanel:setStaffStatus'] = true,
        ['lyxpanel:requestStaffSync'] = true,
        ['lyxpanel:reports:claim'] = true,
        ['lyxpanel:reports:resolve'] = true,
        ['lyxpanel:reports:get'] = true,
        ['lyxpanel:danger:approve'] = true,
        ['lyxpanel:staffcmd:requestRevive'] = true,
        ['lyxpanel:staffcmd:requestInstantRespawn'] = true,
        ['lyxpanel:staffcmd:requestAmmoRefill'] = true,
    }

    for ev, enabled in pairs(defaults) do
        if enabled == true then
            protectedEvents[ev] = true
        end
    end

    local extra = root.protectedEvents
    if type(extra) == 'table' then
        for k, v in pairs(extra) do
            local ev = nil
            if type(k) == 'number' and type(v) == 'string' then
                ev = v
                v = true
            elseif type(k) == 'string' then
                ev = k
            end

            if ev and ev ~= '' then
                protectedEvents[ev] = (v == true)
            end
        end
    end

    return {
        enabled = root.enabled ~= false,
        eventPrefix = tostring(root.eventPrefix or 'lyxpanel:action:'),
        allowedAce = ace,
        protectedEvents = protectedEvents,
        punishEnabled = punish.enabled ~= false,
        permanent = punish.permanent ~= false,
        durationSeconds = tonumber(punish.durationSeconds) or 0,
        punishCooldownMs = math.max(tonumber(punish.cooldownMs) or 15000, 0),
        reason = tostring(punish.reason or 'Cheating detected (LyxPanel admin event spoof)'),
        by = tostring(punish.by or 'LyxGuard TriggerProtection')
    }
end

local function _GetGuardPanelProtectCfg()
    local root = Config and Config.TriggerProtection and Config.TriggerProtection.guardPanelEventProtection or {}
    local punish = type(root.punish) == 'table' and root.punish or {}

    local ace = root.allowedAce
    if type(ace) ~= 'table' then
        ace = {}
    end

    local excluded = root.excludedEvents
    if type(excluded) ~= 'table' then
        excluded = {}
    end

    local schemas = _BuildGuardPanelSchemaMap(root.schemas)

    return {
        enabled = root.enabled ~= false,
        eventPrefix = tostring(root.eventPrefix or 'lyxguard:panel:'),
        allowedAce = ace,
        excludedEvents = excluded,
        schemaValidation = root.schemaValidation ~= false,
        schemas = schemas,
        actionSecurity = type(root.actionSecurity) == 'table' and root.actionSecurity or {},
        punishEnabled = punish.enabled ~= false,
        permanent = punish.permanent ~= false,
        durationSeconds = tonumber(punish.durationSeconds) or 0,
        punishCooldownMs = math.max(tonumber(punish.cooldownMs) or 15000, 0),
        reason = tostring(punish.reason or 'Cheating detected (LyxGuard panel event spoof)'),
        by = tostring(punish.by or 'LyxGuard TriggerProtection')
    }
end

local function _HasAnyAce(source, aceList)
    if type(aceList) ~= 'table' then return false end

    for _, ace in ipairs(aceList) do
        if type(ace) == 'string' and ace ~= '' and IsPlayerAceAllowed(source, ace) then
            return true
        end
    end

    return false
end

local function _HandleTxAdminEventSpoof(source, eventName)
    local cfg = _GetTxAdminProtectCfg()
    if cfg.enabled ~= true then return false end
    if not _StartsWith(eventName, cfg.eventPrefix) then return false end
    if _HasAnyAce(source, cfg.allowedAce) then return false end

    CancelEvent()

    if MarkPlayerSuspicious then
        MarkPlayerSuspicious(source, 'txadmin_event_spoof', {
            event = eventName,
            prefix = cfg.eventPrefix
        })
    end

    if ApplyPunishment then
        ApplyPunishment(source, 'txadmin_event_spoof', { punishment = 'none', tolerance = 1 }, {
            reason = 'txAdmin event spoof blocked',
            event = eventName
        })
    end

    if cfg.punishEnabled then
        local reason = ('%s | event=%s'):format(cfg.reason, tostring(eventName))
        local duration = cfg.permanent and 0 or math.max(tonumber(cfg.durationSeconds) or 0, 60)

        if BanPlayer then
            BanPlayer(source, reason, duration, cfg.by)
        else
            DropPlayer(source, reason)
        end
    end

    return true
end
-- -----------------------------------------------------------------------------
-- EVENT HANDLER WRAPPER
-- -----------------------------------------------------------------------------

local _PanelSpoofPunishCooldown = {}

local function _CanPunishPanelSpoof(source, cfg)
    local cooldownMs = tonumber(cfg and cfg.punishCooldownMs) or 0
    if cooldownMs <= 0 then return true end

    local now = GetGameTimer()
    local last = _PanelSpoofPunishCooldown[source] or 0
    if (now - last) < cooldownMs then
        return false
    end

    _PanelSpoofPunishCooldown[source] = now
    return true
end

local function _HasPanelAccessViaExport(source)
    if GetResourceState('lyx-panel') ~= 'started' then
        return false
    end

    local ok, has = pcall(function()
        return exports['lyx-panel']:HasPanelAccess(source)
    end)

    return ok == true and has == true
end

local function _HasGuardPanelAccessViaExport(source)
    local ok, has = pcall(function()
        return exports['lyx-guard']:HasPanelAccess(source)
    end)

    return ok == true and has == true
end

local _RestrictedEventPunishCooldown = {}

local function _LookupNormalized(map, value)
    if type(map) ~= 'table' then
        return false
    end
    if type(value) ~= 'string' or value == '' then
        return false
    end
    return map[value:lower()] == true
end

local function _GetRestrictedPlayerContext(source)
    local ctx = {
        group = nil,
        job = nil,
        permissionLevel = nil
    }

    if type(GetPlayerPermissionLevel) == 'function' then
        local ok, level = pcall(GetPlayerPermissionLevel, source)
        if ok and type(level) == 'string' and level ~= '' then
            ctx.permissionLevel = level:lower()
        end
    end

    local esxObj = _G.ESX
    if type(esxObj) == 'table' and type(esxObj.GetPlayerFromId) == 'function' then
        local ok, xPlayer = pcall(esxObj.GetPlayerFromId, source)
        if ok and xPlayer then
            if type(xPlayer.getGroup) == 'function' then
                local gok, g = pcall(xPlayer.getGroup, xPlayer)
                if gok and type(g) == 'string' and g ~= '' then
                    ctx.group = g:lower()
                end
            elseif type(xPlayer.group) == 'string' and xPlayer.group ~= '' then
                ctx.group = xPlayer.group:lower()
            end

            local jobData = nil
            if type(xPlayer.getJob) == 'function' then
                local jok, j = pcall(xPlayer.getJob, xPlayer)
                if jok then
                    jobData = j
                end
            end
            if not jobData and type(xPlayer.job) == 'table' then
                jobData = xPlayer.job
            end

            if type(jobData) == 'table' then
                local jobName = jobData.name or jobData.label
                if type(jobName) == 'string' and jobName ~= '' then
                    ctx.job = jobName:lower()
                end
            end
        end
    end

    if (not ctx.group or not ctx.job) and type(Player) == 'function' then
        local p = Player(source)
        local state = p and p.state or nil
        if state then
            if not ctx.group then
                local sg = state.group
                if type(sg) == 'string' and sg ~= '' then
                    ctx.group = sg:lower()
                end
            end

            if not ctx.job then
                local sj = state.job
                if type(sj) == 'table' then
                    sj = sj.name or sj.label
                end
                if type(sj) == 'string' and sj ~= '' then
                    ctx.job = sj:lower()
                end
            end
        end
    end

    return ctx
end

local function _CanPunishRestrictedEvent(source, rule)
    local cooldownMs = tonumber(rule and rule.punishCooldownMs) or 0
    if cooldownMs <= 0 then
        return true
    end

    local now = GetGameTimer()
    local last = _RestrictedEventPunishCooldown[source] or 0
    if (now - last) < cooldownMs then
        return false
    end

    _RestrictedEventPunishCooldown[source] = now
    return true
end

local function _IsRestrictedEventAllowed(source, rule, ctx)
    if IsPlayerImmune and IsPlayerImmune(source) then
        return true
    end

    if rule.allowPanelAccess ~= false and _HasPanelAccessViaExport(source) then
        return true
    end

    if rule.allowGuardPanelAccess == true and _HasGuardPanelAccessViaExport(source) then
        return true
    end

    if _HasAnyAce(source, rule.allowAce) then
        return true
    end

    if _LookupNormalized(rule.allowPermissionLevels, ctx.permissionLevel) then
        return true
    end

    if _LookupNormalized(rule.allowGroups, ctx.group) then
        return true
    end

    if _LookupNormalized(rule.allowJobs, ctx.job) then
        return true
    end

    return false
end

local function _HandleRestrictedEvent(source, eventName, eventData)
    local normalized = _NormalizeRestrictedEventName(eventName)
    if not normalized then
        return false
    end

    local rule = RestrictedEventRules[normalized]
    if type(rule) ~= 'table' or rule.enabled ~= true then
        return false
    end

    local ctx = _GetRestrictedPlayerContext(source)
    if _IsRestrictedEventAllowed(source, rule, ctx) then
        return false
    end

    local detection = tostring(rule.detection or 'restricted_event_spoof')
    local argCount = (type(eventData) == 'table') and #eventData or nil

    if rule.block ~= false then
        CancelEvent()
    end

    if MarkPlayerSuspicious then
        MarkPlayerSuspicious(source, detection, {
            event = eventName,
            group = ctx.group,
            job = ctx.job,
            permissionLevel = ctx.permissionLevel,
            args = argCount
        })
    end

    if ApplyPunishment then
        ApplyPunishment(source, detection, { punishment = 'none', tolerance = 1 }, {
            reason = tostring(rule.reason or 'Evento restringido no autorizado'),
            event = eventName,
            group = ctx.group,
            job = ctx.job,
            permissionLevel = ctx.permissionLevel,
            args = argCount
        })
    end

    if rule.punishEnabled and _CanPunishRestrictedEvent(source, rule) then
        local reason = ('%s | event=%s'):format(
            tostring(rule.reason or 'Evento restringido no autorizado'),
            tostring(eventName)
        )
        local duration = (rule.punishPermanent == true) and 0 or math.max(tonumber(rule.punishDurationSeconds) or 0, 60)
        local by = tostring(rule.punishBy or 'LyxGuard TriggerProtection')

        if BanPlayer then
            BanPlayer(source, reason, duration, by)
        else
            DropPlayer(source, reason)
        end
    end

    return rule.block ~= false
end

local function _HandlePanelAdminEventSpoof(source, eventName)
    local cfg = _GetPanelAdminProtectCfg()
    if cfg.enabled ~= true then return false end
    local isProtected = _StartsWith(eventName, cfg.eventPrefix) or (cfg.protectedEvents and cfg.protectedEvents[eventName] == true)
    if not isProtected then return false end

    if _HasPanelAccessViaExport(source) or _HasAnyAce(source, cfg.allowedAce) then
        return false
    end

    CancelEvent()

    if MarkPlayerSuspicious then
        MarkPlayerSuspicious(source, 'lyxpanel_admin_event_spoof', {
            event = eventName,
            prefix = cfg.eventPrefix
        })
    end

    if ApplyPunishment then
        ApplyPunishment(source, 'lyxpanel_admin_event_spoof', { punishment = 'none', tolerance = 1 }, {
            reason = 'LyxPanel admin event spoof blocked',
            event = eventName
        })
    end

    if cfg.punishEnabled and _CanPunishPanelSpoof(source, cfg) then
        local reason = ('%s | event=%s'):format(cfg.reason, tostring(eventName))
        local duration = cfg.permanent and 0 or math.max(tonumber(cfg.durationSeconds) or 0, 60)

        if BanPlayer then
            BanPlayer(source, reason, duration, cfg.by)
        else
            DropPlayer(source, reason)
        end
    end

    return true
end

local function _HandleGuardPanelEventSpoof(source, eventName)
    local cfg = _GetGuardPanelProtectCfg()
    if cfg.enabled ~= true then return false end
    if not _StartsWith(eventName, cfg.eventPrefix) then return false end
    if cfg.excludedEvents[eventName] == true then
        return false
    end

    if _HasGuardPanelAccessViaExport(source) or _HasAnyAce(source, cfg.allowedAce) then
        return false
    end

    CancelEvent()

    if MarkPlayerSuspicious then
        MarkPlayerSuspicious(source, 'lyxguard_panel_event_spoof', {
            event = eventName,
            prefix = cfg.eventPrefix
        })
    end

    if ApplyPunishment then
        ApplyPunishment(source, 'lyxguard_panel_event_spoof', { punishment = 'none', tolerance = 1 }, {
            reason = 'LyxGuard panel event spoof blocked',
            event = eventName
        })
    end

    if cfg.punishEnabled and _CanPunishPanelSpoof(source, cfg) then
        local reason = ('%s | event=%s'):format(cfg.reason, tostring(eventName))
        local duration = cfg.permanent and 0 or math.max(tonumber(cfg.durationSeconds) or 0, 60)

        if BanPlayer then
            BanPlayer(source, reason, duration, cfg.by)
        else
            DropPlayer(source, reason)
        end
    end

    return true
end

local function _ValidateGuardPanelActionSecurity(source, eventName, eventData, cfg)
    local secRoot = cfg and cfg.actionSecurity
    if type(secRoot) ~= 'table' or secRoot.enabled == false then
        return true, nil, nil
    end
    if secRoot.requireForPanelEvents == false then
        return true, nil, nil
    end

    if type(ValidateGuardPanelActionEnvelope) == 'function' then
        local ok, allowed, reason, meta = pcall(ValidateGuardPanelActionEnvelope, source, eventName, eventData)
        if ok then
            if allowed == true then
                return true, nil, meta
            end
            return false, tostring(reason or 'security_validation_failed'), meta
        end
        return false, 'security_validator_error', { error = tostring(allowed) }
    end

    if GetResourceState('lyx-guard') == 'started' and exports['lyx-guard'] and exports['lyx-guard'].ValidateGuardPanelActionEnvelope then
        local ok, allowed, reason, meta = pcall(function()
            return exports['lyx-guard']:ValidateGuardPanelActionEnvelope(source, eventName, eventData)
        end)
        if ok then
            if allowed == true then
                return true, nil, meta
            end
            return false, tostring(reason or 'security_validation_failed'), meta
        end
        return false, 'security_validator_error', { error = tostring(allowed) }
    end

    return false, 'security_validator_unavailable', {}
end

-- Store original RegisterNetEvent if not already wrapped
if not _G.LyxGuard_OriginalRegisterNetEvent then
    _G.LyxGuard_OriginalRegisterNetEvent = RegisterNetEvent
end

-- Create protected event handler
function RegisterProtectedNetEvent(eventName, handler)
    return _G.LyxGuard_OriginalRegisterNetEvent(eventName, function(...)
        local source = source

        -- Skip if no source (internal event)
        if not source or source <= 0 then
            return handler(...)
        end

        -- Check if player is immune
        if IsPlayerImmune and IsPlayerImmune(source) then
            return handler(...)
        end

        if _HandleRestrictedEvent(source, eventName, { ... }) then
            return
        end

        -- Check blacklisted events
        if BlacklistedEventLookup[eventName] then
            -- Log and reject
            if MarkPlayerSuspicious then
                MarkPlayerSuspicious(source, 'blacklisted_event', {
                    event = eventName,
                    type = 'BLACKLISTED_TRIGGER'
                })
            end

            return -- Block the event
        end

        -- Track event
        TrackEvent(source, eventName)

        -- Check spam
        local isSpam, spamDetails = CheckEventSpam(source, eventName)
        if isSpam then
            local history = GetPlayerEventHistory(source)
            local eventHistory = history and history.events and history.events[eventName] or nil
            local now = GetGameTimer()
            local spamCooldown = _GetSpamFlagCooldownMs()
            local canFlag = _ShouldFlagSpam(history, spamDetails, now) and
                _CanFlagByCooldown(eventHistory and eventHistory.lastSpamFlagMs, spamCooldown, now)

            if canFlag and eventHistory then
                eventHistory.lastSpamFlagMs = now
            end

            if canFlag and MarkPlayerSuspicious then
                MarkPlayerSuspicious(source, 'event_spam', {
                    event = eventName,
                    count = spamDetails.count,
                    maxAllowed = spamDetails.maxAllowed,
                    scale = spamDetails.scale
                })
            end

            return -- Block the event
        end

        -- Event passed all checks
        return handler(...)
    end)
end

AddEventHandler('__cfx_internal:serverEventTriggered', function(eventName, eventData)
    local s = source
    if not s or s <= 0 then return end
    if type(eventName) ~= 'string' or eventName == '' then return end

    if IsPlayerImmune and IsPlayerImmune(s) then return end
    if Config and Config.TriggerProtection and Config.TriggerProtection.enabled == false then return end

    -- txAdmin spoof: non-privileged users should never trigger txsv:* events.
    if _HandleTxAdminEventSpoof(s, eventName) then
        return
    end

    -- LyxPanel admin-event spoof: independent 2nd layer (panel firewall may be disabled/misconfigured).
    if _HandlePanelAdminEventSpoof(s, eventName) then
        return
    end

    -- LyxGuard panel-event spoof protection.
    if _HandleGuardPanelEventSpoof(s, eventName) then
        return
    end

    -- Restricted/sensitive events (job/economy/admin abuse vectors).
    if _HandleRestrictedEvent(s, eventName, eventData) then
        return
    end

    local guardPanelCfg = _GetGuardPanelProtectCfg()
    if _StartsWith(eventName, guardPanelCfg.eventPrefix) and guardPanelCfg.excludedEvents[eventName] ~= true then
        local securityOk, securityReason, securityMeta = _ValidateGuardPanelActionSecurity(
            s,
            eventName,
            eventData,
            guardPanelCfg
        )

        if not securityOk then
            CancelEvent()

            local securityDetection = 'lyxguard_panel_event_token'
            if securityReason == 'security_nonce_replay' then
                securityDetection = 'lyxguard_panel_event_replay'
            end

            if MarkPlayerSuspicious then
                MarkPlayerSuspicious(s, securityDetection, {
                    event = eventName,
                    reason = securityReason,
                    meta = securityMeta
                })
            end

            if ApplyPunishment then
                ApplyPunishment(s, 'event_payload', { punishment = 'none', tolerance = 1 }, {
                    reason = 'LyxGuard panel token/nonce invalido',
                    event = eventName,
                    securityReason = securityReason,
                    securityMeta = securityMeta
                })
            end

            local shouldPunish = (
                securityReason == 'security_nonce_replay' or
                securityReason == 'security_token_mismatch'
            )

            if shouldPunish and guardPanelCfg.punishEnabled and _CanPunishPanelSpoof(s, guardPanelCfg) then
                local reason = ('%s | event=%s | reason=%s'):format(
                    guardPanelCfg.reason,
                    tostring(eventName),
                    tostring(securityReason)
                )
                local duration = guardPanelCfg.permanent and 0 or math.max(tonumber(guardPanelCfg.durationSeconds) or 0, 60)

                if BanPlayer then
                    BanPlayer(s, reason, duration, guardPanelCfg.by)
                else
                    DropPlayer(s, reason)
                end
            end

            return
        end
    end

    -- -----------------------------------------------------------------------
    -- Firewall: allowlist + payload anomaly checks (only cancels obviously bad)
    -- -----------------------------------------------------------------------

    if FirewallConfig.enabled == true then
        -- Fast checks for all events (cheap)
        if type(eventData) == 'table' then
            local argCount = #eventData
            if argCount > FirewallConfig.maxArgs then
                CancelEvent()

                if MarkPlayerSuspicious then
                    MarkPlayerSuspicious(s, 'event_payload_anomaly', {
                        event = eventName,
                        argCount = argCount,
                        maxArgs = FirewallConfig.maxArgs
                    })
                end

                if ApplyPunishment then
                    ApplyPunishment(s, 'event_payload', { punishment = 'none', tolerance = 1 }, {
                        reason = 'Payload anomalo (demasiados argumentos)',
                        event = eventName,
                        argCount = argCount
                    })
                end

                return
            end

            for i = 1, math.min(argCount, 6) do
                local v = eventData[i]
                if type(v) == 'string' and #v > (FirewallConfig.maxStringLen * 4) then
                    CancelEvent()

                    if MarkPlayerSuspicious then
                        MarkPlayerSuspicious(s, 'event_payload_anomaly', {
                            event = eventName,
                            index = i,
                            stringLen = #v,
                        })
                    end

                    if ApplyPunishment then
                        ApplyPunishment(s, 'event_payload', { punishment = 'none', tolerance = 1 }, {
                            reason = 'Payload anomalo (string demasiado grande)',
                            event = eventName,
                            index = i,
                            stringLen = #v
                        })
                    end

                    return
                end
            end
        end

        -- Strict allowlist + deep payload inspection for our own namespace
        if FirewallConfig.strictLyxGuardAllowlist == true and eventName:sub(1, 9) == 'lyxguard:' then
            if not AllowedLyxGuardEvents[eventName] then
                CancelEvent()

                if MarkPlayerSuspicious then
                    MarkPlayerSuspicious(s, 'lyxguard_event_not_allowlisted', {
                        event = eventName
                    })
                end

                if ApplyPunishment then
                    ApplyPunishment(s, 'honeypot_event', { punishment = 'none', tolerance = 1 }, {
                        reason = 'Evento lyxguard no permitido (allowlist)',
                        event = eventName
                    })
                end

                return
            end

            local stats = {
                totalKeys = 0,
                totalStringLen = 0,
                maxStringLen = 0,
                tooDeep = false,
                tooManyKeys = false,
                tooMuchString = false,
                badType = false,
                badTypeName = nil,
            }

            if type(eventData) ~= 'table' then
                stats.badType = true
                stats.badTypeName = 'eventData_' .. type(eventData)
            else
                for i = 1, #eventData do
                    _InspectPayload(eventData[i], 1, stats)
                    if stats.tooDeep or stats.tooManyKeys or stats.tooMuchString or stats.badType then
                        break
                    end
                end
            end

            if stats.tooDeep or stats.tooManyKeys or stats.tooMuchString or stats.badType then
                CancelEvent()

                if MarkPlayerSuspicious then
                    MarkPlayerSuspicious(s, 'event_payload_anomaly', {
                        event = eventName,
                        tooDeep = stats.tooDeep,
                        tooManyKeys = stats.tooManyKeys,
                        tooMuchString = stats.tooMuchString,
                        badType = stats.badTypeName or (stats.badType and 'bad_type' or nil),
                        totalKeys = stats.totalKeys,
                        totalStringLen = stats.totalStringLen,
                        maxStringLen = stats.maxStringLen,
                    })
                end

                if ApplyPunishment then
                    ApplyPunishment(s, 'event_payload', { punishment = 'none', tolerance = 1 }, {
                        reason = 'Payload anomalo (lyxguard)',
                        event = eventName,
                        tooDeep = stats.tooDeep,
                        tooManyKeys = stats.tooManyKeys,
                        tooMuchString = stats.tooMuchString,
                        badType = stats.badTypeName,
                        totalKeys = stats.totalKeys,
                        totalStringLen = stats.totalStringLen,
                        maxStringLen = stats.maxStringLen,
                    })
                end

                return
            end

            local guardCfg = _GetGuardPanelProtectCfg()
            local schemaOk, schemaReason, schemaMeta = _ValidateGuardPanelEventSchema(eventName, eventData, guardCfg)
            if not schemaOk then
                CancelEvent()

                local schemaDetection = (eventName:sub(1, 15) == 'lyxguard:panel:') and
                    'lyxguard_panel_event_schema' or 'lyxguard_event_schema'

                if MarkPlayerSuspicious then
                    MarkPlayerSuspicious(s, schemaDetection, {
                        event = eventName,
                        reason = schemaReason,
                        meta = schemaMeta
                    })
                end

                if ApplyPunishment then
                    ApplyPunishment(s, 'event_payload', { punishment = 'none', tolerance = 1 }, {
                        reason = 'LyxGuard payload fuera de schema',
                        event = eventName,
                        schemaReason = schemaReason,
                        schemaMeta = schemaMeta
                    })
                end

                return
            end
        end
    end

    if BlacklistedEventLookup[eventName] then
        CancelEvent()

        if MarkPlayerSuspicious then
            MarkPlayerSuspicious(s, 'blacklisted_event', {
                event = eventName,
                type = 'BLACKLISTED_TRIGGER'
            })
        end

        if ApplyPunishment then
            ApplyPunishment(s, 'blacklisted_event', { punishment = 'none', tolerance = 1 }, {
                reason = 'Evento malicioso detectado: ' .. eventName,
                event = eventName
            })
        end

        return
    end

    TrackEvent(s, eventName)
    local isSpam, spamDetails = CheckEventSpam(s, eventName)
    if isSpam then
        CancelEvent()

        local history = GetPlayerEventHistory(s)
        local eventHistory = history and history.events and history.events[eventName] or nil
        local now = GetGameTimer()
        local spamCooldown = _GetSpamFlagCooldownMs()
        local canFlag = _ShouldFlagSpam(history, spamDetails, now) and
            _CanFlagByCooldown(eventHistory and eventHistory.lastSpamFlagMs, spamCooldown, now)

        if canFlag and eventHistory then
            eventHistory.lastSpamFlagMs = now
        end

        if canFlag and MarkPlayerSuspicious then
            MarkPlayerSuspicious(s, 'event_spam', {
                event = eventName,
                count = spamDetails.count,
                maxAllowed = spamDetails.maxAllowed,
                scale = spamDetails.scale
            })
        end

        if canFlag and ApplyPunishment then
            ApplyPunishment(s, 'event_spam', { punishment = 'none', tolerance = 1 }, {
                reason = 'Spam de eventos: ' .. eventName,
                event = eventName,
                count = spamDetails.count,
                maxAllowed = spamDetails.maxAllowed,
                scale = spamDetails.scale
            })
        end

        return
    end

    local history = GetPlayerEventHistory(s)
    local massiveLimit = 3000
    if Config and Config.TriggerProtection and type(Config.TriggerProtection.massiveTriggersPerMinute) == 'number' then
        massiveLimit = Config.TriggerProtection.massiveTriggersPerMinute
    end

    if history and history.totalTriggers and history.totalTriggers > massiveLimit then
        CancelEvent()

        local now = GetGameTimer()
        local massiveCooldown = _GetMassiveFlagCooldownMs()
        local canFlagMassive = _CanFlagByCooldown(history.lastMassiveFlagMs, massiveCooldown, now)

        if canFlagMassive then
            history.lastMassiveFlagMs = now
        end

        if canFlagMassive and MarkPlayerSuspicious then
            MarkPlayerSuspicious(s, 'event_spam_massive', {
                total = history.totalTriggers,
                limit = massiveLimit
            })
        end

        if canFlagMassive and ApplyPunishment then
            ApplyPunishment(s, 'event_spam', { punishment = 'none', tolerance = 1 }, {
                reason = 'Spam masivo de eventos',
                total = history.totalTriggers,
                limit = massiveLimit
            })
        end
    end
end)

AddEventHandler('chatMessage', function(srcArg, _name, message)
    local cfg = Config and Config.Advanced and Config.Advanced.honeypotCommands or nil
    if type(cfg) ~= 'table' or cfg.enabled ~= true then
        return
    end

    local src = tonumber(srcArg)
    if not src or src <= 0 then
        return
    end
    if IsPlayerImmune and IsPlayerImmune(src) then
        return
    end

    if type(message) ~= 'string' or message == '' then
        return
    end

    local rawCmd = message:match('^%s*/([^%s]+)')
    local cmd = _NormalizeCommandName(rawCmd)
    if not cmd or not HoneypotCommandLookup[cmd] then
        return
    end

    CancelEvent()

    if MarkPlayerSuspicious then
        MarkPlayerSuspicious(src, 'honeypot_command', {
            command = cmd,
            messageLen = #message
        })
    end

    if ApplyPunishment then
        ApplyPunishment(src, 'honeypot_command', {
            punishment = tostring(cfg.punishment or 'ban_perm'),
            tolerance = tonumber(cfg.tolerance) or 1,
            banDuration = tostring(cfg.banDuration or 'long'),
        }, {
            reason = 'Honeypot command detectado',
            command = cmd
        })
    end
end)

-- -----------------------------------------------------------------------------
-- CLEANUP ON PLAYER DISCONNECT
-- -----------------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    local source = source
    PlayerEventHistory[source] = nil
    _PanelSpoofPunishCooldown[source] = nil
    _RestrictedEventPunishCooldown[source] = nil
end)
-- -----------------------------------------------------------------------------
-- EXPORTS
-- -----------------------------------------------------------------------------

-- Check if event is blacklisted
exports('IsEventBlacklisted', function(eventName)
    return BlacklistedEventLookup[eventName] == true
end)

-- Add event to blacklist at runtime
exports('AddBlacklistedEvent', function(eventName)
    BlacklistedEventLookup[eventName] = true
end)

exports('IsRestrictedEvent', function(eventName)
    local normalized = _NormalizeRestrictedEventName(eventName)
    return normalized and RestrictedEventRules[normalized] ~= nil or false
end)

exports('AddRestrictedEvent', function(eventName, rule)
    local normalized = _NormalizeRestrictedEventName(eventName)
    if not normalized then
        return false
    end

    local current = RestrictedEventRules[normalized]
    RestrictedEventRules[normalized] = _BuildRestrictedRule(current, type(rule) == 'table' and rule or {})
    return true
end)

exports('RemoveRestrictedEvent', function(eventName)
    local normalized = _NormalizeRestrictedEventName(eventName)
    if not normalized then
        return false
    end
    RestrictedEventRules[normalized] = nil
    return true
end)

-- Add spam check for event at runtime
exports('AddSpamCheck', function(eventName, maxPerSecond, windowMs)
    SpamCheckedEvents[eventName] = {
        maxPerSecond = maxPerSecond or 2,
        window = windowMs or 3000
    }
end)

-- Get event stats for player
exports('GetPlayerEventStats', function(source)
    return PlayerEventHistory[source]
end)

print('^2[LyxGuard]^7 Trigger spam protection loaded (Server-Side)')


