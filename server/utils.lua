--[[
    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║                           LYXGUARD v4.0 PROFESSIONAL                         ║
    ║                            Server Utilities                                   ║
    ╠═══════════════════════════════════════════════════════════════════════════════╣
    ║  Author: LyxDev                                                               ║
    ║  License: Commercial                                                          ║
    ║  Purpose: Shared utility functions for server-side operations                ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- IDENTIFIER MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════════

---Get specific identifier type for a player
---@param source number Player source
---@param idType string Identifier type (license, steam, discord, fivem, ip)
---@return string|nil
function GetIdentifier(source, idType)
    if not source or source <= 0 then return nil end
    if not idType or type(idType) ~= 'string' then return nil end

    local identifiers = GetPlayerIdentifiers(source)
    if not identifiers then return nil end

    local prefix = idType .. ':'
    for _, id in ipairs(identifiers) do
        if string.sub(id, 1, #prefix) == prefix then
            return id
        end
    end

    return nil
end

---Get all identifiers for a player
---@param source number Player source
---@return table
function GetAllIdentifiers(source)
    if not source or source <= 0 then
        return {
            license = nil,
            steam = nil,
            discord = nil,
            fivem = nil,
            ip = nil
        }
    end

    return {
        license = GetIdentifier(source, 'license'),
        steam = GetIdentifier(source, 'steam'),
        discord = GetIdentifier(source, 'discord'),
        fivem = GetIdentifier(source, 'fivem'),
        ip = GetPlayerEndpoint(source)
    }
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DATABASE WHITELIST CACHE (lyxguard_whitelist)
-- Avoid synchronous MySQL calls inside hot paths.
local _DbWhitelistLoaded = false
local _DbWhitelist = {}

local function _RefreshDbWhitelist()
    if not MySQL or not MySQL.query then
        return
    end

    MySQL.query('SELECT identifier, level FROM lyxguard_whitelist', {}, function(rows)
        local map = {}
        for _, r in ipairs(rows or {}) do
            if r and r.identifier and r.level then
                map[tostring(r.identifier)] = tostring(r.level)
            end
        end
        _DbWhitelist = map
        _DbWhitelistLoaded = true
    end)
end

if MySQL and MySQL.ready then
    MySQL.ready(function()
        _RefreshDbWhitelist()
    end)
else
    CreateThread(function()
        Wait(5000)
        _RefreshDbWhitelist()
    end)
end

AddEventHandler('lyxguard:whitelist:refresh', function()
    _RefreshDbWhitelist()
end)

-- PERMISSION MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════════

---Check if player has immunity from anti-cheat
---IMPORTANT: This is called DURING playerConnecting before ESX is fully loaded,
---so we check ACE permissions FIRST (they work during connection)
---@param source number Player source
---@return boolean
function IsPlayerImmune(source)
    local level, _ = GetPlayerPermissionLevel(source)
    return level == 'full'
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- v4.4 ULTRA PROFESIONAL: Sistema avanzado de permisos
-- ═══════════════════════════════════════════════════════════════════════════════

---Get detailed permission level for a player
---@param source number Player source
---@return string level ('full', 'vip', 'none')
---@return table|nil playerConfig (individual config if exists)
function GetPlayerPermissionLevel(source)
    if not source or source <= 0 then return 'none', nil end

    local permissions = Config and Config.Permissions
    if not permissions or permissions.enabled == false then
        return 'none', nil
    end

    local playerIds = GetPlayerIdentifiers(source)

    -- ═══════════════════════════════════════════════════════════════════
    -- PRIORITY 1: Check individual whitelist (overrides everything)
    -- ═══════════════════════════════════════════════════════════════════
    local individual = permissions.individualWhitelist
    if individual and individual.enabled and individual.players and playerIds then
        for _, playerId in ipairs(playerIds) do
            local playerConfig = individual.players[playerId]
            if playerConfig then
                local level = playerConfig.immuneLevel or 'vip'
                return level, playerConfig
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════════════
    -- PRIORITY 1.5: Persistent DB whitelist (managed from panel)
    if _DbWhitelistLoaded and playerIds then
        local foundVip = false
        for _, playerId in ipairs(playerIds) do
            local lvl = _DbWhitelist[playerId]
            if lvl == 'full' then
                return 'full', nil
            elseif lvl == 'vip' then
                foundVip = true
            end
        end
        if foundVip then
            return 'vip', nil
        end
    end

    -- PRIORITY 2: Check ACE permissions for full immunity
    -- ═══════════════════════════════════════════════════════════════════
    local acePerms = permissions.acePermissions or {}
    for _, perm in ipairs(acePerms) do
        if IsPlayerAceAllowed(source, perm) then
            return 'full', nil
        end
    end

    -- Check txAdmin if enabled
    if permissions.txAdminImmune == true then
        local txAdminACEs = { 'command.kick', 'command.ban', 'command.stop' }
        for _, perm in ipairs(txAdminACEs) do
            if IsPlayerAceAllowed(source, perm) then
                return 'full', nil
            end
        end
    end

    local vipAcePerms = permissions.vipAcePermissions or {}
    for _, perm in ipairs(vipAcePerms) do
        if IsPlayerAceAllowed(source, perm) then
            return 'vip', nil
        end
    end

    -- ═══════════════════════════════════════════════════════════════════
    -- PRIORITY 3: Check identifier whitelist for full immunity
    -- ═══════════════════════════════════════════════════════════════════
    local immuneIds = permissions.immuneIdentifiers or {}
    if #immuneIds > 0 and playerIds then
        for _, playerId in ipairs(playerIds) do
            for _, immuneId in ipairs(immuneIds) do
                if playerId == immuneId then
                    return 'full', nil
                end
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════════════
    -- PRIORITY 4: Check ESX groups
    -- ═══════════════════════════════════════════════════════════════════
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            local group = xPlayer.getGroup()

            -- Check immune groups (full immunity)
            local immuneGroups = permissions.immuneGroups or {}
            for _, immuneGroup in ipairs(immuneGroups) do
                if group == immuneGroup then
                    return 'full', nil
                end
            end

            -- Check VIP groups (reduced detection)
            local vipConfig = permissions.vipWhitelist
            if vipConfig and vipConfig.enabled then
                local vipGroups = vipConfig.vipGroups or {}
                for _, vipGroup in ipairs(vipGroups) do
                    if group == vipGroup then
                        return 'vip', nil
                    end
                end
            end
        end
    end

    return 'none', nil
end

---Check if a specific detection should apply to a player
---@param source number Player source
---@param detectionType string Detection type to check
---@return boolean shouldDetect
---@return number toleranceMultiplier
function ShouldDetect(source, detectionType)
    local level, playerConfig = GetPlayerPermissionLevel(source)
    detectionType = tostring(detectionType or '')
    local dt = detectionType:lower()

    -- Full immunity = never detect
    if level == 'full' then
        return false, 1.0
    end

    local permissions = Config and Config.Permissions
    local toleranceMultiplier = 1.0

    -- ═══════════════════════════════════════════════════════════════════
    -- Check individual player config first
    -- ═══════════════════════════════════════════════════════════════════
    if playerConfig then
        -- Check forced detections (always apply)
        if playerConfig.forcedDetections then
            for _, forced in ipairs(playerConfig.forcedDetections) do
                if tostring(forced):lower() == dt then
                    return true, playerConfig.toleranceMultiplier or 1.0
                end
            end
        end

        -- Check ignored detections
        if playerConfig.ignoredDetections then
            for _, ignored in ipairs(playerConfig.ignoredDetections) do
                if tostring(ignored):lower() == dt then
                    return false, 1.0
                end
            end
        end

        toleranceMultiplier = playerConfig.toleranceMultiplier or 1.0
    end

    -- ═══════════════════════════════════════════════════════════════════
    -- For VIP level without individual config, use VIP whitelist settings
    -- ═══════════════════════════════════════════════════════════════════
    if level == 'vip' and permissions then
        local vipConfig = permissions.vipWhitelist
        if vipConfig and vipConfig.enabled then
            -- Check always detect (highest priority for VIPs)
            if vipConfig.alwaysDetect then
                for _, always in ipairs(vipConfig.alwaysDetect) do
                    if tostring(always):lower() == dt then
                        return true, vipConfig.toleranceMultiplier or 2.0
                    end
                end
            end

            -- Check ignored detections for VIPs
            if vipConfig.ignoredDetections then
                for _, ignored in ipairs(vipConfig.ignoredDetections) do
                    if tostring(ignored):lower() == dt then
                        return false, 1.0
                    end
                end
            end

            toleranceMultiplier = vipConfig.toleranceMultiplier or 2.0
        end
    end

    -- Normal player or detection not in any list
    return true, toleranceMultiplier
end

---Get tolerance multiplier for a player
---@param source number Player source
---@return number multiplier
function GetPlayerToleranceMultiplier(source)
    local _, shouldDetect = ShouldDetect(source, 'any')
    return shouldDetect
end

-- Export new functions
exports('GetPlayerPermissionLevel', GetPlayerPermissionLevel)
exports('ShouldDetect', ShouldDetect)
exports('GetPlayerToleranceMultiplier', GetPlayerToleranceMultiplier)

-- ═══════════════════════════════════════════════════════════════════════════════
-- TIME UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════════

---Format timestamp to readable date string
---@param timestamp number Unix timestamp
---@return string
function FormatTime(timestamp)
    if not timestamp or timestamp <= 0 then
        return 'N/A'
    end
    return os.date('%Y-%m-%d %H:%M:%S', timestamp)
end

---Format hours to human-readable duration
---@param hours number
---@return string
function FormatDuration(hours)
    if not hours or hours <= 0 then
        return 'Permanente'
    end

    if hours < 1 then
        return math.floor(hours * 60) .. 'm'
    elseif hours < 24 then
        return math.floor(hours) .. 'h'
    elseif hours < 168 then -- 7 days
        local days = math.floor(hours / 24)
        return days .. 'd'
    elseif hours < 720 then -- 30 days
        return math.floor(hours / 168) .. 'w'
    else
        return math.floor(hours / 720) .. 'mo'
    end
end

---Calculate unban timestamp from hours
---@param hours number Hours until unban (0 = permanent)
---@return number|nil Nil for permanent
function GetUnbanTime(hours)
    if not hours or hours <= 0 then
        return nil -- Permanent
    end
    return os.time() + (hours * 3600)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEBUG LOGGING
-- ═══════════════════════════════════════════════════════════════════════════════

---Debug log (only when Config.Debug is true)
---@param message string
---@param ... any
function DebugLog(message, ...)
    if not Config or not Config.Debug then return end

    local formatted
    if select('#', ...) > 0 then
        local success, result = pcall(string.format, message, ...)
        formatted = success and result or message
    else
        formatted = message
    end

    print('^3[LyxGuard Debug]^7 ' .. formatted)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════════

exports('IsPlayerImmune', IsPlayerImmune)
exports('GetIdentifier', GetIdentifier)
exports('GetAllIdentifiers', GetAllIdentifiers)
