--[[
    LyxGuard v2.1 - Structured Logger Module
    JSON-based logging system with Discord webhook support
]]

StructuredLogger = {}

-- Configuration (can be overridden by Config.Logger)
local LoggerConfig = {
    enabled = true,
    saveToFile = true,
    sendToDiscord = true,
    minLevel = 1,                  -- 1=DEBUG, 2=INFO, 3=WARN, 4=ERROR, 5=CRITICAL
    filePath = 'lyxguard_logs.json',
    maxFileSize = 5 * 1024 * 1024, -- 5MB
    discordWebhook = nil,          -- Set from main config
    discordColors = {
        DEBUG = 8421504,           -- Gray
        INFO = 3447003,            -- Blue
        WARN = 16776960,           -- Yellow
        ERROR = 15158332,          -- Red
        CRITICAL = 10038562        -- Dark Red
    }
}

-- Log levels
local LOG_LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    CRITICAL = 5
}

-- Internal log buffer
local logBuffer = {}
local maxBufferSize = 100

-- ═══════════════════════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════════

function StructuredLogger.Init(config)
    if config then
        for k, v in pairs(config) do
            LoggerConfig[k] = v
        end
    end

    -- Get webhook from main config if available
    if Config and Config.DiscordWebhooks and Config.DiscordWebhooks.detections then
        LoggerConfig.discordWebhook = Config.DiscordWebhooks.detections
    end

    print('^5[LyxGuard Logger]^7 Initialized with level: ' .. LoggerConfig.minLevel)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CORE LOGGING FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

function StructuredLogger.Log(level, module, data)
    if not LoggerConfig.enabled then return end

    local levelNum = LOG_LEVELS[level] or 2
    if levelNum < LoggerConfig.minLevel then return end

    local log = {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        level = level,
        module = module,
        data = data,
        server = GetConvar('sv_hostname', 'Unknown'),
        resource = GetCurrentResourceName()
    }

    -- Add to buffer
    table.insert(logBuffer, log)
    if #logBuffer > maxBufferSize then
        table.remove(logBuffer, 1)
    end

    -- Console output
    local prefix = level == 'DEBUG' and '^3' or
        level == 'INFO' and '^5' or
        level == 'WARN' and '^3' or
        level == 'ERROR' and '^1' or
        level == 'CRITICAL' and '^1^7' or '^7'
    print(prefix .. '[LyxGuard ' .. level .. ']^7 [' .. module .. '] ' .. (data.message or json.encode(data)))

    -- Send to Discord if enabled and level is WARN or higher
    if LoggerConfig.sendToDiscord and levelNum >= 3 and LoggerConfig.discordWebhook then
        StructuredLogger.SendToDiscord(log)
    end

    return log
end

-- Convenience functions
function StructuredLogger.Debug(module, message, data)
    return StructuredLogger.Log('DEBUG', module, { message = message, details = data })
end

function StructuredLogger.Info(module, message, data)
    return StructuredLogger.Log('INFO', module, { message = message, details = data })
end

function StructuredLogger.Warn(module, message, data)
    return StructuredLogger.Log('WARN', module, { message = message, details = data })
end

function StructuredLogger.Error(module, message, data)
    return StructuredLogger.Log('ERROR', module, { message = message, details = data })
end

function StructuredLogger.Critical(module, message, data)
    return StructuredLogger.Log('CRITICAL', module, { message = message, details = data })
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DETECTION LOGGING
-- ═══════════════════════════════════════════════════════════════════════════════

function StructuredLogger.LogDetection(detectionType, playerData, detectionData)
    local log = StructuredLogger.Log('WARN', 'DETECTION', {
        type = detectionType,
        player = {
            id = playerData.id,
            name = playerData.name,
            identifier = playerData.identifier,
            ip = playerData.ip,
            coordinates = playerData.coordinates
        },
        detection = {
            module = detectionData.module,
            severity = detectionData.severity or 'medium',
            confidence = detectionData.confidence or 0.8,
            evidence = detectionData.evidence,
            action = detectionData.action or 'logged'
        },
        message = string.format('[%s] %s detected for %s',
            detectionType,
            detectionData.module or 'Unknown',
            playerData.name or 'Unknown')
    })

    return log
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- BAN/PUNISHMENT LOGGING
-- ═══════════════════════════════════════════════════════════════════════════════

function StructuredLogger.LogBan(playerData, banData, adminData)
    local log = StructuredLogger.Log('CRITICAL', 'BAN', {
        player = {
            id = playerData.id,
            name = playerData.name,
            identifier = playerData.identifier,
            ip = playerData.ip
        },
        ban = {
            reason = banData.reason,
            duration = banData.duration,
            permanent = banData.permanent or false,
            autoban = banData.autoban or false,
            detectionType = banData.detectionType
        },
        admin = adminData and {
            id = adminData.id,
            name = adminData.name,
            identifier = adminData.identifier
        } or nil,
        message = string.format('Player %s was banned for: %s',
            playerData.name or 'Unknown',
            banData.reason or 'No reason')
    })

    return log
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DISCORD WEBHOOK
-- ═══════════════════════════════════════════════════════════════════════════════

function StructuredLogger.SendToDiscord(log)
    if not LoggerConfig.discordWebhook or LoggerConfig.discordWebhook == '' then return end

    local color = LoggerConfig.discordColors[log.level] or 3447003

    local embed = {
        title = '🛡️ LyxGuard ' .. log.level,
        description = log.data.message or 'No message',
        color = color,
        timestamp = log.timestamp,
        footer = {
            text = 'LyxGuard v2.1 | ' .. (log.server or 'Unknown Server')
        },
        fields = {}
    }

    -- Add module field
    if log.module then
        table.insert(embed.fields, {
            name = '📋 Module',
            value = '`' .. log.module .. '`',
            inline = true
        })
    end

    -- Add player info if available
    if log.data.player then
        table.insert(embed.fields, {
            name = '👤 Player',
            value = string.format('%s (ID: %d)',
                log.data.player.name or 'Unknown',
                log.data.player.id or 0),
            inline = true
        })
    end

    -- Add detection info if available
    if log.data.detection then
        table.insert(embed.fields, {
            name = '🔍 Detection',
            value = string.format('Type: %s\nSeverity: %s\nConfidence: %.0f%%',
                log.data.detection.module or 'Unknown',
                log.data.detection.severity or 'medium',
                (log.data.detection.confidence or 0.8) * 100),
            inline = false
        })
    end

    -- Add evidence if available
    if log.data.detection and log.data.detection.evidence then
        local evidenceStr = type(log.data.detection.evidence) == 'table'
            and json.encode(log.data.detection.evidence)
            or tostring(log.data.detection.evidence)

        if #evidenceStr > 1000 then
            evidenceStr = evidenceStr:sub(1, 997) .. '...'
        end

        table.insert(embed.fields, {
            name = '📝 Evidence',
            value = '```json\n' .. evidenceStr .. '\n```',
            inline = false
        })
    end

    local payload = {
        username = 'LyxGuard',
        avatar_url = 'https://i.imgur.com/4M34hi2.png',
        embeds = { embed }
    }

    PerformHttpRequest(LoggerConfig.discordWebhook, function(statusCode, text, headers)
        if statusCode ~= 200 and statusCode ~= 204 then
            print('^1[LyxGuard Logger]^7 Discord webhook failed: ' .. tostring(statusCode))
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

function StructuredLogger.GetRecentLogs(count)
    count = count or 50
    local result = {}
    local start = math.max(1, #logBuffer - count + 1)
    for i = start, #logBuffer do
        table.insert(result, logBuffer[i])
    end
    return result
end

function StructuredLogger.GetLogsByLevel(level, count)
    count = count or 50
    local result = {}
    for i = #logBuffer, 1, -1 do
        if logBuffer[i].level == level then
            table.insert(result, 1, logBuffer[i])
            if #result >= count then break end
        end
    end
    return result
end

function StructuredLogger.GetLogsByModule(module, count)
    count = count or 50
    local result = {}
    for i = #logBuffer, 1, -1 do
        if logBuffer[i].module == module then
            table.insert(result, 1, logBuffer[i])
            if #result >= count then break end
        end
    end
    return result
end

function StructuredLogger.ClearBuffer()
    logBuffer = {}
end

-- Export for use by other scripts
exports('GetLogger', function()
    return StructuredLogger
end)
