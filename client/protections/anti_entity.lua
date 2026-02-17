--[[
    LyxGuard - Anti-Entity Spawn Protection
    v2: Budgets per time-window + repeated model detection + progressive escalation.

    Notes:
    - Client-side is best-effort only. Real enforcement is server-side via entityCreating.
    - This module focuses on fast local cleanup + telemetry.
]]

local Protection = {}
Protection.Name = "Anti-EntitySpawn"
Protection.Enabled = true

-- Local references
local GetGameTimer = GetGameTimer
local GetEntityModel = GetEntityModel
local DeleteEntity = DeleteEntity
local DoesEntityExist = DoesEntityExist
local GetHashKey = GetHashKey
local GetEntityType = GetEntityType
local NetworkGetEntityOwner = NetworkGetEntityOwner
local PlayerId = PlayerId
local GetEntityCoords = GetEntityCoords

-- Runtime state (per-client, per-window)
local State = {
    windowStart = 0,
    counts = { vehicles = 0, peds = 0, objects = 0 },
    models = {}, -- [modelHash] = count
    strikes = 0,
    lastStrike = 0,
    lastReport = 0,
}

-- Callback
Protection.OnDetection = nil

-- Blacklisted peds (problematic/exploit peds)
local BLACKLISTED_PEDS = {}
local BLACKLISTED_PED_MODELS = {
    { model = 'a_m_m_acult_01', label = 'Altruist Cult' },
    { model = 'a_m_y_acult_02', label = 'Altruist Cult 2' },
    { model = 'a_m_o_acult_01', label = 'Altruist Cult Old' },
    { model = 'a_m_y_acult_01', label = 'Altruist Cult Young' },
    { model = 'u_m_y_juggernaut_01', label = 'Juggernaut' },
    { model = 's_m_y_clown_01', label = 'Clown' },
    { model = 's_m_m_movalien_01', label = 'Alien' },
    { model = 'a_c_chimp', label = 'Chimp' },
    { model = 'a_c_chop', label = 'Chop' },
    { model = 'a_c_husky', label = 'Husky' },
    { model = 'a_c_pug', label = 'Pug' },
    { model = 'a_c_rottweiler', label = 'Rottweiler' },
}

for _, p in ipairs(BLACKLISTED_PED_MODELS) do
    BLACKLISTED_PEDS[GetHashKey(p.model)] = p.label
end

-- Blacklisted objects (exploit objects)
local BLACKLISTED_OBJECTS = {}
local BLACKLISTED_OBJECT_MODELS = {
    { model = 'prop_beach_fire', label = 'Beach Fire' },
    { model = 'prop_carcreeper', label = 'Car Creeper' },
    { model = 'prop_cj_big_boat', label = 'Big Boat' },
    { model = 'prop_gold_cont_01', label = 'Gold Container' },
    { model = 'prop_steps_big_01', label = 'Big Steps' },
    { model = 'des_tankerexplosion_01', label = 'Tanker Explosion 1' },
    { model = 'des_tankerexplosion_02', label = 'Tanker Explosion 2' },
}

for _, o in ipairs(BLACKLISTED_OBJECT_MODELS) do
    BLACKLISTED_OBJECTS[GetHashKey(o.model)] = o.label
end

local function GetFirewallCfg()
    return Config and Config.Entities and Config.Entities.entityFirewall or nil
end

local function ResetWindow(now)
    State.windowStart = now
    State.counts.vehicles = 0
    State.counts.peds = 0
    State.counts.objects = 0
    State.models = {}
end

local function AddStrike(now, add)
    add = tonumber(add) or 1
    if add < 1 then add = 1 end

    local decayMs = 60000
    local cfg = GetFirewallCfg()
    if cfg and cfg.strikes and cfg.strikes.decayMs then
        decayMs = tonumber(cfg.strikes.decayMs) or decayMs
    end

    if State.strikes > 0 and State.lastStrike > 0 and (now - State.lastStrike) > decayMs then
        State.strikes = math.max(0, State.strikes - 1)
    end

    State.strikes = State.strikes + add
    State.lastStrike = now
end

local function MaybeReport(now, kind, data)
    -- Avoid spamming detections (client-side telemetry only)
    if (now - (State.lastReport or 0)) < 2000 then
        return
    end
    State.lastReport = now

    if Protection.OnDetection then
        Protection.OnDetection('entity_firewall', kind, 'WARN')
    end

    -- Also report to server (best-effort); server-side entityCreating is authoritative.
    local ped = PlayerPedId()
    local coords = ped and ped ~= 0 and GetEntityCoords(ped) or nil
    TriggerServerEvent('lyxguard:detection', 'entity_firewall', {
        kind = kind,
        data = data,
        strikes = State.strikes,
        ts = now,
    }, coords and { x = coords.x, y = coords.y, z = coords.z } or nil)
end

-- Check for entity creation (client-side)
function Protection.OnEntityCreated(entity, entityType)
    if not Protection.Enabled then return true end
    if not entity or entity == 0 or not DoesEntityExist(entity) then return true end

    -- Only track entities owned by this client (per-player budget)
    if NetworkGetEntityOwner and NetworkGetEntityOwner(entity) ~= PlayerId() then
        return true
    end

    local cfg = GetFirewallCfg()
    if not cfg or cfg.enabled ~= true then
        return true
    end

    local now = GetGameTimer()
    local windowMs = tonumber(cfg.windowMs) or 10000
    if State.windowStart == 0 or (now - State.windowStart) > windowMs then
        ResetWindow(now)
    end

    local model = GetEntityModel(entity)
    local kind = nil
    local strikeAdd = 1

    if entityType == 1 then
        State.counts.peds = State.counts.peds + 1

        if BLACKLISTED_PEDS[model] then
            kind = 'blacklisted_ped'
            strikeAdd = 2
        else
            local limit = cfg.budgets and tonumber(cfg.budgets.peds) or nil
            if limit and State.counts.peds > limit then
                kind = 'ped_budget'
            end
        end
    elseif entityType == 2 then
        State.counts.vehicles = State.counts.vehicles + 1

        local limit = cfg.budgets and tonumber(cfg.budgets.vehicles) or nil
        if limit and State.counts.vehicles > limit then
            kind = 'vehicle_budget'
        end
    elseif entityType == 3 then
        State.counts.objects = State.counts.objects + 1

        if BLACKLISTED_OBJECTS[model] then
            kind = 'blacklisted_object'
            strikeAdd = 2
        else
            local limit = cfg.budgets and tonumber(cfg.budgets.objects) or nil
            if limit and State.counts.objects > limit then
                kind = 'object_budget'
            end
        end
    else
        return true
    end

    local maxSame = tonumber(cfg.maxSameModel) or 0
    if not kind and maxSame > 0 then
        State.models[model] = (State.models[model] or 0) + 1
        if State.models[model] > maxSame then
            kind = 'repeated_model'
        end
    end

    if not kind then
        return true
    end

    AddStrike(now, strikeAdd)

    -- Local cleanup
    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end

    MaybeReport(now, kind, {
        entityType = entityType,
        model = model,
        counts = State.counts,
        sameModel = State.models[model],
        windowMs = windowMs
    })

    return false
end

-- Add to blacklists
function Protection.AddBlacklistedPed(hash, name)
    BLACKLISTED_PEDS[hash] = name
end

function Protection.AddBlacklistedObject(hash, name)
    BLACKLISTED_OBJECTS[hash] = name
end

-- Initialize
function Protection.Init(config)
    Protection.Enabled = true
    print('^2[LyxGuard]^7 Anti-EntitySpawn protection initialized')
end

-- No continuous run - event-based
function Protection.Run() end

-- Hook entity creation events
AddEventHandler('entityCreated', function(entity)
    if not Protection.Enabled then return end
    if not entity or entity == 0 then return end
    local t = GetEntityType(entity)
    Protection.OnEntityCreated(entity, t)
end)

-- Self-register
CreateThread(function()
    Wait(100)
    if RegisterProtectionModule then
        RegisterProtectionModule('anti_entity', Protection)
        return
    end
    if exports['lyx-guard'] and exports['lyx-guard'].RegisterProtection then
        exports['lyx-guard']:RegisterProtection('anti_entity', Protection)
    end
end)

return Protection
