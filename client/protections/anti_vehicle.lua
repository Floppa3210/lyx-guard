--[[
    LyxGuard - Anti-Vehicle Spawn Protection
    Detects players spawning blacklisted vehicles
    Based on FIREAC + Icarus detection logic
]]

local Protection = {}
Protection.Name = "Anti-VehicleSpawn"
Protection.Enabled = true

-- Local references
local GetGameTimer = GetGameTimer
local GetEntityModel = GetEntityModel
local GetVehiclePedIsIn = GetVehiclePedIsIn
local IsPedInAnyVehicle = IsPedInAnyVehicle
local PlayerPedId = PlayerPedId
local DeleteEntity = DeleteEntity
local DoesEntityExist = DoesEntityExist
local NetworkGetEntityOwner = NetworkGetEntityOwner
local PlayerId = PlayerId
local GetHashKey = GetHashKey

-- Configuration
local CHECK_INTERVAL = 3000 -- ms
local MAX_VEHICLES_PER_PLAYER = 5
local lastCheck = 0
local vehicleSpawnCounts = {}

-- Callback
Protection.OnDetection = nil

-- Blacklisted vehicles (from Icarus - military/OP vehicles)
local BLACKLISTED_VEHICLES = {}
local BLACKLISTED_VEHICLE_MODELS = {
    { model = 'apc', label = 'APC' },
    { model = 'rhino', label = 'Rhino Tank' },
    { model = 'khanjali', label = 'Khanjali Tank' },
    { model = 'hydra', label = 'Hydra Jet' },
    { model = 'lazer', label = 'P-996 Lazer' },
    { model = 'jet', label = 'Jet' },
    { model = 'hunter', label = 'Hunter Helicopter' },
    { model = 'savage', label = 'Savage Helicopter' },
    { model = 'akula', label = 'Akula Helicopter' },
    { model = 'valkyrie', label = 'Valkyrie' },
    { model = 'valkyrie2', label = 'Valkyrie (Armed)' },
    { model = 'buzzard', label = 'Buzzard' },
    { model = 'oppressor', label = 'Oppressor' },
    { model = 'oppressor2', label = 'Oppressor Mk II' },
    { model = 'vigilante', label = 'Vigilante' },
    { model = 'scramjet', label = 'Scramjet' },
    { model = 'ruiner2', label = 'Ruiner 2000' },
    { model = 'deluxo', label = 'Deluxo' },
    { model = 'stromberg', label = 'Stromberg' },
    { model = 'insurgent', label = 'Insurgent' },
    { model = 'insurgent2', label = 'Insurgent Pick-Up' },
    { model = 'insurgent3', label = 'Insurgent Pick-Up Custom' },
    { model = 'technical', label = 'Technical' },
    { model = 'technical2', label = 'Technical Aqua' },
    { model = 'technical3', label = 'Technical Custom' },
    { model = 'nightshark', label = 'Nightshark' },
    { model = 'halftrack', label = 'Half-track' },
    { model = 'barrage', label = 'Barrage' },
    { model = 'chernobog', label = 'Chernobog' },
    { model = 'thruster', label = 'Thruster Jetpack' },
    { model = 'avenger', label = 'Avenger' },
    { model = 'avenger2', label = 'Avenger (Interior)' },
    { model = 'bombushka', label = 'Bombushka' },
    { model = 'volatol', label = 'Volatol' },
    { model = 'alkonost', label = 'Alkonost' },
    { model = 'strikeforce', label = 'Strikeforce' },
    { model = 'kosatka', label = 'Kosatka' },
    { model = 'patrolboat', label = 'Patrol Boat' },
    { model = 'annihilator', label = 'Annihilator' },
    { model = 'annihilator2', label = 'Annihilator Stealth' },
    { model = 'minitank', label = 'Invade and Persuade Tank' },
    { model = 'raiju', label = 'Raiju' },
}

for _, v in ipairs(BLACKLISTED_VEHICLE_MODELS) do
    BLACKLISTED_VEHICLES[GetHashKey(v.model)] = v.label
end

-- Get hash for comparison
local function GetModelHash(modelName)
    return GetHashKey(modelName)
end

-- Check if vehicle is blacklisted
local function IsVehicleBlacklisted(vehicleHash)
    return BLACKLISTED_VEHICLES[vehicleHash] ~= nil
end

-- Check current vehicle
local function CheckVehicle()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    
    if not IsPedInAnyVehicle(ped, false) then return false end
    
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 then return false end
    
    local vehicleHash = GetEntityModel(vehicle)
    
    if IsVehicleBlacklisted(vehicleHash) then
        local vehicleName = BLACKLISTED_VEHICLES[vehicleHash] or "Unknown"
        
        -- Delete the vehicle
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
        
        if Protection.OnDetection then
            Protection.OnDetection(
                "Anti-VehicleSpawn",
                ("Blacklisted vehicle: %s (Hash: 0x%X)"):format(vehicleName, vehicleHash),
                "KICK"
            )
        end
        
        return true
    end
    
    return false
end

-- Called when entity is created (hook from server)
function Protection.OnEntityCreated(entity, entityType)
    if entityType ~= 2 then return true end -- 2 = vehicle
    
    local vehicleHash = GetEntityModel(entity)
    
    if IsVehicleBlacklisted(vehicleHash) then
        local vehicleName = BLACKLISTED_VEHICLES[vehicleHash] or "Unknown"
        
        if Protection.OnDetection then
            Protection.OnDetection(
                "Anti-VehicleSpawn",
                ("Attempted to spawn blacklisted vehicle: %s"):format(vehicleName),
                "BAN"
            )
        end
        
        return false -- Block creation
    end
    
    return true
end

-- Main loop
function Protection.Run()
    if not Protection.Enabled then return end
    
    local now = GetGameTimer()
    if now - lastCheck < CHECK_INTERVAL then return end
    lastCheck = now
    
    CheckVehicle()
end

-- Add vehicle to blacklist
function Protection.AddBlacklistedVehicle(vehicleName, displayName)
    local hash = GetHashKey(vehicleName)
    BLACKLISTED_VEHICLES[hash] = displayName or vehicleName
end

-- Initialize
function Protection.Init(config)
    if config and config.AntiVehicleSpawn then
        Protection.Enabled = config.AntiVehicleSpawn.enabled ~= false
        
        -- Add custom blacklist from config
        if config.AntiVehicleSpawn.blacklist then
            for _, vehicle in ipairs(config.AntiVehicleSpawn.blacklist) do
                local hash = GetHashKey(vehicle)
                BLACKLISTED_VEHICLES[hash] = vehicle
            end
        end
    end
    
    print('^2[LyxGuard]^7 Anti-VehicleSpawn protection initialized')
end


-- Self-register
CreateThread(function()
    Wait(100)
    if exports['lyx-guard'] and exports['lyx-guard'].RegisterProtection then
        exports['lyx-guard']:RegisterProtection('anti_vehicle', Protection)
    end
end)

return Protection
