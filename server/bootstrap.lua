--[[
    LyxGuard - Server Bootstrap (Security/Init Helpers)

    Goals:
    - Centralize ESX retrieval
    - Block dangerous dynamic code execution patterns (load/loadstring)
    - Provide lightweight dependency helpers (lyx-panel optional)
]]

LyxGuard = LyxGuard or {}
LyxGuard.Bootstrap = LyxGuard.Bootstrap or {}

local _warnOnce = {}
local function WarnOnce(key, msg)
    if _warnOnce[key] then return end
    _warnOnce[key] = true
    print(msg)
end

-- ---------------------------------------------------------------------------
-- Hardening: block dynamic code execution inside this resource environment
-- ---------------------------------------------------------------------------

local function _BlockedDynamicCode()
    error('[LyxGuard][SECURITY] Dynamic code execution is disabled (load/loadstring).', 2)
end

if type(_G.load) == 'function' then
    _G.load = _BlockedDynamicCode
end
if type(_G.loadstring) == 'function' then
    _G.loadstring = _BlockedDynamicCode
end
if type(_G.loadfile) == 'function' then
    _G.loadfile = _BlockedDynamicCode
end
if type(_G.dofile) == 'function' then
    _G.dofile = _BlockedDynamicCode
end

-- ---------------------------------------------------------------------------
-- ESX Helper (@es_extended/imports.lua should provide ESX, keep safe fallback)
-- ---------------------------------------------------------------------------

function LyxGuard.GetESX()
    if ESX then return ESX end
    if _G.ESX then
        ESX = _G.ESX
        return ESX
    end

    if GetResourceState('es_extended') == 'started' then
        local ok, obj = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and obj then
            ESX = obj
            _G.ESX = obj
            return ESX
        end
    end

    return nil
end

function LyxGuard.WaitForESX(timeoutMs)
    timeoutMs = tonumber(timeoutMs) or 15000
    local deadline = GetGameTimer() + timeoutMs

    while not LyxGuard.GetESX() do
        if GetGameTimer() > deadline then
            WarnOnce('esx_timeout', '^1[LyxGuard]^7 ESX no disponible (timeout). Revisa que `es_extended` este started.')
            return nil
        end
        Wait(200)
    end

    return ESX
end

-- ---------------------------------------------------------------------------
-- Optional dependency checks
-- ---------------------------------------------------------------------------

function LyxGuard.IsResourceStarted(name)
    return GetResourceState(name) == 'started'
end

function LyxGuard.IsLyxPanelAvailable()
    return GetResourceState('lyx-panel') == 'started'
end

CreateThread(function()
    Wait(2000)
    if not LyxGuard.IsLyxPanelAvailable() then
        WarnOnce('dep_lyxpanel_boot',
            '^3[LyxGuard]^7 lyx-panel no esta iniciado. Integracion de panel y telemetria cruzada quedaran deshabilitadas.')
    end
end)

print('^2[LyxGuard]^7 bootstrap loaded')
