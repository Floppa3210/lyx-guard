--[[
    
                               LYXGUARD v4.0 PROFESSIONAL                         
                                Discord Webhooks                                   
    
      Author: LyxDev                                                               
      License: Commercial                                                          
      Purpose: Discord webhook integration for notifications and logging          
    
]]

-- 
-- WEBHOOK CONFIGURATION
-- 

local WEBHOOK_COOLDOWN = 1000 -- Minimum ms between webhooks (rate limiting)
local MAX_EMBED_LENGTH = 2000 -- Discord embed field limit
local lastWebhookTime = 0

-- Embed colors
local COLORS = {
    DETECTION = 16711680, -- Red
    WARNING = 16776960,   -- Yellow
    BAN = 15158332,       -- Dark Red
    KICK = 15105570,      -- Orange
    INFO = 3447003,       -- Blue
    SUCCESS = 3066993     -- Green
}

-- 
-- CORE WEBHOOK FUNCTION
-- 

---Send webhook to Discord
---@param webhookUrl string Discord webhook URL
---@param embed table Embed object
---@param content? string Optional message content
---@return boolean success
function SendWebhook(webhookUrl, embed, content)
    -- Validate URL
    if not webhookUrl or type(webhookUrl) ~= 'string' or webhookUrl == '' then
        return false
    end

    if not string.match(webhookUrl, '^https://discord%.com/api/webhooks/') and
        not string.match(webhookUrl, '^https://discordapp%.com/api/webhooks/') then
        if Config and Config.Debug then
            print('^3[LyxGuard Webhook]^7 Invalid webhook URL format')
        end
        return false
    end

    -- Rate limiting
    local now = GetGameTimer()
    if now - lastWebhookTime < WEBHOOK_COOLDOWN then
        if Config and Config.Debug then
            print('^3[LyxGuard Webhook]^7 Rate limited, skipping')
        end
        return false
    end
    lastWebhookTime = now

    -- Build payload
    local discordConfig = Config and Config.Discord or {}
    local payload = {
        username = 'LyxGuard',
        avatar_url = discordConfig.serverLogo ~= '' and discordConfig.serverLogo or nil,
        embeds = { embed }
    }

    if content and content ~= '' then
        payload.content = content
    end

    -- Send request with error handling
    local success, err = pcall(function()
        PerformHttpRequest(webhookUrl, function(statusCode, responseText, headers)
            if statusCode ~= 200 and statusCode ~= 204 and statusCode ~= nil then
                if Config and Config.Debug then
                    print(string.format('^1[LyxGuard Webhook]^7 HTTP Error: %d', statusCode))
                end
            end
        end, 'POST', json.encode(payload), {
            ['Content-Type'] = 'application/json'
        })
    end)

    if not success and Config and Config.Debug then
        print('^1[LyxGuard Webhook]^7 Error: ' .. tostring(err))
    end

    return success
end

-- 
-- HELPER FUNCTIONS
-- 

---Truncate string to max length
---@param str string
---@param maxLen number
---@return string
local function Truncate(str, maxLen)
    if not str then return '' end
    str = tostring(str)
    if #str > maxLen then
        return str:sub(1, maxLen - 3) .. '...'
    end
    return str
end

---Get player data safely
---@param source number
---@return table|nil
local function GetPlayerDataSafe(source)
    if not source then return nil end
    if PlayerData and PlayerData[source] then
        return PlayerData[source]
    end
    return nil
end

---Get webhook URL from config
---@param webhookType string
---@return string|nil
local function GetWebhookUrl(webhookType)
    local discord = Config and Config.Discord
    if not discord or not discord.webhooks then return nil end
    return discord.webhooks[webhookType]
end

-- 
-- DETECTION WEBHOOK
-- 

---Send detection alert to Discord
---@param source number Player source
---@param detectionType string Type of detection
---@param details? table Additional details
---@param coords? table Player coordinates
---@param punishment? string Punishment applied
function SendDiscordDetection(source, detectionType, details, coords, punishment)
    local webhookUrl = GetWebhookUrl('detections')
    if not webhookUrl then return end

    local pd = GetPlayerDataSafe(source)
    if not pd then return end

    local discordConfig = Config and Config.Discord or {}

    -- Build coordinates string
    local coordsStr = 'N/A'
    if coords and coords.x then
        coordsStr = string.format('%.2f, %.2f, %.2f', coords.x, coords.y, coords.z)
    end

    -- Build details string
    local detailsStr = 'N/A'
    if details then
        local success, encoded = pcall(json.encode, details)
        if success then
            detailsStr = Truncate(encoded, 500)
        end
    end

    local embed = {
        title = 'Deteccion de Anti-Cheat',
        color = COLORS.DETECTION,
        thumbnail = {
            url = discordConfig.serverLogo or nil
        },
        fields = {
            { name = 'Jugador', value = Truncate(pd.name or 'Unknown', 100), inline = true },
            { name = 'ID', value = tostring(source), inline = true },
            { name = 'Deteccion', value = detectionType or 'Unknown', inline = true },
            { name = 'Castigo', value = punishment or 'none', inline = true },
            { name = 'Identifier', value = '`' .. Truncate(pd.identifier or 'N/A', 50) .. '`', inline = false },
            { name = 'Coords', value = '`' .. coordsStr .. '`', inline = true }
        },
        footer = {
            text = discordConfig.serverFooter or 'LyxGuard',
            icon_url = discordConfig.serverLogo or nil
        },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    -- Add Steam/Discord if available
    if pd.steam then
        table.insert(embed.fields, { name = 'Steam', value = '`' .. pd.steam .. '`', inline = true })
    end
    if pd.discord then
        table.insert(embed.fields, { name = 'Discord', value = '`' .. pd.discord .. '`', inline = true })
    end

    SendWebhook(webhookUrl, embed)
end

-- 
-- WARNING WEBHOOK
-- 

---Send warning notification to Discord
---@param source number
---@param reason string
---@param currentCount? number
---@param maxWarnings? number
function SendDiscordWarning(source, reason, currentCount, maxWarnings)
    local webhookUrl = GetWebhookUrl('warnings') or GetWebhookUrl('logs')
    if not webhookUrl then return end

    local pd = GetPlayerDataSafe(source)
    if not pd then return end

    currentCount = currentCount or 1
    maxWarnings = maxWarnings or 3

    local discordConfig = Config and Config.Discord or {}

    local embed = {
        title = 'Advertencia Emitida',
        color = COLORS.WARNING,
        fields = {
            { name = 'Jugador', value = Truncate(pd.name or 'Unknown', 100), inline = true },
            { name = 'ID', value = tostring(source), inline = true },
            { name = 'Razon', value = Truncate(reason or 'Sin razon', 200), inline = false },
            { name = 'Warnings', value = currentCount .. '/' .. maxWarnings, inline = true }
        },
        footer = {
            text = discordConfig.serverFooter or 'LyxGuard'
        },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    SendWebhook(webhookUrl, embed)
end

-- 
-- KICK WEBHOOK
-- 

---Send kick notification to Discord
---@param source number
---@param reason string
---@param playerName? string
function SendDiscordKick(source, reason, playerName)
    local webhookUrl = GetWebhookUrl('kicks') or GetWebhookUrl('logs')
    if not webhookUrl then return end

    local pd = GetPlayerDataSafe(source)
    local name = playerName or (pd and pd.name) or 'Unknown'
    local identifier = pd and pd.identifier or 'N/A'

    local discordConfig = Config and Config.Discord or {}

    local embed = {
        title = 'Jugador Expulsado',
        color = COLORS.KICK,
        fields = {
            { name = 'Jugador', value = Truncate(name, 100), inline = true },
            { name = 'ID', value = tostring(source), inline = true },
            { name = 'Razon', value = Truncate(reason or 'Sin razon', 200), inline = false },
            { name = 'Identifier', value = '`' .. Truncate(identifier, 50) .. '`', inline = false }
        },
        footer = {
            text = discordConfig.serverFooter or 'LyxGuard'
        },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    SendWebhook(webhookUrl, embed)
end

-- 
-- BAN WEBHOOK
-- 

---Send ban notification to Discord
---@param source number
---@param reason string
---@param duration any Duration key or hours
---@param playerName? string
---@param bannedBy? string
function SendDiscordBan(source, reason, duration, playerName, bannedBy)
    local webhookUrl = GetWebhookUrl('bans') or GetWebhookUrl('logs')
    if not webhookUrl then return end

    local pd = GetPlayerDataSafe(source)
    local name = playerName or (pd and pd.name) or 'Unknown'
    local identifier = pd and pd.identifier or 'N/A'

    -- Format duration
    local durationStr = 'Permanente'
    if duration and duration ~= 0 and duration ~= 'permanent' then
        if type(duration) == 'number' then
            durationStr = FormatDuration and FormatDuration(duration) or (duration .. 'h')
        else
            durationStr = tostring(duration)
        end
    end

    local discordConfig = Config and Config.Discord or {}

    local embed = {
        title = 'Jugador Baneado',
        color = COLORS.BAN,
        fields = {
            { name = 'Jugador', value = Truncate(name, 100), inline = true },
            { name = 'ID', value = tostring(source), inline = true },
            { name = 'Duracion', value = durationStr, inline = true },
            { name = 'Razon', value = Truncate(reason or 'Sin razon', 200), inline = false },
            { name = 'Identifier', value = '`' .. Truncate(identifier, 50) .. '`', inline = false },
            { name = 'Baneado por', value = bannedBy or 'LyxGuard', inline = true }
        },
        footer = {
            text = discordConfig.serverFooter or 'LyxGuard'
        },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    -- Add identifiers
    if pd then
        if pd.steam then
            table.insert(embed.fields, { name = 'Steam', value = '`' .. pd.steam .. '`', inline = true })
        end
        if pd.discord then
            table.insert(embed.fields, { name = 'Discord', value = '`' .. pd.discord .. '`', inline = true })
        end
    end

    SendWebhook(webhookUrl, embed)
end

-- 
-- SCREENSHOT WEBHOOK
-- 

---Send screenshot to Discord
---@param source number
---@param reason string
---@param imageData string Base64 image data
function SendScreenshotWebhook(source, reason, imageData)
    local webhookUrl = GetWebhookUrl('screenshots') or GetWebhookUrl('detections')
    if not webhookUrl then return end

    local pd = GetPlayerDataSafe(source)
    local name = pd and pd.name or 'Unknown'

    -- Note: Base64 screenshots require special handling
    -- Discord webhooks don't directly support base64 images
    -- You would need to upload to a service first or use a file upload endpoint

    local discordConfig = Config and Config.Discord or {}

    local embed = {
        title = 'Screenshot Capturado',
        color = COLORS.INFO,
        fields = {
            { name = 'Jugador', value = Truncate(name, 100), inline = true },
            { name = 'ID', value = tostring(source), inline = true },
            { name = 'Razon', value = Truncate(reason or 'Deteccion', 200), inline = false }
        },
        footer = {
            text = discordConfig.serverFooter or 'LyxGuard'
        },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    SendWebhook(webhookUrl, embed)
end

-- Generic webhook bridge used by some modules (e.g. ban_system.lua).
AddEventHandler('lyxguard:sendWebhook', function(webhookType, embed)
    if type(webhookType) ~= 'string' or webhookType == '' then
        return
    end
    if type(embed) ~= 'table' then
        return
    end

    local url = GetWebhookUrl(webhookType)
    if not url then
        return
    end

    local safeEmbed = {
        title = tostring(embed.title or 'LyxGuard'),
        color = tonumber(embed.color) or COLORS.INFO,
        fields = type(embed.fields) == 'table' and embed.fields or {},
        footer = type(embed.footer) == 'table' and embed.footer or {
            text = (Config and Config.Discord and Config.Discord.serverFooter) or 'LyxGuard'
        },
        timestamp = embed.timestamp or os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    if type(embed.description) == 'string' and embed.description ~= '' then
        safeEmbed.description = Truncate(embed.description, MAX_EMBED_LENGTH)
    end
    if type(embed.thumbnail) == 'table' then
        safeEmbed.thumbnail = embed.thumbnail
    end

    SendWebhook(url, safeEmbed, embed.content)
end)



