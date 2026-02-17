--[[
    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║                           LYXGUARD v4.0 PROFESSIONAL                         ║
    ║                        Shared Utility Library                                 ║
    ╠═══════════════════════════════════════════════════════════════════════════════╣
    ║  Author: LyxDev                                                               ║
    ║  License: Commercial                                                          ║
    ║  Purpose: Pure utility functions shared between server and client             ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝
]]

---@class LyxGuardLib
LyxGuardLib = LyxGuardLib or {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONSTANTS
-- ═══════════════════════════════════════════════════════════════════════════════

LyxGuardLib.VERSION = '4.0.0'
LyxGuardLib.RESOURCE_NAME = GetCurrentResourceName()

-- Detection type constants
-- v4.4 HOTFIX: Added ALL detection types to prevent Invalid detection warnings
LyxGuardLib.DETECTIONS = {
    -- Movement
    TELEPORT = 'teleport',
    NOCLIP = 'noclip',
    SPEEDHACK = 'speedhack',
    SUPERJUMP = 'superjump',
    FLYHACK = 'flyhack',
    UNDERGROUND = 'underground',
    WALLBREACH = 'wallbreach',
    TASKTP = 'tasktp',
    -- Combat
    GODMODE = 'godmode',
    HEALTHHACK = 'healthhack',
    ARMORHACK = 'armorhack',
    RAPIDFIRE = 'rapidfire',
    INFINITEAMMO = 'infiniteammo',
    AIMBOT_ULTRA = 'aimbot_ultra',
    -- Anti (alternative naming from other anticheats)
    ANTI_GODMODE = 'Anti-GodMode',
    ANTI_TELEPORT = 'Anti-Teleport',
    -- Entities
    EXPLOSION = 'explosion',
    CAGETRAP = 'cagetrap',
    VEHICLEGODMODE = 'vehiclegodmode',
    VEHICLE_SPAWN = 'vehicle_spawn',
    -- Blacklists
    BLACKLIST_WEAPON = 'blacklist_weapon',
    BLACKLIST_VEHICLE = 'blacklist_vehicle',
    BLACKLIST_PED = 'blacklist_ped',
    -- Advanced
    INJECTION = 'injection',
    AFKFARMING = 'afkfarming',
    RESOURCEVALIDATION = 'resourcevalidation',
    MENUDETECTION = 'menudetection',
    -- Player State
    RAGDOLL_DISABLED = 'ragdoll_disabled',
    INVISIBLE_ABUSE = 'invisible_abuse',
    INVISIBLEPLAYER = 'invisibleplayer',
    SPECTATEABUSE = 'spectateabuse',
    HONEYPOT_EVENT = 'honeypot_event'
}

-- Punishment type constants
LyxGuardLib.PUNISHMENTS = {
    NONE = 'none',
    NOTIFY = 'notify',
    SCREENSHOT = 'screenshot',
    WARN = 'warn',
    KICK = 'kick',
    BAN_TEMP = 'ban_temp',
    BAN_PERM = 'ban_perm',
    TELEPORT = 'teleport',
    FREEZE = 'freeze',
    KILL = 'kill'
}

-- Ban duration presets (in seconds)
LyxGuardLib.BAN_DURATIONS = {
    SHORT = 3600,        -- 1 hour
    MEDIUM = 86400,      -- 1 day
    LONG = 604800,       -- 1 week
    VERY_LONG = 2592000, -- 30 days
    PERMANENT = 0        -- Permanent (0 = no unban date)
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- TYPE VALIDATION
-- ═══════════════════════════════════════════════════════════════════════════════

---@param value any
---@param expectedType string
---@param paramName string
---@return boolean
function LyxGuardLib.ValidateType(value, expectedType, paramName)
    local actualType = type(value)
    if actualType ~= expectedType then
        LyxGuardLib.Error('Invalid type for %s: expected %s, got %s', paramName, expectedType, actualType)
        return false
    end
    return true
end

---@param value number
---@param min number
---@param max number
---@param paramName string
---@return number
function LyxGuardLib.ClampNumber(value, min, max, paramName)
    if type(value) ~= 'number' then
        LyxGuardLib.Warn('ClampNumber: %s is not a number, defaulting to min', paramName)
        return min
    end
    return math.max(min, math.min(max, value))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- STRING UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════════

---Sanitize string for safe logging/display
---@param str string
---@param maxLength? number
---@return string
function LyxGuardLib.Sanitize(str, maxLength)
    if type(str) ~= 'string' then
        return tostring(str)
    end

    -- Remove dangerous characters for logs
    local sanitized = str:gsub('[%c]', '')      -- Remove control characters
    sanitized = sanitized:gsub('[\n\r\t]', ' ') -- Replace whitespace chars

    -- Truncate if needed
    if maxLength and #sanitized > maxLength then
        sanitized = sanitized:sub(1, maxLength) .. '...'
    end

    return sanitized
end

---Trim whitespace from string
---@param str string
---@return string
function LyxGuardLib.Trim(str)
    if type(str) ~= 'string' then return '' end
    return str:match('^%s*(.-)%s*$')
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TIME UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════════

---Format timestamp to readable string
---@param timestamp number Unix timestamp
---@return string
function LyxGuardLib.FormatTime(timestamp)
    if not timestamp or timestamp <= 0 then
        return 'Nunca'
    end
    return os.date('%Y-%m-%d %H:%M:%S', timestamp)
end

---Format duration in seconds to readable string
---@param seconds number
---@return string
function LyxGuardLib.FormatDuration(seconds)
    if not seconds or seconds <= 0 then
        return 'Permanente'
    end

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    local parts = {}
    if days > 0 then table.insert(parts, days .. 'd') end
    if hours > 0 then table.insert(parts, hours .. 'h') end
    if minutes > 0 then table.insert(parts, minutes .. 'm') end

    return #parts > 0 and table.concat(parts, ' ') or '< 1m'
end

---Parse MySQL datetime string to timestamp
---@param dateString string Format: 'YYYY-MM-DD HH:MM:SS'
---@return number|nil
function LyxGuardLib.ParseMySQLDate(dateString)
    if not dateString then return nil end

    local pattern = '(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)'
    local y, m, d, h, min, s = string.match(tostring(dateString), pattern)

    if y then
        return os.time({
            year = tonumber(y),
            month = tonumber(m),
            day = tonumber(d),
            hour = tonumber(h),
            min = tonumber(min),
            sec = tonumber(s)
        })
    end

    return nil
end

---Calculate unban timestamp from now + duration
---@param durationKey string Key from Config.Punishments.banDurations or seconds
---@return number|nil Nil for permanent
function LyxGuardLib.GetUnbanTime(durationKey)
    local durations = (Config and Config.Punishments and Config.Punishments.banDurations) or LyxGuardLib.BAN_DURATIONS
    local seconds = durations[durationKey] or tonumber(durationKey) or 0

    if seconds <= 0 then
        return nil -- Permanent
    end

    return os.time() + seconds
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- LOGGING SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local LOG_LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4
}

local LOG_COLORS = {
    [1] = '^7', -- DEBUG: White
    [2] = '^2', -- INFO: Green
    [3] = '^3', -- WARN: Yellow
    [4] = '^1'  -- ERROR: Red
}

local LOG_PREFIXES = {
    [1] = 'DEBUG',
    [2] = 'INFO',
    [3] = 'WARN',
    [4] = 'ERROR'
}

---Internal log function
---@param level number
---@param message string
---@param ... any
local function Log(level, message, ...)
    local minLevel = (Config and Config.Debug) and LOG_LEVELS.DEBUG or LOG_LEVELS.INFO

    if level < minLevel then return end

    local formatted = string.format(message, ...)
    local sanitized = LyxGuardLib.Sanitize(formatted, 500)

    print(string.format('%s[LyxGuard %s]^7 %s',
        LOG_COLORS[level],
        LOG_PREFIXES[level],
        sanitized
    ))
end

function LyxGuardLib.Debug(message, ...)
    Log(LOG_LEVELS.DEBUG, message, ...)
end

function LyxGuardLib.Info(message, ...)
    Log(LOG_LEVELS.INFO, message, ...)
end

function LyxGuardLib.Warn(message, ...)
    Log(LOG_LEVELS.WARN, message, ...)
end

function LyxGuardLib.Error(message, ...)
    Log(LOG_LEVELS.ERROR, message, ...)
end

-- Legacy compatibility
function DebugLog(message, ...)
    LyxGuardLib.Debug(message, ...)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════════

---Deep copy a table
---@param original table
---@return table
function LyxGuardLib.DeepCopy(original)
    if type(original) ~= 'table' then
        return original
    end

    local copy = {}
    for key, value in pairs(original) do
        if type(value) == 'table' then
            copy[key] = LyxGuardLib.DeepCopy(value)
        else
            copy[key] = value
        end
    end

    return copy
end

---Merge two tables (source into target)
---@param target table
---@param source table
---@return table
function LyxGuardLib.MergeTables(target, source)
    target = target or {}
    source = source or {}

    for key, value in pairs(source) do
        if type(value) == 'table' and type(target[key]) == 'table' then
            LyxGuardLib.MergeTables(target[key], value)
        else
            target[key] = value
        end
    end

    return target
end

---Check if value exists in array
---@param array table
---@param value any
---@return boolean
function LyxGuardLib.Contains(array, value)
    if type(array) ~= 'table' then return false end

    for _, v in ipairs(array) do
        if v == value then
            return true
        end
    end

    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- VALIDATION UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════════

---Validate if detection type is valid
---@param detectionType string
---@return boolean
function LyxGuardLib.IsValidDetection(detectionType)
    detectionType = tostring(detectionType or '')
    local normalized = detectionType:gsub('_', ''):lower()

    for _, v in pairs(LyxGuardLib.DETECTIONS) do
        if v == detectionType then
            return true
        end
        if tostring(v):gsub('_', ''):lower() == normalized then
            return true
        end
    end

    local function matchesConfigTable(tbl)
        if type(tbl) ~= 'table' then return false end
        for k, v in pairs(tbl) do
            if type(v) == 'table' and tostring(k):gsub('_', ''):lower() == normalized then
                return true
            end
        end
        return false
    end

    if Config then
        if matchesConfigTable(Config.Movement) then return true end
        if matchesConfigTable(Config.Combat) then return true end
        if matchesConfigTable(Config.Entities) then return true end
        if matchesConfigTable(Config.Advanced) then return true end
        if matchesConfigTable(Config.Ultra) then return true end
    end

    return false
end

---Validate if punishment type is valid
---@param punishmentType string
---@return boolean
function LyxGuardLib.IsValidPunishment(punishmentType)
    if punishmentType == 'ban' then
        return true
    end
    for _, v in pairs(LyxGuardLib.PUNISHMENTS) do
        if v == punishmentType then
            return true
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- LOCALIZATION
-- ═══════════════════════════════════════════════════════════════════════════════

---Get localized string
---@param key string
---@param ... any Format arguments
---@return string
function LyxGuardLib.L(key, ...)
    local locale = Config and Config.Locale or 'es'
    local locales = Config and Config.Locales or {}
    local l = locales[locale] or locales['es'] or {}

    local text = l[key] or key

    if select('#', ...) > 0 then
        local success, result = pcall(string.format, text, ...)
        return success and result or text
    end

    return text
end

-- Export for GetLocale compatibility
GetLocale = LyxGuardLib.L

return LyxGuardLib
