--[[
    LyxGuard - Anti-Yank Protection
    Protects players from being forcefully removed from vehicles
    Part of the Player Protection system
]]

local Protection = {}
Protection.Name = "Anti-Yank"
Protection.Enabled = true

-- Local references
local PlayerPedId = PlayerPedId
local GetVehiclePedIsIn = GetVehiclePedIsIn
local GetPedInVehicleSeat = GetPedInVehicleSeat
local IsPedAPlayer = IsPedAPlayer
local GetGameTimer = GetGameTimer
local TaskWarpPedIntoVehicle = TaskWarpPedIntoVehicle
local GetVehicleDoorLockStatus = GetVehicleDoorLockStatus
local NetworkGetPlayerIndexFromPed = NetworkGetPlayerIndexFromPed
local GetPlayerServerId = GetPlayerServerId

-- State
local lastVehicle = nil
local lastSeat = nil
local vehicleEnterTime = 0
local wasInVehicle = false
local CHECK_INTERVAL = 500

-- Config cache
local config = nil

-- Callback for detections
Protection.OnDetection = nil

-- Get current ESX player data
local function GetPlayerJob()
    if ESX and ESX.GetPlayerData then
        local playerData = ESX.GetPlayerData()
        if playerData and playerData.job then
            return playerData.job.name
        end
    end
    return nil
end

-- Check if attacker has allowed job
local function IsAllowedJob(attackerSource)
    if not config or not config.allowedJobs then return false end
    -- We can't easily check other player's job client-side
    -- This would need server validation
    return false
end

-- Main check function
function Protection.Run()
    if not Protection.Enabled then return end
    if not config then
        config = Config and Config.Entities and Config.Entities.antiYank
        if not config or not config.enabled then
            Protection.Enabled = false
            return
        end
    end

    local ped = PlayerPedId()
    local currentVehicle = GetVehiclePedIsIn(ped, false)
    local now = GetGameTimer()
    
    -- Track when we enter a vehicle
    if currentVehicle ~= 0 and not wasInVehicle then
        wasInVehicle = true
        lastVehicle = currentVehicle
        lastSeat = GetPedSeatIndex(ped)
        vehicleEnterTime = now
    elseif currentVehicle == 0 and wasInVehicle then
        -- We just left a vehicle
        local timeSinceEnter = now - vehicleEnterTime
        
        -- If we left too quickly after entering (possible yank)
        if timeSinceEnter > config.gracePeriod then
            -- Check if we were forcefully removed
            if lastVehicle and DoesEntityExist(lastVehicle) then
                local doorLock = GetVehicleDoorLockStatus(lastVehicle)
                local vehicleStillExists = DoesEntityExist(lastVehicle)
                
                -- If vehicle is locked and we were removed = possible yank
                if config.protectLockedVehicles and doorLock >= 2 and vehicleStillExists then
                    -- Warp back into vehicle
                    if lastSeat then
                        TaskWarpPedIntoVehicle(ped, lastVehicle, lastSeat)
                        
                        -- Report detection
                        if Protection.OnDetection then
                            Protection.OnDetection("Anti-Yank", 
                                "Player was forcefully removed from locked vehicle", 
                                "WARN")
                        end
                    end
                end
                
                -- Check if another player is now in our seat
                if lastSeat and vehicleStillExists then
                    local pedInSeat = GetPedInVehicleSeat(lastVehicle, lastSeat)
                    if pedInSeat ~= 0 and pedInSeat ~= ped and IsPedAPlayer(pedInSeat) then
                        -- Someone took our seat = possible hijack/yank
                        local attackerPlayer = NetworkGetPlayerIndexFromPed(pedInSeat)
                        local attackerSource = GetPlayerServerId(attackerPlayer)
                        
                        -- Trigger server-side check (attacker job validation)
                        TriggerServerEvent('lyxguard:validateYank', attackerSource, {
                            vehicle = lastVehicle,
                            seat = lastSeat,
                            doorLock = doorLock
                        })
                    end
                end
            end
        end
        
        wasInVehicle = false
        lastVehicle = nil
        lastSeat = nil
    end
end

-- Helper function to get ped's seat index
function GetPedSeatIndex(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return nil end
    
    for i = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if GetPedInVehicleSeat(vehicle, i) == ped then
            return i
        end
    end
    return nil
end

-- Initialize
function Protection.Init(cfg)
    if cfg and cfg.Entities and cfg.Entities.antiYank then
        config = cfg.Entities.antiYank
        Protection.Enabled = config.enabled
    end
    
    print('^2[LyxGuard]^7 Anti-Yank protection initialized')
end

-- Self-register
CreateThread(function()
    Wait(100)
    
    if RegisterProtectionModule then
        RegisterProtectionModule('anti_yank', Protection)
    elseif exports['lyx-guard'] and exports['lyx-guard'].RegisterProtection then
        exports['lyx-guard']:RegisterProtection('anti_yank', Protection)
    end
end)

return Protection
