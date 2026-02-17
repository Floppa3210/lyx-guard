--[[
    LyxGuard - Connection Security Module
    Anti-VPN, VAC Ban checker, Name filter, and enhanced deferrals
    Based on Icarus DeferralsModule
]]

local ConnectionSecurity = {}

-- Configuration (can be overridden by Config)
local Settings = {
    AntiVPN = {
        enabled = false,
        apiUrl = 'https://vpnapi.io/api/', -- Free VPN detection API
        apiKey = '', -- Optional API key for more checks
        rejectMessage = 'Conectar via VPN no esta permitido. Desactiva tu VPN para conectar.'
    },
    VACBanCheck = {
        enabled = false, -- Requires steam_webApiKey in server.cfg
        rejectMessage = 'Estas baneado en Steam VAC y no puedes conectar a este servidor.'
    },
    NameFilter = {
        enabled = true,
        blockNonAlphanumeric = false, -- Block names with special chars
        minLength = 3,
        maxLength = 32,
        blacklistedWords = {
            'admin', 'moderator', 'owner', 'staff', 'console',
            'nigger', 'nigga', 'faggot', 'nazi', 'hitler'
        },
        rejectMessage = 'Tu nombre contiene caracteres o palabras no permitidas.'
    },
    MinIdentifiers = 2, -- Minimum identifiers required to connect
    HideIP = true
}
-- -----------------------------------------------------------------------------
-- VPN DETECTION
-- -----------------------------------------------------------------------------

--- Check if IP is a VPN
---@param ip string
---@param callback function(isVPN: boolean, country: string|nil)
local function CheckVPN(ip, callback)
    if not Settings.AntiVPN.enabled or not ip or ip == '' then
        callback(false, nil)
        return
    end
    
    -- Clean IP (remove port if present)
    ip = ip:gsub(':%d+$', '')
    
    -- Use vpnapi.io (free tier: 100 queries/day)
    local url = Settings.AntiVPN.apiUrl .. ip
    if Settings.AntiVPN.apiKey and Settings.AntiVPN.apiKey ~= '' then
        url = url .. '?key=' .. Settings.AntiVPN.apiKey
    end
    
    PerformHttpRequest(url, function(status, response, headers)
        if status ~= 200 then
            -- API error, allow connection
            callback(false, nil)
            return
        end
        
        local data = json.decode(response)
        if not data then
            callback(false, nil)
            return
        end
        
        local isVPN = false
        local country = nil
        
        -- vpnapi.io response format
        if data.security then
            isVPN = data.security.vpn or data.security.proxy or data.security.tor
        end
        
        if data.location then
            country = data.location.country
        end
        
        callback(isVPN, country)
    end, 'GET', '', { ['Content-Type'] = 'application/json' })
end
-- -----------------------------------------------------------------------------
-- VAC BAN CHECK
-- -----------------------------------------------------------------------------

--- Check Steam VAC ban status
---@param steamId string Steam64 ID
---@param callback function(isBanned: boolean)
local function CheckVACBan(steamId, callback)
    if not Settings.VACBanCheck.enabled or not steamId then
        callback(false)
        return
    end
    
    -- Extract Steam64 ID from identifier
    local steam64 = steamId:gsub('steam:', '')
    
    -- Convert hex to decimal if needed
    if steam64:match('^%x+$') then
        local high = tonumber(steam64:sub(1, 8), 16) or 0
        local low = tonumber(steam64:sub(9), 16) or 0
        steam64 = tostring(high * 4294967296 + low)
    end
    
    -- Get Steam API key from convar
    local steamApiKey = GetConvar('steam_webApiKey', '')
    if steamApiKey == '' then
        callback(false)
        return
    end
    
    local url = ('https://api.steampowered.com/ISteamUser/GetPlayerBans/v1/?key=%s&steamids=%s'):format(
        steamApiKey, steam64
    )
    
    PerformHttpRequest(url, function(status, response)
        if status ~= 200 then
            callback(false)
            return
        end
        
        local data = json.decode(response)
        if not data or not data.players or #data.players == 0 then
            callback(false)
            return
        end
        
        local player = data.players[1]
        local isBanned = player.VACBanned or player.NumberOfVACBans > 0 or player.NumberOfGameBans > 0
        
        callback(isBanned)
    end, 'GET', '', {})
end
-- -----------------------------------------------------------------------------
-- NAME FILTER
-- -----------------------------------------------------------------------------

--- Check if player name is valid
---@param name string
---@return boolean isValid
---@return string|nil reason
local function ValidateName(name)
    if not Settings.NameFilter.enabled then
        return true, nil
    end
    
    if not name or name == '' then
        return false, 'Nombre vacio'
    end
    
    -- Length check
    if #name < Settings.NameFilter.minLength then
        return false, ('Nombre muy corto (minimo %d caracteres)'):format(Settings.NameFilter.minLength)
    end
    
    if #name > Settings.NameFilter.maxLength then
        return false, ('Nombre muy largo (maximo %d caracteres)'):format(Settings.NameFilter.maxLength)
    end
    
    -- Alphanumeric check
    if Settings.NameFilter.blockNonAlphanumeric then
        if not name:match('^[%w%s_%-]+$') then
            return false, 'Solo se permiten letras, numeros y espacios'
        end
    end
    
    -- Blacklisted words check
    local nameLower = name:lower()
    for _, word in ipairs(Settings.NameFilter.blacklistedWords) do
        if nameLower:find(word:lower()) then
            return false, 'Nombre contiene palabras prohibidas'
        end
    end
    
    return true, nil
end
-- -----------------------------------------------------------------------------
-- MAIN DEFERRAL HANDLER
-- -----------------------------------------------------------------------------

--- Process connection deferrals
---@param source number
---@param name string
---@param deferrals table
function ConnectionSecurity.ProcessConnection(source, name, deferrals)
    deferrals.defer()
    Wait(0)
    
    local playerName = name or 'Unknown'
    
    -- Update deferral message
    deferrals.update('Verificando conexion...')
    Wait(100)
    
    -- Get identifiers
    local identifiers = {}
    local numIds = GetNumPlayerIdentifiers(source)
    
    for i = 0, numIds - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id then
            local idType = id:match('^(%w+):')
            if idType then
                identifiers[idType] = id
            end
        end
    end
    
    -- Check minimum identifiers
    local idCount = 0
    for _ in pairs(identifiers) do
        idCount = idCount + 1
    end
    
    if idCount < Settings.MinIdentifiers then
        deferrals.done(('Identifiers insuficientes. Necesitas al menos %d (tienes %d)'):format(
            Settings.MinIdentifiers, idCount
        ))
        return
    end
    
    -- Check name filter
    deferrals.update('Verificando nombre...')
    Wait(100)
    
    local nameValid, nameReason = ValidateName(playerName)
    if not nameValid then
        deferrals.done('Acceso denegado: ' .. Settings.NameFilter.rejectMessage .. '\n\n' .. (nameReason or ''))
        return
    end
    
    -- Check existing ban
    deferrals.update('Verificando bans...')
    Wait(100)
    
    local isBanned, banData = false, nil
    if exports['lyx-guard'] and exports['lyx-guard'].CheckPlayerBan then
        local ok, b, d = pcall(function()
            return exports['lyx-guard']:CheckPlayerBan(source)
        end)
        if ok then
            isBanned, banData = b, d
        end
    end
    if isBanned then
        local banMessage = [[
BANEADO

Razon: %s
Fecha: %s
Expira: %s

Apelacion: Discord del servidor]]

        deferrals.done(banMessage:format(
            banData.reason or 'No reason',
            banData.ban_date or 'Unknown',
            banData.permanent == 1 and 'Permanente' or (banData.unban_date or 'Unknown')
        ))
        return
    end
    
    -- Check VPN (async)
    if Settings.AntiVPN.enabled and identifiers.ip then
        deferrals.update('Verificando IP...')
        
        local vpnCheckDone = false
        local isVPN = false
        local country = nil
        
        CheckVPN(identifiers.ip, function(vpn, ctry)
            isVPN = vpn
            country = ctry
            vpnCheckDone = true
        end)
        
        -- Wait for VPN check (max 5 seconds)
        local timeout = 0
        while not vpnCheckDone and timeout < 50 do
            Wait(100)
            timeout = timeout + 1
        end
        
        if isVPN then
            deferrals.done('Acceso denegado: ' .. Settings.AntiVPN.rejectMessage)
            return
        end
    end
    
    -- Check VAC ban (async)
    if Settings.VACBanCheck.enabled and identifiers.steam then
        deferrals.update('Verificando Steam...')
        
        local vacCheckDone = false
        local isVACBanned = false
        
        CheckVACBan(identifiers.steam, function(banned)
            isVACBanned = banned
            vacCheckDone = true
        end)
        
        -- Wait for VAC check (max 5 seconds)
        local timeout = 0
        while not vacCheckDone and timeout < 50 do
            Wait(100)
            timeout = timeout + 1
        end
        
        if isVACBanned then
            deferrals.done('Acceso denegado: ' .. Settings.VACBanCheck.rejectMessage)
            return
        end
    end
    
    -- All checks passed
    deferrals.update('Conexion verificada')
    Wait(500)
    deferrals.done()
end
-- -----------------------------------------------------------------------------
-- INITIALIZATION
-- -----------------------------------------------------------------------------

--- Initialize with config
---@param config table
function ConnectionSecurity.Init(config)
    if config and config.Connection then
        if config.Connection.AntiVPN then
            for k, v in pairs(config.Connection.AntiVPN) do
                Settings.AntiVPN[k] = v
            end
        end
        if config.Connection.VACBanCheck then
            for k, v in pairs(config.Connection.VACBanCheck) do
                Settings.VACBanCheck[k] = v
            end
        end
        if config.Connection.NameFilter then
            for k, v in pairs(config.Connection.NameFilter) do
                Settings.NameFilter[k] = v
            end
        end
        if config.Connection.MinIdentifiers then
            Settings.MinIdentifiers = config.Connection.MinIdentifiers
        end
        if config.Connection.HideIP ~= nil then
            Settings.HideIP = config.Connection.HideIP
        end
    end
    
    print('^2[LyxGuard]^7 Connection Security initialized')
    print(('  Anti-VPN: %s | VAC Check: %s | Name Filter: %s'):format(
        Settings.AntiVPN.enabled and 'ON' or 'OFF',
        Settings.VACBanCheck.enabled and 'ON' or 'OFF',
        Settings.NameFilter.enabled and 'ON' or 'OFF'
    ))
end

-- Register connection handler
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local source = source
    ConnectionSecurity.ProcessConnection(source, name, deferrals)
end)

-- Initialize on start
CreateThread(function()
    Wait(1000)
    ConnectionSecurity.Init(Config)
end)

return ConnectionSecurity




