--[[
    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║                           LYXGUARD v4.0 PROFESSIONAL                         ║
    ║                         Modular Detection Core                                ║
    ╠═══════════════════════════════════════════════════════════════════════════════╣
    ║  Author: LyxDev                                                               ║
    ║  License: Commercial                                                          ║
    ║  Purpose: Client-side detection API and helper utilities                      ║
    ║                                                                               ║
    ║  USAGE: To add a new detection, create a file in client/detections/          ║
    ║         and call RegisterDetection() with config and handler                  ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- MODULE INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════════

---@class DetectionCore
-- IMPORTANT: DetectionCore is GLOBAL so it can be accessed by main.lua and other modules
DetectionCore = DetectionCore or {}

-- Private registries
local Registry = {
    detections = {},  -- [name] = {handler, defaultConfig, enabled}
    configs = {},     -- [name] = merged config from server
    states = {},      -- [name] = {violations, lastTrigger, data}
    groups = {        -- Detection groups by check interval
        fast = {},    -- 100ms checks (movement, critical)
        normal = {},  -- 500ms checks (combat, entities)
        slow = {},    -- 2000ms checks (advanced, resources)
        periodic = {} -- 30000ms checks (background scans)
    }
}

-- Player state (shared with detections)
PlayerState = {
    immune = false,
    inGracePeriod = true,
    frozen = false,
    dead = false,
    lastPos = nil,
    lastHealth = 200,
    lastArmor = 0,
    lastWeapon = nil,
    spawnTime = 0,
    lastVehicle = nil,
    lastSpeed = 0
}

-- Detection groups by interval (configurable per detection)
local GROUP_INTERVALS = {
    fast = 100,
    normal = 500,
    slow = 2000,
    periodic = 30000
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- DETECTION REGISTRATION API
-- ═══════════════════════════════════════════════════════════════════════════════

---Register a new detection module
---@param name string Unique detection identifier
---@param defaultConfig table Default configuration
---@param handler function Detection handler(config, state, helpers) -> boolean, details
---@param group? string Check interval group: 'fast', 'normal', 'slow', 'periodic'
function DetectionCore.Register(name, defaultConfig, handler, group)
    -- Validation
    if type(name) ~= 'string' or #name == 0 then
        print('^1[LyxGuard]^7 RegisterDetection: Invalid name')
        return false
    end

    if type(handler) ~= 'function' then
        print('^1[LyxGuard]^7 RegisterDetection: Handler must be a function')
        return false
    end

    -- Store detection
    Registry.detections[name] = {
        name = name,
        handler = handler,
        defaultConfig = defaultConfig or {},
        enabled = true
    }

    -- Initialize state
    Registry.states[name] = {
        violations = 0,
        lastTrigger = 0,
        lastCheck = 0,
        data = {}
    }

    -- Add to appropriate group
    group = group or 'normal'
    if not Registry.groups[group] then
        group = 'normal'
    end
    table.insert(Registry.groups[group], name)

    if Config and Config.Debug then
        print(string.format('^2[LyxGuard]^7 Detection registered: %s (group: %s)', name, group))
    end

    return true
end

-- Global alias for backwards compatibility
RegisterDetection = function(name, config, handler, group)
    -- If group is provided directly as 4th arg, use it
    -- Otherwise determine group from checkInterval if specified
    if not group and config and config.checkInterval then
        if config.checkInterval <= 100 then
            group = 'fast'
        elseif config.checkInterval <= 500 then
            group = 'normal'
        elseif config.checkInterval <= 2000 then
            group = 'slow'
        else
            group = 'periodic'
        end
    end
    return DetectionCore.Register(name, config, handler, group or 'normal')
end

---Enable or disable a detection at runtime
---@param name string Detection name
---@param enabled boolean
function DetectionCore.SetEnabled(name, enabled)
    if Registry.detections[name] then
        Registry.detections[name].enabled = enabled
        if Config and Config.Debug then
            print(string.format('^3[LyxGuard]^7 Detection %s: %s', name, enabled and 'ENABLED' or 'DISABLED'))
        end
    end
end

-- Global alias
SetDetectionEnabled = DetectionCore.SetEnabled

---Get detection state
---@param name string
---@return table
function DetectionCore.GetState(name)
    return Registry.states[name] or {}
end

GetDetectionState = DetectionCore.GetState

---Reset violations for a detection
---@param name string
function DetectionCore.ResetViolations(name)
    if Registry.states[name] then
        Registry.states[name].violations = 0
    end
end

ResetDetectionViolations = DetectionCore.ResetViolations

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONFIGURATION MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════════

---Set server-provided config for detections
---@param configs table Dictionary of detection configs
function DetectionCore.SetConfigs(configs)
    if type(configs) ~= 'table' then return end
    Registry.configs = configs
end

---Get merged config for a detection
---@param name string
---@return table
function DetectionCore.GetConfig(name)
    local serverCfg = Registry.configs[name] or {}
    local defaultCfg = Registry.detections[name] and Registry.detections[name].defaultConfig or {}

    -- Merge: server config overrides defaults
    local merged = {}
    for k, v in pairs(defaultCfg) do merged[k] = v end
    for k, v in pairs(serverCfg) do merged[k] = v end

    return merged
end

-- Global aliases
DetectionConfigs = Registry.configs
GetDetectionConfig = DetectionCore.GetConfig
Detections = Registry.detections
DetectionStates = Registry.states

-- ═══════════════════════════════════════════════════════════════════════════════
-- DETECTION EXECUTION
-- ═══════════════════════════════════════════════════════════════════════════════

---Run a single detection
---@param name string
---@return boolean triggered
function DetectionCore.Run(name)
    local det = Registry.detections[name]
    if not det or not det.enabled then return false end

    local config = DetectionCore.GetConfig(name)
    if config.enabled == false then return false end

    -- Skip if in grace period and detection doesn't ignore it
    if PlayerState.inGracePeriod and not config.ignoreGracePeriod then
        return false
    end

    -- Skip if immune
    if PlayerState.immune then return false end

    local state = Registry.states[name]

    -- Execute handler with error protection
    local success, triggered, details = pcall(det.handler, config, state, Helpers)

    if not success then
        if Config and Config.Debug then
            print(string.format('^1[LyxGuard]^7 Detection error (%s): %s', name, tostring(triggered)))
        end
        return false
    end

    if triggered then
        state.violations = state.violations + 1
        state.lastTrigger = GetGameTimer()

        -- Check threshold
        local threshold = config.tolerance or config.threshold or 1
        if state.violations >= threshold then
            DetectionCore.Trigger(name, details or {}, config)
            state.violations = 0
        end
    else
        -- Decay violations over time
        local decayTime = config.decayTime or 10000
        if GetGameTimer() - state.lastTrigger > decayTime and state.violations > 0 then
            state.violations = math.max(0, state.violations - 1)
            state.lastTrigger = GetGameTimer()
        end
    end

    return triggered
end

-- Global alias
RunDetection = DetectionCore.Run

---Trigger detection event to server
---@param name string
---@param details table
---@param config table
function DetectionCore.Trigger(name, details, config)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    details = details or {}
    details.detection = name
    details.timestamp = GetGameTimer()
    details.playerPed = ped

    TriggerServerEvent('lyxguard:detection', name, details, {
        x = coords.x,
        y = coords.y,
        z = coords.z
    })

    if Config and Config.Debug then
        print(string.format('^3[LyxGuard]^7 Detection triggered: %s', name))
    end
end

TriggerDetection = DetectionCore.Trigger

-- ═══════════════════════════════════════════════════════════════════════════════
-- OPTIMIZED DETECTION LOOPS
-- ═══════════════════════════════════════════════════════════════════════════════

---Run all detections in a group
---@param group string
local function RunDetectionGroup(group)
    local detections = Registry.groups[group]
    if not detections then return end

    for _, name in ipairs(detections) do
        DetectionCore.Run(name)
    end
end

---Start consolidated detection loops
function DetectionCore.StartLoops()
    -- Fast detections (100ms) - Critical movement checks
    CreateThread(function()
        while true do
            Wait(GROUP_INTERVALS.fast)
            if not PlayerState.inGracePeriod and not PlayerState.immune then
                RunDetectionGroup('fast')

                -- Update player state
                local ped = PlayerPedId()
                PlayerState.lastPos = GetEntityCoords(ped)
                PlayerState.lastSpeed = GetEntitySpeed(ped)
            end
        end
    end)

    -- Normal detections (500ms) - Combat, entities
    CreateThread(function()
        while true do
            Wait(GROUP_INTERVALS.normal)
            if not PlayerState.inGracePeriod and not PlayerState.immune then
                RunDetectionGroup('normal')

                -- Update combat state
                local ped = PlayerPedId()
                PlayerState.lastHealth = GetEntityHealth(ped)
                PlayerState.lastArmor = GetPedArmour(ped)
                PlayerState.dead = IsEntityDead(ped)
            end
        end
    end)

    -- Slow detections (2000ms) - Advanced checks
    CreateThread(function()
        while true do
            Wait(GROUP_INTERVALS.slow)
            if not PlayerState.inGracePeriod and not PlayerState.immune then
                RunDetectionGroup('slow')
            end
        end
    end)

    -- Periodic detections (30000ms) - Background scans
    CreateThread(function()
        while true do
            Wait(GROUP_INTERVALS.periodic)
            RunDetectionGroup('periodic')
        end
    end)

    if Config and Config.Debug then
        print('^2[LyxGuard]^7 Detection loops started (4 consolidated threads)')
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS FOR DETECTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

---@class Helpers
Helpers = {}

function Helpers.IsInGracePeriod()
    return PlayerState.inGracePeriod
end

function Helpers.GetPlayerSpeed()
    return GetEntitySpeed(PlayerPedId())
end

function Helpers.GetDistanceFromLast()
    if not PlayerState.lastPos then return 0 end
    local pos = GetEntityCoords(PlayerPedId())
    return #(pos - PlayerState.lastPos)
end

function Helpers.IsInVehicle()
    return IsPedInAnyVehicle(PlayerPedId(), false)
end

function Helpers.GetVehicle()
    return GetVehiclePedIsIn(PlayerPedId(), false)
end

function Helpers.IsOnGround()
    local ped = PlayerPedId()
    -- IsPedOnGround doesn't exist, use GetEntityHeightAboveGround instead
    local heightAboveGround = GetEntityHeightAboveGround(ped)
    return heightAboveGround < 1.0 or IsPedClimbing(ped) or IsPedVaulting(ped)
end

function Helpers.IsFalling()
    return IsPedFalling(PlayerPedId())
end

function Helpers.IsSwimming()
    return IsPedSwimming(PlayerPedId())
end

function Helpers.IsClimbing()
    return IsPedClimbing(PlayerPedId())
end

function Helpers.HasParachute()
    return IsPedInParachuteFreeFall(PlayerPedId())
end

function Helpers.GetHeightAboveGround()
    local pos = GetEntityCoords(PlayerPedId())
    local success, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)
    if success then
        return pos.z - groundZ
    end
    return 0
end

function Helpers.IsScreenFaded()
    return IsScreenFadedOut() or IsScreenFadingOut()
end

function Helpers.IsPlayerDead()
    return IsEntityDead(PlayerPedId())
end

function Helpers.GetCurrentWeapon()
    local _, weapon = GetCurrentPedWeapon(PlayerPedId(), true)
    return weapon
end

function Helpers.IsPlayerImmune()
    return PlayerState.immune
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEBUG LOGGING
-- ═══════════════════════════════════════════════════════════════════════════════

function DebugLog(msg, ...)
    if LyxGuardLib and LyxGuardLib.Debug then
        LyxGuardLib.Debug(msg, ...)
    elseif Config and Config.Debug then
        print('^3[LyxGuard Debug]^7 ' .. string.format(msg, ...))
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- PROTECTION MODULE INTEGRATION
-- Bridge between ProtectionLoader (old system) and DetectionCore (new system)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Storage for protection modules that run their own loops
local ProtectionModules = {}

---Register a protection module and integrate it with the detection system
---@param name string Protection name (e.g., 'anti_godmode')
---@param protection table Protection module with Run, Init, etc.
function RegisterProtectionModule(name, protection)
    if not protection then return false end

    -- Store the protection module
    ProtectionModules[name] = protection

    -- Set up detection callback if not present
    if not protection.OnDetection then
        protection.OnDetection = function(detectionName, details, action)
            -- Send to server for processing
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            TriggerServerEvent('lyxguard:detection', detectionName, {
                details = details,
                action = action or 'WARN',
                timestamp = GetGameTimer()
            }, {
                x = coords.x,
                y = coords.y,
                z = coords.z
            })

            if Config and Config.Debug then
                print(('[^1LyxGuard^7] Detection from protection: %s'):format(detectionName))
            end
        end
    end

    -- Initialize with config if available
    if protection.Init and Config then
        protection.Init(Config)
    end

    if Config and Config.Debug then
        print(('[^2LyxGuard^7] Protection module registered: %s'):format(name))
    end

    return true
end

---Run all protection modules (called from main loop)
function RunProtectionModules()
    if PlayerState.immune or PlayerState.inGracePeriod then return end

    for name, protection in pairs(ProtectionModules) do
        if protection.Enabled and protection.Run then
            local success, err = pcall(protection.Run)
            if not success and Config and Config.Debug then
                print(('[^1LyxGuard^7] Protection error (%s): %s'):format(name, tostring(err)))
            end
        end
    end
end

---Get count of registered protections
function GetProtectionCount()
    local count = 0
    for _ in pairs(ProtectionModules) do count = count + 1 end
    return count
end


---List registered protection module names (sorted).
---@return string[] names
function GetProtectionNames()
    local out = {}
    for name in pairs(ProtectionModules) do
        out[#out + 1] = tostring(name)
    end
    table.sort(out)
    return out
end

---List registered detection names (sorted).
---@return string[] names
function DetectionCore.ListDetections()
    local out = {}
    for name in pairs(Registry.detections) do
        out[#out + 1] = tostring(name)
    end
    table.sort(out)
    return out
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- UNIFIED DETECTION LOOP (Runs both detection systems)
-- ═══════════════════════════════════════════════════════════════════════════════

function StartUnifiedDetectionLoops()
    -- Start the DetectionCore loops
    DetectionCore.StartLoops()

    -- Also run protection modules in a separate thread
    CreateThread(function()
        while true do
            Wait(100) -- Fast check loop for protections
            RunProtectionModules()
        end
    end)

    print('^2[LyxGuard]^7 Unified detection system started')
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MODULE READY
-- DetectionCore is now GLOBAL - no need to return
-- ═══════════════════════════════════════════════════════════════════════════════

print('^2[LyxGuard]^7 Detection Core loaded (GLOBAL)')

