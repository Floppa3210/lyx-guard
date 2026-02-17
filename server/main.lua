--[[
    
                               LYXGUARD v4.0 PROFESSIONAL                         
                                 Server Main Module                                
    
      Author: LyxDev                                                               
      License: Commercial                                                          
      Purpose: Server initialization, player management, and event handling       
    
]]

-- 
-- MODULE INITIALIZATION
-- 

---@class LyxGuardServer
local LyxGuardServer = {}

-- ESX es proporcionado por @es_extended/imports.lua en shared_scripts

-- Private state (encapsulated)
local State = {
    isReady = false,
    bannedPlayers = {}, -- Cache of active bans [identifier] = banData
    playerData = {},    -- Connected player data [source] = playerData
    warnings = {}       -- Cached warnings [identifier] = count
}

-- Heartbeat tracking (client -> server)
local HeartbeatState = {} -- [source] = { last = ms, misses = n }

-- Make State accessible to other modules via exports
PlayerData = State.playerData       -- Legacy compatibility
BannedPlayers = State.bannedPlayers -- Legacy compatibility
Warnings = State.warnings           -- Legacy compatibility

-- 
-- DATABASE INITIALIZATION
-- 

---@private
---@return boolean success
local function InitializeDatabase()
    if LyxGuard and LyxGuard.Migrations and LyxGuard.Migrations.Apply then
        return LyxGuard.Migrations.Apply()
    end

    LyxGuardLib.Error('Migrations module missing - DB init skipped.')
    return false
end

-- 
-- BAN MANAGEMENT
-- 

---Load active bans into memory cache
---@private
function LyxGuardServer.LoadBans()
    MySQL.Async.fetchAll('SELECT * FROM lyxguard_bans WHERE active = 1', {}, function(bans)
        if not bans then
            LyxGuardLib.Warn('No bans loaded (empty table or error)')
            return
        end

        -- Clear cache before reload
        State.bannedPlayers = {}
        BannedPlayers = State.bannedPlayers

        for _, ban in ipairs(bans) do
            local unbanTime = LyxGuardLib.ParseMySQLDate(ban.unban_date)

            local banData = {
                id = ban.id,
                reason = ban.reason or 'No reason provided',
                permanent = ban.permanent == 1,
                unbanTime = unbanTime,
                steam = ban.steam,
                discord = ban.discord,
                license = ban.license,
                fivem = ban.fivem,
                bannedBy = ban.banned_by,
                banDate = LyxGuardLib.ParseMySQLDate(ban.ban_date)
            }

            -- Index by primary identifier
            State.bannedPlayers[ban.identifier] = banData

            -- Also index by secondary identifiers for faster lookups
            if ban.license then State.bannedPlayers[ban.license] = banData end
            if ban.steam then State.bannedPlayers[ban.steam] = banData end
            if ban.discord then State.bannedPlayers[ban.discord] = banData end
            if ban.fivem then State.bannedPlayers[ban.fivem] = banData end
        end

        LyxGuardLib.Info('Loaded %d active bans into cache', #bans)
    end)
end

---Check if a player is banned
---@param identifiers table Player identifiers
---@return boolean isBanned
---@return table|nil banData
function LyxGuardServer.CheckBan(identifiers)
    for idType, identifier in pairs(identifiers) do
        local ban = State.bannedPlayers[identifier]
        if ban then
            -- Check if temporary ban has expired
            if not ban.permanent and ban.unbanTime and ban.unbanTime <= os.time() then
                -- Ban expired, remove from cache
                State.bannedPlayers[identifier] = nil
                return false, nil
            end
            return true, ban
        end
    end
    return false, nil
end

---Unban a player
---@param identifier string Player identifier
---@param unbannerName string Name of admin unbanning
---@return boolean success
function LyxGuardServer.UnbanPlayer(identifier, unbannerName)
    if not identifier or identifier == '' then
        LyxGuardLib.Error('UnbanPlayer: Invalid identifier')
        return false
    end

    unbannerName = LyxGuardLib.Sanitize(unbannerName or 'Unknown', 100)

    MySQL.Async.execute(
        'UPDATE lyxguard_bans SET active = 0, unbanned_by = ? WHERE (identifier = ? OR license = ? OR steam = ?) AND active = 1',
        { unbannerName, identifier, identifier, identifier },
        function(rowsAffected)
            if rowsAffected > 0 then
                -- Remove from cache
                State.bannedPlayers[identifier] = nil
                LyxGuardLib.Info('Player unbanned: %s by %s', identifier, unbannerName)
            end
        end
    )

    return true
end

-- 
-- PLAYER DATA MANAGEMENT
-- 

---Initialize player data on join
---@param source number Player source
function LyxGuardServer.InitPlayerData(source)
    if not source or source <= 0 then return end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        LyxGuardLib.Warn('InitPlayerData: ESX player not found for source %d', source)
        return
    end

    local identifiers = GetAllIdentifiers(source)

    State.playerData[source] = {
        identifier = xPlayer.identifier,
        name = LyxGuardLib.Sanitize(GetPlayerName(source) or 'Unknown', 100),
        group = xPlayer.getGroup(),
        steam = identifiers.steam,
        discord = identifiers.discord,
        license = identifiers.license,
        fivem = identifiers.fivem,
        ip = identifiers.ip,
        immune = IsPlayerImmune(source),
        joinTime = os.time(),
        lastUpdate = os.time()
    }

    LyxGuardLib.Debug('Player initialized: %s (immune: %s)',
        State.playerData[source].name,
        State.playerData[source].immune and 'yes' or 'no'
    )
end

---Get player data from cache
---@param source number
---@return table|nil
function LyxGuardServer.GetPlayerData(source)
    return State.playerData[source]
end

---Clean up player data on disconnect
---@param source number
function LyxGuardServer.CleanupPlayer(source)
    State.playerData[source] = nil
end

-- 
-- DETECTION CONFIG MAPPING
-- 

 local DetectionConfigLookup = nil

 local function _NormalizeDetectionKey(key)
     return tostring(key or ''):gsub('_', ''):lower()
 end

 local function _BuildDetectionConfigLookup()
     local lookup = {}

     local function addTable(tbl)
         if type(tbl) ~= 'table' then return end
         for k, v in pairs(tbl) do
             if type(v) == 'table' then
                 lookup[_NormalizeDetectionKey(k)] = v
             end
         end
     end

     addTable(Config and Config.Movement)
     addTable(Config and Config.Combat)
     addTable(Config and Config.Entities)
     addTable(Config and Config.Advanced)
     addTable(Config and Config.Ultra)

     if Config and Config.Blacklists then
         lookup[_NormalizeDetectionKey('blacklist_weapon')] = Config.Blacklists.weapons
         lookup[_NormalizeDetectionKey('blacklist_vehicle')] = Config.Blacklists.vehicles
         lookup[_NormalizeDetectionKey('blacklist_ped')] = Config.Blacklists.peds
     end

     return lookup
 end

---Get detection configuration
---@param detectionType string
---@return table config
function LyxGuardServer.GetDetectionConfig(detectionType)
    if not DetectionConfigLookup then
        DetectionConfigLookup = _BuildDetectionConfigLookup()
    end

    local cfg = DetectionConfigLookup[_NormalizeDetectionKey(detectionType)]
    return cfg or { enabled = true, punishment = LyxGuardLib.PUNISHMENTS.NOTIFY }
end

-- Global for legacy compatibility
GetDetectionConfig = LyxGuardServer.GetDetectionConfig

-- 
-- EVENT HANDLERS
-- 

-- Connection deferrals are handled by server/connection_security.lua.
-- Keep a single playerConnecting handler to avoid deferral conflicts.

-- ESX player loaded
RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer, isNew)
    local source = playerId or source
    LyxGuardServer.InitPlayerData(source)
end)

-- Player dropped
AddEventHandler('playerDropped', function(reason)
    local source = source
    HeartbeatState[source] = nil
    LyxGuardServer.CleanupPlayer(source)
end)

-- Client heartbeat (anti tamper / module down detection)
RegisterNetEvent('lyxguard:heartbeat', function(payload)
    local src = source
    if not src or src <= 0 then return end

    -- Skip immune players (admins/devs)
    if IsPlayerImmune and IsPlayerImmune(src) then
        return
    end

    HeartbeatState[src] = HeartbeatState[src] or { last = 0, misses = 0 }
    HeartbeatState[src].last = GetGameTimer()
    HeartbeatState[src].misses = 0

    if type(LyxGuardTrackPlayerAction) == 'function' then
        pcall(LyxGuardTrackPlayerAction, src, 'heartbeat_received', {
            payload_type = type(payload)
        }, 'debug', {
            resource = 'lyx-guard',
            event = 'lyxguard:heartbeat',
            result = 'observed',
            throttleKey = ('heartbeat:%s'):format(tostring(src)),
            minIntervalMs = 2000
        })
    end

    if type(payload) ~= 'table' then return end

    local function _SanitizeArr(v, maxItems)
        if type(v) ~= 'table' then return nil end
        local out = {}
        local n = 0
        for _, it in ipairs(v) do
            if n >= (maxItems or 64) then break end
            if type(it) == 'string' then
                local s = it:gsub('%s+', ''):sub(1, 64)
                if s ~= '' then
                    n = n + 1
                    out[n] = s
                end
            end
        end
        return out
    end

    local hb = HeartbeatState[src]
    hb.client = hb.client or {}
    hb.client.ver = tostring(payload.ver or '')
    hb.client.det = tonumber(payload.detections or 0) or 0
    hb.client.prot = tonumber(payload.protections or 0) or 0
    hb.client.detHash = tonumber(payload.detHash or 0) or 0
    hb.client.protHash = tonumber(payload.protHash or 0) or 0
    hb.client.detNames = _SanitizeArr(payload.detNames, 96)
    hb.client.protNames = _SanitizeArr(payload.protNames, 96)
    hb.client.lastPayload = GetGameTimer()
    HeartbeatState[src] = hb

    -- Optional module integrity checks (best-effort, don't hard fail based on client data alone).
    local cfg = Config and Config.Advanced and Config.Advanced.heartbeat or nil
    if cfg and cfg.enabled == true then
        local pd = State.playerData[src]
        local graceSeconds = tonumber(cfg.graceSeconds) or 30
        if pd and pd.joinTime and (os.time() - pd.joinTime) >= graceSeconds then
            local nowMs = GetGameTimer()
            local flagCooldownMs = tonumber(cfg.integrityFlagCooldownMs) or 60000
            local minDet = tonumber(cfg.minDetections) or 0
            local minProt = tonumber(cfg.minProtections) or 0

            if (minDet > 0 and hb.client.det < minDet) or (minProt > 0 and hb.client.prot < minProt) then
                local lastFlag = tonumber(hb._lastModulesLowFlagMs) or 0
                if flagCooldownMs <= 0 or (nowMs - lastFlag) >= flagCooldownMs then
                    hb._lastModulesLowFlagMs = nowMs
                    HeartbeatState[src] = hb

                    if MarkPlayerSuspicious then
                        MarkPlayerSuspicious(src, 'modules_low', {
                            det = hb.client.det,
                            prot = hb.client.prot,
                            minDet = minDet,
                            minProt = minProt
                        })
                    end
                end
            end

            local function _Missing(required, have)
                if type(required) ~= 'table' or #required == 0 then return nil end
                if type(have) ~= 'table' or #have == 0 then return { '_no_list' } end
                local lookup = {}
                for _, n in ipairs(have) do lookup[n] = true end
                local miss = {}
                for _, r in ipairs(required) do
                    r = tostring(r or ''):gsub('%s+', '')
                    if r ~= '' and not lookup[r] then
                        miss[#miss + 1] = r
                    end
                end
                return (#miss > 0) and miss or nil
            end

            local missDet = _Missing(cfg.requiredDetections, hb.client.detNames)
            local missProt = _Missing(cfg.requiredProtections, hb.client.protNames)
            if (missDet and #missDet > 0) or (missProt and #missProt > 0) then
                local lastFlag = tonumber(hb._lastModulesMissingFlagMs) or 0
                if flagCooldownMs <= 0 or (nowMs - lastFlag) >= flagCooldownMs then
                    hb._lastModulesMissingFlagMs = nowMs
                    HeartbeatState[src] = hb

                    if MarkPlayerSuspicious then
                        MarkPlayerSuspicious(src, 'modules_missing', {
                            missingDetections = missDet,
                            missingProtections = missProt
                        })
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        local cfg = Config and Config.Advanced and Config.Advanced.heartbeat or nil
        local enabled = cfg and cfg.enabled == true
        local interval = tonumber(cfg and cfg.intervalMs) or 10000

        Wait(interval)

        if not enabled then
            goto continue
        end

        local timeoutMs = tonumber(cfg.timeoutMs) or 30000
        local graceSeconds = tonumber(cfg.graceSeconds) or 30
        local tolerance = tonumber(cfg.tolerance) or 3

        for _, pid in ipairs(GetPlayers()) do
            local psrc = tonumber(pid)
            if psrc and psrc > 0 and GetPlayerName(psrc) then
                if IsPlayerImmune and IsPlayerImmune(psrc) then
                    goto next_player
                end

                local pd = State.playerData[psrc]
                if pd and pd.joinTime and (os.time() - pd.joinTime) < graceSeconds then
                    goto next_player
                end

                local hb = HeartbeatState[psrc]
                local last = hb and hb.last or 0
                if last == 0 or (GetGameTimer() - last) > timeoutMs then
                    hb = hb or { last = last, misses = 0 }
                    hb.misses = (hb.misses or 0) + 1
                    HeartbeatState[psrc] = hb

                    if hb.misses >= tolerance then
                        -- Only flag once per threshold (avoid 3 instant strikes due to a single outage).
                        if MarkPlayerSuspicious then
                            MarkPlayerSuspicious(psrc, 'heartbeat_missing', {
                                misses = hb.misses,
                                tolerance = tolerance,
                                timeoutMs = timeoutMs
                            })
                        end

                        if ApplyPunishment then
                            ApplyPunishment(psrc, 'heartbeat', cfg, {
                                reason = 'Heartbeat ausente (posible tampering / anticheat detenido)',
                                misses = hb.misses,
                                timeoutMs = timeoutMs
                            }, nil)
                        end
                        hb.misses = 0
                        HeartbeatState[psrc] = hb
                    end
                end
            end
            ::next_player::
        end

        ::continue::
    end
end)

-- Detection event with security validation
local _IgnoredLogCooldowns = {}

local function _IsIgnoredLogRateLimited(src, key, cooldownMs)
    if not src or src <= 0 then return true end

    local now = GetGameTimer()
    _IgnoredLogCooldowns[src] = _IgnoredLogCooldowns[src] or {}
    local last = _IgnoredLogCooldowns[src][key] or 0
    if (now - last) < (cooldownMs or 0) then
        return true
    end
    _IgnoredLogCooldowns[src][key] = now
    return false
end

local function _LogIgnoredDetection(src, detectionType, details, coords, level, why)
    local logCfg = Config and Config.Permissions and Config.Permissions.logging or nil
    if not logCfg then return end

    local shouldLog = false
    local shouldWebhook = false
    if level == 'full' then
        shouldLog = logCfg.logImmuneDetections == true
        shouldWebhook = logCfg.sendWebhookForImmune == true
    elseif level == 'vip' then
        shouldLog = logCfg.logVipDetections == true
        shouldWebhook = logCfg.sendWebhookForVip == true
    end

    if not shouldLog and not shouldWebhook then
        return
    end

    local key = tostring(detectionType or 'unknown')
    if _IsIgnoredLogRateLimited(src, key, 10000) then
        return
    end

    local playerName = GetPlayerName(src) or 'Unknown'
    local ids = GetAllIdentifiers(src)
    local identifier = ids.license or ids.steam or ids.discord or ids.fivem or 'unknown'

    local coordsStr = nil
    if coords and coords.x then
        coordsStr = string.format('%.2f,%.2f,%.2f', coords.x or 0, coords.y or 0, coords.z or 0)
    end

    local payload = {
        ignored = true,
        level = level,
        why = why,
        detectionType = detectionType,
        details = details
    }

    local detailsJson = nil
    local ok, enc = pcall(json.encode, payload)
    if ok then
        detailsJson = enc
    end

    if shouldLog and MySQL and MySQL.Async and MySQL.Async.execute then
        MySQL.Async.execute([[
            INSERT INTO lyxguard_detections
            (player_name, identifier, steam, discord, detection_type, details, coords, punishment)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            playerName,
            identifier,
            ids.steam,
            ids.discord,
            tostring(detectionType),
            detailsJson,
            coordsStr,
            'ignored'
        })
    end

    if shouldWebhook and SendDiscordDetection then
        pcall(SendDiscordDetection, src, tostring(detectionType), payload, coords, 'ignored')
    end
end

RegisterNetEvent('lyxguard:detection', function(detectionType, details, coords)
    local source = source

    -- Security: Validate source
    if not source or source <= 0 then return end

    -- Security: Validate payload types (clients can send arbitrary garbage)
    if type(detectionType) ~= 'string' or detectionType == '' then
        return
    end

    if details ~= nil and type(details) ~= 'table' then
        -- Legacy/bad callers may send strings/numbers; wrap to keep logging stable.
        details = { legacy = tostring(details) }
    end

    if coords ~= nil and type(coords) ~= 'table' then
        coords = nil
    end

    if coords and (type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number') then
        coords = nil
    end

    -- Defensive sanitization of details to avoid JSON explosions / crashes.
    local function _SanitizeTable(v, depth, out, stats)
        if stats.truncated then return end
        if depth > 6 then
            stats.truncated = true
            return
        end

        local count = 0
        for k, val in pairs(v) do
            count = count + 1
            stats.keys = stats.keys + 1
            if count > 64 or stats.keys > 256 then
                stats.truncated = true
                break
            end

            local kt = type(k)
            if kt ~= 'string' and kt ~= 'number' then
                -- Skip weird keys.
            else
                local t = type(val)
                if t == 'string' then
                    if #val > 512 then
                        out[k] = val:sub(1, 512)
                        stats.truncated = true
                    else
                        out[k] = val
                    end
                elseif t == 'number' or t == 'boolean' or t == 'nil' then
                    out[k] = val
                elseif t == 'table' then
                    out[k] = {}
                    _SanitizeTable(val, depth + 1, out[k], stats)
                else
                    -- function/userdata/thread: drop
                    stats.truncated = true
                end
            end

            if stats.truncated then
                -- Keep iterating a bit to capture more context? No, stop.
                break
            end
        end
    end

    if details then
        local clean = {}
        local stats = { keys = 0, truncated = false }
        _SanitizeTable(details, 1, clean, stats)
        if stats.truncated then
            clean._sanitized = true
        end
        details = clean
    end

    -- GLOBAL ADMIN BYPASS (Hardcoded safety)
    if IsPlayerAceAllowed(source, 'lyxguard.bypass') then
        return
    end

    local playerName = GetPlayerName(source)
    if not playerName then
        LyxGuardLib.Debug('Detection ignored: Player not found')
        return
    end

    -- Skip completely for immune players (admins)
    if IsPlayerImmune(source) then
        if LyxGuardLib.IsValidDetection(detectionType) then
            _LogIgnoredDetection(source, detectionType, details, coords, 'full', 'immune')
        end
        LyxGuardLib.Debug('Detection ignored: Player %s is immune', playerName)
        return
    end

    -- Security: Validate detection type
    if not LyxGuardLib.IsValidDetection(detectionType) then
        LyxGuardLib.Warn('Invalid detection type from %s: %s', playerName, tostring(detectionType))
        return
    end

    -- Safe-state: allow short immunity windows for legitimate admin/panel actions (teleport/heal/entity spawn).
    local function _IsSafe(key)
        if not key then return false end
        if type(IsPlayerSafe) == 'function' then
            return IsPlayerSafe(source, key) == true
        end
        local ok, res = pcall(function()
            return exports['lyx-guard']:IsPlayerSafe(source, key)
        end)
        return ok and res == true
    end

    do
        local safeKey = nil
        local dt = detectionType:lower()
        if dt:find('entity', 1, true) then
            safeKey = 'entity'
        elseif dt:find('explosion', 1, true) then
            safeKey = 'explosion'
        elseif dt:find('weapon', 1, true) or dt:find('bullet', 1, true) then
            safeKey = 'weapon'
        elseif dt:find('resource', 1, true) or dt:find('inject', 1, true) then
            safeKey = 'resource'
        elseif dt:find('teleport', 1, true) or dt:find('noclip', 1, true) or dt:find('speed', 1, true) or dt:find('fly', 1, true) then
            safeKey = 'movement'
        elseif dt:find('health', 1, true) or dt:find('armor', 1, true) or dt:find('revive', 1, true) then
            safeKey = 'health'
        end

        if _IsSafe('all') or _IsSafe(detectionType) or _IsSafe(safeKey) then
            _LogIgnoredDetection(source, detectionType, details, coords, 'safe', safeKey or detectionType)
            return
        end
    end

    -- Permission system: VIPs may ignore some detections; DB whitelist is cached in utils.lua.
    if ShouldDetect then
        local shouldDetect = ShouldDetect(source, detectionType)
        if not shouldDetect then
            local level = 'none'
            if GetPlayerPermissionLevel then
                level = GetPlayerPermissionLevel(source)
            end
            if level == 'vip' or level == 'full' then
                _LogIgnoredDetection(source, detectionType, details, coords, level, 'permission')
            end
            return
        end
    end

    -- Get detection config and apply punishment
    local config = LyxGuardServer.GetDetectionConfig(detectionType)
    if config and config.enabled ~= false then
        ApplyPunishment(source, detectionType, config, details, coords)
    end
end)

-- 
-- SERVER CALLBACKS
-- 

ESX.RegisterServerCallback('lyxguard:checkImmunity', function(source, cb)
    cb(IsPlayerImmune(source))
end)

ESX.RegisterServerCallback('lyxguard:getConfig', function(source, cb)
    cb({
        debug = Config.Debug or false,
        movement = Config.Movement or {},
        combat = Config.Combat or {},
        entities = Config.Entities or {},
        blacklists = Config.Blacklists or {},
        advanced = Config.Advanced or {}
    })
end)

-- 
-- INTERNAL EVENTS (Server-Only)
-- 

AddEventHandler('lyxguard:reloadBans', function()
    LyxGuardServer.LoadBans()
    LyxGuardLib.Info('Ban cache reloaded')
end)

-- Console command for reload
RegisterCommand('lyxguard_reload', function(source, args)
    if source ~= 0 then
        LyxGuardLib.Warn('lyxguard_reload can only be used from server console')
        return
    end
    LyxGuardServer.LoadBans()
    LyxGuardLib.Info('Bans reloaded from console')
end, true)

-- 
-- PUBLIC API (Exports)
-- 

function UnbanPlayer(identifier, unbannerName)
    return LyxGuardServer.UnbanPlayer(identifier, unbannerName)
end

function GetPlayerWarnings(identifier)
    if not identifier then return {} end
    return MySQL.Sync.fetchAll(
        'SELECT * FROM lyxguard_warnings WHERE identifier = ? AND active = 1 ORDER BY warn_date DESC',
        { identifier }
    ) or {}
end

-- Make available to other server scripts
function InitPlayerData(source)
    return LyxGuardServer.InitPlayerData(source)
end

-- Exports
exports('UnbanPlayer', UnbanPlayer)
exports('GetPlayerWarnings', GetPlayerWarnings)
exports('GetPlayerData', function(source) return LyxGuardServer.GetPlayerData(source) end)
exports('IsServerReady', function() return State.isReady end)
exports('GetHeartbeatState', function(source)
    source = tonumber(source)
    if not source or source <= 0 then return nil end
    local hb = HeartbeatState[source]
    if not hb then return nil end
    local now = GetGameTimer()
    return {
        last = hb.last,
        misses = hb.misses,
        ageMs = (hb.last and (now - hb.last)) or nil
    }
end)

-- 
-- INITIALIZATION
-- 

MySQL.ready(function()
    LyxGuardLib.Info('Initializing LyxGuard v%s...', LyxGuardLib.VERSION)

    -- Initialize database tables
    local dbSuccess = InitializeDatabase()
    if not dbSuccess then
        LyxGuardLib.Error('Database initialization failed (migrations). Check oxmysql/MySQL permissions.')
    end

    -- Load active bans
    LyxGuardServer.LoadBans()

    -- Initialize structured logger (v2.1)
    if StructuredLogger and StructuredLogger.Init then
        StructuredLogger.Init({
            enabled = true,
            minLevel = Config.Debug and 1 or 2, -- DEBUG if debug mode, else INFO
            discordWebhook = Config.Discord and Config.Discord.webhooks and Config.Discord.webhooks.detections
        })
        LyxGuardLib.Info('Structured Logger v2.1 initialized')
    end

    -- Initialize existing players (important for script reload)
    CreateThread(function()
        Wait(2000) -- Wait for ESX to be ready
        local players = GetPlayers()
        for _, playerId in ipairs(players) do
            local src = tonumber(playerId)
            if src and src > 0 and not State.playerData[src] then
                LyxGuardLib.Debug('Initializing existing player: %s', GetPlayerName(src) or 'Unknown')
                LyxGuardServer.InitPlayerData(src)
            end
        end
    end)

    -- Mark as ready
    State.isReady = true

    LyxGuardLib.Info('LyxGuard v%s loaded successfully', LyxGuardLib.VERSION)
end)

return LyxGuardServer


