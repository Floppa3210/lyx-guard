--[[
    LyxGuard - Enhanced Ban System
    Supports HWID/Token bans, Player Cache for offline bans
    Based on vAdmin ban system + FIREAC
]]

local BanSystem = {}

-- Player cache for offline bans (stores recently disconnected players)
local PlayerCache = {}
local CACHE_EXPIRY = 86400 -- 24 hours in seconds
local MAX_CACHE_SIZE = 500

local _FNV32_PRIME = 16777619
local _FNV32_OFFSET = 2166136261
local _U32_MOD = 4294967296

local function _GetHardeningCfg()
    local cfg = Config and Config.BanHardening or {}
    return {
        enableTokenHashes = cfg.enableTokenHashes ~= false,
        enableIdentifierFingerprint = cfg.enableIdentifierFingerprint ~= false,
        tokenHashScanLimit = math.max(tonumber(cfg.tokenHashScanLimit) or 3000, 200),
        legacyTokenLikeFallback = cfg.legacyTokenLikeFallback ~= false,
    }
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

local function _NormalizeIdentifier(v)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('^%s+', ''):gsub('%s+$', '')
    if v == '' then return nil end
    return v:lower()
end

local function _NormalizeToken(v)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('%s+', '')
    if v == '' then return nil end
    return v
end

local function _BuildTokenHashes(tokens)
    local out = {}
    local seen = {}
    if type(tokens) ~= 'table' then return out end

    for _, token in ipairs(tokens) do
        local norm = _NormalizeToken(token)
        if norm then
            local h = _HashFNV1a(norm)
            if not seen[h] then
                seen[h] = true
                out[#out + 1] = h
            end
        end
    end

    table.sort(out)
    return out
end

local function _BuildIdentifierFingerprint(identifiers, tokenHashes)
    if type(identifiers) ~= 'table' then return nil end

    local fields = {
        _NormalizeIdentifier(identifiers.license),
        _NormalizeIdentifier(identifiers.steam),
        _NormalizeIdentifier(identifiers.discord),
        _NormalizeIdentifier(identifiers.fivem),
    }

    local parts = {}
    for _, f in ipairs(fields) do
        if f then parts[#parts + 1] = f end
    end

    if type(tokenHashes) == 'table' then
        local maxTokens = math.min(#tokenHashes, 6)
        for i = 1, maxTokens do
            parts[#parts + 1] = tostring(tokenHashes[i])
        end
    end

    if #parts == 0 then
        return nil
    end

    local seed = table.concat(parts, '|')
    return _HashFNV1a(seed .. '|lyxguard_fp_v2_a') .. _HashFNV1a(seed .. '|lyxguard_fp_v2_b')
end

local function _IsBanExpired(ban)
    if not ban then return false end
    if ban.permanent == 1 or ban.permanent == true then return false end
    if not ban.unban_date then return false end

    local unbanTime = LyxGuardLib and LyxGuardLib.ParseMySQLDate and LyxGuardLib.ParseMySQLDate(ban.unban_date) or nil
    if unbanTime and unbanTime <= os.time() then
        return true
    end
    return false
end

local function _TryDeactivateExpiredBan(ban)
    if not ban or not ban.id then return end
    MySQL.Async.execute('UPDATE lyxguard_bans SET active = 0 WHERE id = ?', { ban.id })
end

local function _HasTokenHashMatch(candidateJson, lookup)
    if type(candidateJson) ~= 'string' or candidateJson == '' then return false end
    if type(lookup) ~= 'table' then return false end

    local ok, parsed = pcall(json.decode, candidateJson)
    if not ok or type(parsed) ~= 'table' then
        return false
    end

    for _, h in ipairs(parsed) do
        local key = tostring(h or '')
        if key ~= '' and lookup[key] then
            return true
        end
    end
    return false
end

-- 
-- DATABASE INITIALIZATION
-- 

function BanSystem.InitDatabase()
    -- DB schema is managed by versioned migrations (server/migrations.lua).
    -- Keep this function for backwards compatibility, but never run ad-hoc ALTERs.
    if LyxGuard and LyxGuard.Migrations and LyxGuard.Migrations.Apply then
        return LyxGuard.Migrations.Apply()
    end

    print('^3[LyxGuard]^7 BanSystem.InitDatabase: migrations module missing, skipping DB init')
    return false
end

-- 
-- TOKEN/HWID MANAGEMENT
-- 

--- Get all tokens for a player
---@param source number
---@return table tokens
function BanSystem.GetPlayerTokens(source)
    local tokens = {}
    local numTokens = GetNumPlayerTokens(source)
    
    for i = 0, numTokens - 1 do
        local token = GetPlayerToken(source, i)
        if token then
            table.insert(tokens, token)
        end
    end
    
    return tokens
end

--- Get all identifiers for a player
---@param source number
---@return table identifiers
function BanSystem.GetPlayerIdentifiers(source)
    local identifiers = {}
    local numIds = GetNumPlayerIdentifiers(source)
    
    for i = 0, numIds - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id then
            local idType = id:match("^(%w+):")
            if idType then
                identifiers[idType] = id
            end
        end
    end
    
    return identifiers
end

-- 
-- PLAYER CACHE (for offline bans)
-- 

--- Add player to cache on join/update
---@param source number
function BanSystem.CachePlayer(source)
    local name = GetPlayerName(source)
    if not name then return end
    
    local identifiers = BanSystem.GetPlayerIdentifiers(source)
    local tokens = BanSystem.GetPlayerTokens(source)
    local license = identifiers.license or identifiers.fivem or 'unknown'
    
    local playerData = {
        name = name,
        identifiers = identifiers,
        tokens = tokens,
        lastSeen = os.time(),
        source = source
    }
    
    PlayerCache[license] = playerData
    
    -- Also save to database
    MySQL.Async.execute([[
        INSERT INTO lyxguard_player_cache 
        (identifier, player_name, steam, discord, license, fivem, ip, tokens, last_seen)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
        player_name = VALUES(player_name),
        steam = VALUES(steam),
        discord = VALUES(discord),
        fivem = VALUES(fivem),
        ip = VALUES(ip),
        tokens = VALUES(tokens),
        last_seen = NOW()
    ]], {
        license,
        name,
        identifiers.steam,
        identifiers.discord,
        identifiers.license,
        identifiers.fivem,
        identifiers.ip,
        json.encode(tokens)
    })
    
    -- Prune old cache entries
    BanSystem.PruneCache()
end

--- Get player from cache by name or identifier
---@param search string
---@return table|nil playerData
function BanSystem.GetCachedPlayer(search)
    -- Check memory cache first
    for _, data in pairs(PlayerCache) do
        if data.name and data.name:lower():find(search:lower()) then
            return data
        end
        for _, id in pairs(data.identifiers or {}) do
            if id:lower():find(search:lower()) then
                return data
            end
        end
    end
    
    -- Check database
    local result = MySQL.Sync.fetchAll([[
        SELECT * FROM lyxguard_player_cache 
        WHERE player_name LIKE ? OR identifier LIKE ? OR license LIKE ? OR steam LIKE ?
        ORDER BY last_seen DESC LIMIT 1
    ]], {
        '%' .. search .. '%',
        '%' .. search .. '%',
        '%' .. search .. '%',
        '%' .. search .. '%'
    })
    
    if result and result[1] then
        local row = result[1]
        return {
            name = row.player_name,
            identifiers = {
                license = row.license,
                steam = row.steam,
                discord = row.discord,
                fivem = row.fivem,
                ip = row.ip
            },
            tokens = row.tokens and json.decode(row.tokens) or {},
            lastSeen = row.last_seen
        }
    end
    
    return nil
end

--- Get all cached players (for list display)
---@param limit number
---@return table players
function BanSystem.GetAllCachedPlayers(limit)
    limit = limit or 100
    
    local result = MySQL.Sync.fetchAll([[
        SELECT * FROM lyxguard_player_cache 
        ORDER BY last_seen DESC LIMIT ?
    ]], { limit })
    
    local players = {}
    for _, row in ipairs(result or {}) do
        table.insert(players, {
            name = row.player_name,
            identifier = row.identifier,
            identifiers = {
                license = row.license,
                steam = row.steam,
                discord = row.discord,
                fivem = row.fivem
            },
            tokens = row.tokens and json.decode(row.tokens) or {},
            lastSeen = row.last_seen
        })
    end
    
    return players
end

--- Prune expired cache entries
function BanSystem.PruneCache()
    local now = os.time()
    local expiredKeys = {}
    
    for key, data in pairs(PlayerCache) do
        if data.lastSeen and (now - data.lastSeen) > CACHE_EXPIRY then
            table.insert(expiredKeys, key)
        end
    end
    
    for _, key in ipairs(expiredKeys) do
        PlayerCache[key] = nil
    end
    
    -- Also prune database (keep last 30 days)
    MySQL.Async.execute([[
        DELETE FROM lyxguard_player_cache 
        WHERE last_seen < DATE_SUB(NOW(), INTERVAL 30 DAY)
    ]], {})
end

-- 
-- ENHANCED BAN SYSTEM
-- 

--- Generate unique ban ID
---@return string banId
local function GenerateBanId()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local id = ""
    for i = 1, 8 do
        local r = math.random(1, #chars)
        id = id .. chars:sub(r, r)
    end
    return id
end

--- Ban a player with full HWID support
---@param data table Ban data
---@return boolean success
---@return string|nil banId
function BanSystem.BanPlayer(data)
    if not data.identifier then
        return false, nil
    end
    
    local banId = GenerateBanId()
    local unbanDate = nil
    local permanent = true
    
    -- Calculate unban date if not permanent
    if data.duration and data.duration > 0 then
        unbanDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + data.duration)
        permanent = false
    end
    
    -- Prepare token tracking data
    local tokensJson = nil
    if data.tokens and #data.tokens > 0 then
        tokensJson = json.encode(data.tokens)
    end

    local hardening = _GetHardeningCfg()
    local tokenHashes = hardening.enableTokenHashes and _BuildTokenHashes(data.tokens or {}) or {}
    local tokenHashesJson = (hardening.enableTokenHashes and #tokenHashes > 0) and json.encode(tokenHashes) or nil
    local identifierFingerprint = nil
    if hardening.enableIdentifierFingerprint then
        identifierFingerprint = data.identifierFingerprint or _BuildIdentifierFingerprint({
            license = data.license or data.identifier,
            steam = data.steam,
            discord = data.discord,
            fivem = data.fivem
        }, tokenHashes)
    end
    if not hardening.enableIdentifierFingerprint then
        identifierFingerprint = nil
    end
    
    MySQL.Async.execute([[
        INSERT INTO lyxguard_bans 
        (identifier, steam, discord, license, fivem, ip, tokens, token_hashes, identifier_fingerprint, player_name, reason, 
         ban_date, unban_date, permanent, banned_by, active)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?, ?, ?, 1)
    ]], {
        data.identifier,
        data.steam,
        data.discord,
        data.license,
        data.fivem,
        data.ip,
        tokensJson,
        tokenHashesJson,
        identifierFingerprint,
        data.playerName or 'Unknown',
        data.reason or 'No reason provided',
        unbanDate,
        permanent and 1 or 0,
        data.bannedBy or 'LyxGuard'
    })
    
    -- Drop player if online
    if data.source then
        DropPlayer(data.source, ([[
BANEADO

Razon: %s
Ban ID: %s
Duracion: %s

Apelacion: Discord del servidor
        ]]):format(
            data.reason or 'No reason',
            banId,
            permanent and 'Permanente' or (data.durationText or 'Temporal')
        ))
    end
    
    -- Log to webhook
    if Config and Config.Webhooks and Config.Webhooks.bans then
        TriggerEvent('lyxguard:sendWebhook', 'bans', {
            title = 'Jugador Baneado',
            color = 16711680, -- Red
            fields = {
                { name = 'Jugador', value = data.playerName or 'Unknown', inline = true },
                { name = 'Ban ID', value = banId, inline = true },
                { name = 'Razon', value = data.reason or 'No reason', inline = false },
                { name = 'Baneado por', value = data.bannedBy or 'LyxGuard', inline = true },
                { name = 'Duracion', value = permanent and 'Permanente' or (data.durationText or 'Temporal'), inline = true },
                { name = 'License', value = data.license or 'N/A', inline = false },
                { name = 'Steam', value = data.steam or 'N/A', inline = true },
                { name = 'Discord', value = data.discord or 'N/A', inline = true },
                { name = 'Tokens (HWID)', value = tokensJson and ('```%d tokens```'):format(type(data.tokens) == 'table' and #data.tokens or 0) or 'N/A', inline = false },
                { name = 'Token Hashes', value = tokenHashesJson and ('```%d hashes```'):format(#tokenHashes) or 'N/A', inline = false },
                { name = 'Fingerprint', value = identifierFingerprint or 'N/A', inline = false }
            }
        })
    end
    
    return true, banId
end

--- Offline ban a player (from cache)
---@param search string Player name or identifier to search
---@param reason string Ban reason
---@param duration number Duration in seconds (0 = permanent)
---@param adminSource number Admin who issued the ban
---@return boolean success
---@return string|nil message
function BanSystem.OfflineBan(search, reason, duration, adminSource)
    local cachedPlayer = BanSystem.GetCachedPlayer(search)
    
    if not cachedPlayer then
        return false, 'Jugador no encontrado en cache'
    end
    
    local adminName = 'Console'
    if adminSource and adminSource > 0 then
        adminName = GetPlayerName(adminSource) or 'Admin'
    end
    
    local success, banId = BanSystem.BanPlayer({
        identifier = cachedPlayer.identifiers.license or cachedPlayer.identifiers.fivem,
        steam = cachedPlayer.identifiers.steam,
        discord = cachedPlayer.identifiers.discord,
        license = cachedPlayer.identifiers.license,
        fivem = cachedPlayer.identifiers.fivem,
        ip = cachedPlayer.identifiers.ip,
        tokens = cachedPlayer.tokens,
        playerName = cachedPlayer.name,
        reason = reason,
        duration = duration,
        durationText = duration > 0 and ('%d dias'):format(duration / 86400) or nil,
        bannedBy = adminName
    })
    
    if success then
        return true, ('Jugador %s baneado offline. Ban ID: %s'):format(cachedPlayer.name, banId)
    else
        return false, 'Error al banear jugador'
    end
end

--- Check if player is banned (including token check)
---@param source number
---@return boolean isBanned
---@return table|nil banData
function BanSystem.CheckPlayerBan(source)
    local hardening = _GetHardeningCfg()
    local identifiers = BanSystem.GetPlayerIdentifiers(source)
    local tokens = BanSystem.GetPlayerTokens(source)
    local tokenHashes = hardening.enableTokenHashes and _BuildTokenHashes(tokens) or {}
    local tokenHashLookup = {}
    for _, h in ipairs(tokenHashes) do
        tokenHashLookup[h] = true
    end
    local identifierFingerprint = nil
    if hardening.enableIdentifierFingerprint then
        identifierFingerprint = _BuildIdentifierFingerprint(identifiers, tokenHashes)
    end
    
    -- Check by direct identifiers + fingerprint
    local result = MySQL.Sync.fetchAll([[
        SELECT * FROM lyxguard_bans 
        WHERE active = 1 AND (
            identifier = ? OR license = ? OR steam = ? OR discord = ? OR fivem = ?
            OR (identifier_fingerprint IS NOT NULL AND identifier_fingerprint = ?)
        )
        ORDER BY id DESC
        LIMIT 1
    ]], {
        identifiers.license or '',
        identifiers.license or '',
        identifiers.steam or '',
        identifiers.discord or '',
        identifiers.fivem or '',
        identifierFingerprint or ''
    })
    
    if result and result[1] then
        local ban = result[1]
        
        if _IsBanExpired(ban) then
            _TryDeactivateExpiredBan(ban)
            return false, nil
        end
        
        return true, ban
    end
    
    -- Check by token hashes (exact, deterministic; preferred over raw token LIKE)
    if hardening.enableTokenHashes and #tokenHashes > 0 then
        local tokenHashJson = json.encode(tokenHashes)
        local tokenResult = nil

        -- MySQL 8+ fast path
        local overlapsOk = pcall(function()
            tokenResult = MySQL.Sync.fetchAll([[
                SELECT * FROM lyxguard_bans
                WHERE active = 1 AND token_hashes IS NOT NULL
                  AND JSON_OVERLAPS(token_hashes, CAST(? AS JSON))
                ORDER BY id DESC
                LIMIT 1
            ]], { tokenHashJson })
        end)

        if overlapsOk and tokenResult and tokenResult[1] then
            local ban = tokenResult[1]
            if _IsBanExpired(ban) then
                _TryDeactivateExpiredBan(ban)
                return false, nil
            end
            return true, ban
        end

        -- Fallback for MariaDB / MySQL variants without JSON_OVERLAPS.
        local hashRows = MySQL.Sync.fetchAll([[
            SELECT * FROM lyxguard_bans
            WHERE active = 1 AND token_hashes IS NOT NULL
            ORDER BY id DESC
            LIMIT ?
        ]], { hardening.tokenHashScanLimit })

        for _, row in ipairs(hashRows or {}) do
            if _HasTokenHashMatch(row.token_hashes, tokenHashLookup) then
                if _IsBanExpired(row) then
                    _TryDeactivateExpiredBan(row)
                    return false, nil
                end
                return true, row
            end
        end
    end

    -- Legacy fallback: raw token LIKE for pre-v2 bans (kept for backwards compatibility).
    if hardening.legacyTokenLikeFallback and #tokens > 0 then
        for _, token in ipairs(tokens) do
            local tokenResult = MySQL.Sync.fetchAll([[
                SELECT * FROM lyxguard_bans 
                WHERE active = 1 AND tokens LIKE ?
                ORDER BY id DESC
                LIMIT 1
            ]], { '%' .. token .. '%' })

            if tokenResult and tokenResult[1] then
                local ban = tokenResult[1]
                if _IsBanExpired(ban) then
                    _TryDeactivateExpiredBan(ban)
                    return false, nil
                end
                return true, ban
            end
        end
    end
    
    return false, nil
end

-- 
-- EVENT HANDLERS
-- 

-- Cache player on load
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(source)
    BanSystem.CachePlayer(source)
end)

-- Update cache on disconnect
AddEventHandler('playerDropped', function(reason)
    local source = source
    BanSystem.CachePlayer(source)
end)

-- Initialize on resource start
MySQL.ready(function()
    BanSystem.InitDatabase()
    print('^2[LyxGuard]^7 Enhanced Ban System with HWID support initialized')
end)

-- Export functions
exports('BanPlayer', BanSystem.BanPlayer)
exports('OfflineBan', BanSystem.OfflineBan)
exports('GetCachedPlayer', BanSystem.GetCachedPlayer)
exports('GetAllCachedPlayers', BanSystem.GetAllCachedPlayers)
exports('CheckPlayerBan', BanSystem.CheckPlayerBan)
exports('GetPlayerTokens', BanSystem.GetPlayerTokens)

return BanSystem


