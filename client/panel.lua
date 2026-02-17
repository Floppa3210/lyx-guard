--[[
    LyxGuard v4.0 - Client Panel Handler
    NUI communication for anticheat panel
]]

local isPanelOpen = false
local panelSecurity = {
    enabled = false,
    token = nil,
    nonceCounter = 0,
}
local _randSeeded = false

local function _SetPanelSecurity(sec)
    if type(sec) ~= 'table' then
        panelSecurity.enabled = false
        panelSecurity.token = nil
        panelSecurity.nonceCounter = 0
        return
    end

    panelSecurity.enabled = sec.enabled == true and type(sec.token) == 'string' and sec.token ~= ''
    panelSecurity.token = panelSecurity.enabled and sec.token or nil
    panelSecurity.nonceCounter = 0
end

local function _GenerateSecurityEnvelope(eventName)
    if not _randSeeded then
        local seed = GetGameTimer() + math.floor((GetFrameTime() or 0.0) * 1000000) + GetPlayerServerId(PlayerId())
        math.randomseed(seed)
        for _ = 1, 8 do math.random() end
        _randSeeded = true
    end

    if panelSecurity.enabled ~= true or type(panelSecurity.token) ~= 'string' or panelSecurity.token == '' then
        return nil
    end

    panelSecurity.nonceCounter = (tonumber(panelSecurity.nonceCounter) or 0) + 1
    local now = GetGameTimer()
    local nonce = ('%d-%d-%d'):format(math.random(100000, 999999), now, panelSecurity.nonceCounter)
    local correlationId = ('lg-%d-%d-%d'):format(GetPlayerServerId(PlayerId()), now, panelSecurity.nonceCounter)

    return {
        __lyxsec = {
            token = panelSecurity.token,
            nonce = nonce,
            correlation_id = correlationId,
            ts = os.time() * 1000,
            event = tostring(eventName or '')
        }
    }
end

local function SendSecurePanelEvent(eventName, ...)
    local args = { ... }
    local env = _GenerateSecurityEnvelope(eventName)
    if env then
        args[#args + 1] = env
    end
    TriggerServerEvent(eventName, table.unpack(args))
end

-- -------------------------------------------------------------------------------
-- KEY BINDING
-- -------------------------------------------------------------------------------

RegisterCommand('lyxguard', function()
    if isPanelOpen then
        closePanelUI()
    else
        openPanelUI()
    end
end, false)

RegisterKeyMapping('lyxguard', 'Abrir Panel LyxGuard', 'keyboard', 'F8')

-- -------------------------------------------------------------------------------
-- PANEL TOGGLE
-- -------------------------------------------------------------------------------

RegisterNetEvent('lyxguard:panel:toggle', function()
    if isPanelOpen then
        closePanelUI()
    else
        openPanelUI()
    end
end)

RegisterNetEvent('lyxguard:panel:openUI', function(data)
    SetNuiFocus(true, true)
    isPanelOpen = true
    _SetPanelSecurity(data and data.security or nil)

    SendNUIMessage({
        action = 'open',
        config = data.config,
        stats = data.stats,
        recentEvents = data.recentEvents
    })
end)

function openPanelUI()
    if isPanelOpen then return end -- Prevent double open
    TriggerServerEvent('lyxguard:panel:open')
end

function closePanelUI()
    if not isPanelOpen then return end -- Prevent double close
    SetNuiFocus(false, false)
    isPanelOpen = false
    _SetPanelSecurity(nil)
    SendNUIMessage({ action = 'close' })
    SendSecurePanelEvent('lyxguard:panel:close')
end

-- -------------------------------------------------------------------------------
-- NUI CALLBACKS
-- -------------------------------------------------------------------------------

RegisterNUICallback('close', function(data, cb)
    closePanelUI()
    cb({})
end)

RegisterNUICallback('getStats', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:getStats', function(stats)
        cb(stats or {})
    end)
end)

RegisterNUICallback('getRecentActivity', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:getRecentActivity', function(result)
        cb(result or { events = {} })
    end)
end)

RegisterNUICallback('getDetections', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:getDetections', function(result)
        cb(result or { detections = {} })
    end, data)
end)

RegisterNUICallback('getBans', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:getBans', function(result)
        cb(result or { bans = {} })
    end, data)
end)

RegisterNUICallback('getWarnings', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:getWarnings', function(result)
        cb(result or { warnings = {} })
    end)
end)

RegisterNUICallback('getSuspicious', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:getSuspicious', function(result)
        cb(result or { players = {} })
    end)
end)

RegisterNUICallback('getPlayerDetails', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:getPlayerDetails', function(result)
        cb(result or {})
    end, data)
end)

RegisterNUICallback('unban', function(data, cb)
    SendSecurePanelEvent('lyxguard:panel:unban', data)
    cb({})
end)

RegisterNUICallback('removeWarning', function(data, cb)
    SendSecurePanelEvent('lyxguard:panel:removeWarning', data)
    cb({})
end)

RegisterNUICallback('banPlayer', function(data, cb)
    SendSecurePanelEvent('lyxguard:panel:banPlayer', data)
    cb({})
end)

RegisterNUICallback('saveWebhooks', function(data, cb)
    SendSecurePanelEvent('lyxguard:panel:saveWebhooks', data)
    cb({})
end)

RegisterNUICallback('clearAllLogs', function(data, cb)
    SendSecurePanelEvent('lyxguard:panel:clearAllLogs')
    cb({})
end)

RegisterNUICallback('clearPlayerLogs', function(data, cb)
    SendSecurePanelEvent('lyxguard:panel:clearPlayerLogs', data.identifier)
    cb({})
end)

RegisterNUICallback('clearPlayerWarnings', function(data, cb)
    SendSecurePanelEvent('lyxguard:panel:clearPlayerWarnings', data.identifier)
    cb({})
end)

RegisterNUICallback('clearOldLogs', function(data, cb)
    SendSecurePanelEvent('lyxguard:panel:clearOldLogs', data.days)
    cb({})
end)

-- Callback para borrar una detección específica por ID
RegisterNUICallback('clearDetection', function(data, cb)
    if data and data.id then
        SendSecurePanelEvent('lyxguard:panel:clearDetection', data.id)
    end
    cb({})
end)

-- -------------------------------------------------------------------------------
-- REAL-TIME EVENTS
-- -------------------------------------------------------------------------------

RegisterNetEvent('lyxguard:panel:newEvent', function(event)
    if isPanelOpen then
        SendNUIMessage({
            action = 'newEvent',
            event = event
        })
    end
end)

-- Notification from system
RegisterNetEvent('lyxguard:notify', function(a, b)
    if not isPanelOpen then return end

    -- Support both legacy (type, message) and modern ({type=..., message=...}) formats.
    local t = a
    local msg = b
    if type(a) == 'table' then
        t = a.type
        msg = a.message
    end

    SendNUIMessage({
        action = tostring(t or 'info'),
        message = tostring(msg or '')
    })
end)

-- -------------------------------------------------------------------------------
-- ADMIN CONFIG NUI CALLBACKS
-- -------------------------------------------------------------------------------

-- Whitelist Management
RegisterNUICallback('getWhitelist', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:getWhitelist', function(result)
        cb(result or { whitelist = {} })
    end)
end)

RegisterNUICallback('addToWhitelist', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:addToWhitelist', function(result)
        cb(result or { success = false })
    end, data)
end)

RegisterNUICallback('removeFromWhitelist', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:removeFromWhitelist', function(result)
        cb(result or { success = false })
    end, data)
end)

-- Immune Groups
RegisterNUICallback('getImmuneGroups', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:getImmuneGroups', function(result)
        cb(result or { groups = {} })
    end)
end)

RegisterNUICallback('saveImmuneGroups', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:saveImmuneGroups', function(result)
        cb(result or { success = false })
    end, data)
end)

-- VIP Settings
RegisterNUICallback('saveVipSettings', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:saveVipSettings', function(result)
        cb(result or { success = false })
    end, data)
end)

-- Detection Settings
RegisterNUICallback('getDetectionSettings', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:getDetectionSettings', function(result)
        cb(result or { detections = {} })
    end)
end)

RegisterNUICallback('saveDetectionSettings', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:saveDetectionSettings', function(result)
        cb(result or { success = false })
    end, data)
end)

RegisterNUICallback('resetDetectionDefaults', function(data, cb)
    ESX.TriggerServerCallback('lyxguard:panel:resetDetectionDefaults', function(result)
        cb(result or { success = false })
    end)
end)

print('[LyxGuard] Panel client module loaded')
