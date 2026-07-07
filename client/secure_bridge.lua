--[[
    LyxGuard - Secure Event Bridge (CLIENT)

    License: MIT

    Espejo cliente del intercomunicador seguro. Guarda la key emitida por el
    servidor y firma cada evento con HMAC-SHA256 + nonce, adjuntando el sobre
    { __lyxbridge = { nonce, seq, ts, sig } } como ultimo argumento.

    API:
        exports['lyx-guard']:TriggerSecureServerEvent('evento', ...)
]]

local bridge = {
    enabled = false,
    key = nil,
    nonceCounter = 0,
    seq = 0,
}
local _randSeeded = false

local function _SeedRandom()
    if _randSeeded then return end
    local seed = GetGameTimer() + math.floor((GetFrameTime() or 0.0) * 1000000) + GetPlayerServerId(PlayerId())
    math.randomseed(seed)
    for _ = 1, 8 do math.random() end
    _randSeeded = true
end

local function _TimestampMs()
    if type(GetCloudTimeAsInt) == 'function' then
        local ok, cloudTime = pcall(GetCloudTimeAsInt)
        cloudTime = tonumber(cloudTime)
        if ok and cloudTime and cloudTime > 0 then
            return cloudTime * 1000
        end
    end
    return 0
end

-- Must match server/secure_bridge.lua _BuildSigningString exactly.
local function _BuildSigningString(eventName, seq, nonce, ts, args)
    local ok, argsJson = pcall(json.encode, args or {})
    if not ok or type(argsJson) ~= 'string' then
        argsJson = ''
    end
    local argsHash = LyxSHA2.sha256(argsJson)
    return table.concat({ tostring(eventName), tostring(seq), tostring(nonce), tostring(ts), argsHash }, '|')
end

local function _SetKey(data)
    if type(data) ~= 'table' or data.enabled == false or type(data.key) ~= 'string' or data.key == '' then
        bridge.enabled = false
        bridge.key = nil
        bridge.nonceCounter = 0
        bridge.seq = 0
        return
    end

    bridge.enabled = true
    bridge.key = data.key
    bridge.nonceCounter = 0
    bridge.seq = 0
end

RegisterNetEvent('lyxguard:bridge:key', function(data)
    _SetKey(data)
end)

---Trigger a server event through the secure bridge (signed + anti-replay).
---Falls back to a plain TriggerServerEvent if the bridge isn't ready yet
---(the server will simply reject it as unsigned, which is the safe default for
---sensitive events).
local function TriggerSecureServerEvent(eventName, ...)
    _SeedRandom()

    if bridge.enabled ~= true or type(bridge.key) ~= 'string' then
        -- No key yet: request one and send unsigned (server decides how to treat it).
        TriggerServerEvent('lyxguard:bridge:requestKey')
        TriggerServerEvent(eventName, ...)
        return
    end

    local args = { ... }

    bridge.nonceCounter = bridge.nonceCounter + 1
    bridge.seq = bridge.seq + 1

    local now = GetGameTimer()
    local nonce = ('%d-%d-%d'):format(math.random(100000, 999999), now, bridge.nonceCounter)
    local ts = _TimestampMs()
    local seq = bridge.seq

    local sig = LyxSHA2.hmac_sha256(bridge.key, _BuildSigningString(eventName, seq, nonce, ts, args))

    args[#args + 1] = {
        __lyxbridge = {
            nonce = nonce,
            seq = seq,
            ts = ts,
            sig = sig
        }
    }

    TriggerServerEvent(eventName, table.unpack(args))
end

exports('TriggerSecureServerEvent', TriggerSecureServerEvent)
_G.LyxTriggerSecureServerEvent = TriggerSecureServerEvent

-- Ask for a key on startup (and after resource restart).
CreateThread(function()
    -- Small delay so the server side is ready.
    Wait(2000)
    TriggerServerEvent('lyxguard:bridge:requestKey')
end)

print('^2[LyxGuard]^7 Secure Event Bridge loaded (HMAC + nonce, Client-Side)')
