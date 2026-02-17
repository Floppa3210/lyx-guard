--[[
    LyxGuard - Anti-Tazer Exploit Protection
    Detects tazer abuse (distance, cooldown bypass)
    Based on Icarus TazerModule
]]

local Protection = {}
Protection.Name = "Anti-TazerExploit"
Protection.Enabled = true

-- Local references
local PlayerPedId = PlayerPedId
local GetEntityCoords = GetEntityCoords
local GetSelectedPedWeapon = GetSelectedPedWeapon
local GetGameTimer = GetGameTimer
local IsPedShooting = IsPedShooting

-- Configuration
local MAX_TAZER_DISTANCE = 12.0 -- meters
local TAZER_COOLDOWN = 12000 -- 12 seconds
local VIOLATION_THRESHOLD = 3

local lastTazerUse = 0
local violations = 0
local lastCheck = 0
local CHECK_INTERVAL = 100

-- Tazer weapon hash
local WEAPON_STUNGUN = GetHashKey('WEAPON_STUNGUN')

-- Callback
Protection.OnDetection = nil

-- Check for tazer abuse
local function CheckTazer()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    
    local currentWeapon = GetSelectedPedWeapon(ped)
    
    -- Only check if holding tazer
    if currentWeapon ~= WEAPON_STUNGUN then
        return false
    end
    
    local now = GetGameTimer()
    
    -- Check if shooting tazer
    if IsPedShooting(ped) then
        -- Check cooldown bypass
        if lastTazerUse > 0 and (now - lastTazerUse) < TAZER_COOLDOWN then
            violations = violations + 1
            
            if violations >= VIOLATION_THRESHOLD then
                if Protection.OnDetection then
                    Protection.OnDetection(
                        "Anti-TazerExploit",
                        ("Tazer cooldown bypass: %.1fs since last use (min: %.1fs)"):format(
                            (now - lastTazerUse) / 1000, TAZER_COOLDOWN / 1000
                        ),
                        "KICK"
                    )
                end
                violations = 0
                return true
            end
        end
        
        lastTazerUse = now
    end
    
    return false
end

-- Called when player is tazed (to check distance)
function Protection.OnPlayerTazed(attackerServerId, victimCoords)
    if not Protection.Enabled then return end
    
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    
    -- Calculate distance
    local dx = victimCoords.x - pedCoords.x
    local dy = victimCoords.y - pedCoords.y
    local dz = victimCoords.z - pedCoords.z
    local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
    
    if distance > MAX_TAZER_DISTANCE then
        if Protection.OnDetection then
            Protection.OnDetection(
                "Anti-TazerExploit",
                ("Tazer from excessive distance: %.1fm (max: %.1fm)"):format(distance, MAX_TAZER_DISTANCE),
                "BAN"
            )
        end
        return false
    end
    
    return true
end

-- Main loop
function Protection.Run()
    if not Protection.Enabled then return end
    
    local now = GetGameTimer()
    if now - lastCheck < CHECK_INTERVAL then return end
    lastCheck = now
    
    CheckTazer()
end

-- Initialize
function Protection.Init(config)
    if config and config.AntiTazerExploit then
        Protection.Enabled = config.AntiTazerExploit.enabled ~= false
        if config.AntiTazerExploit.maxDistance then
            MAX_TAZER_DISTANCE = config.AntiTazerExploit.maxDistance
        end
        if config.AntiTazerExploit.cooldown then
            TAZER_COOLDOWN = config.AntiTazerExploit.cooldown
        end
    end
    
    print('^2[LyxGuard]^7 Anti-TazerExploit protection initialized')
end


-- Self-register
CreateThread(function()
    Wait(100)
    if exports['lyx-guard'] and exports['lyx-guard'].RegisterProtection then
        exports['lyx-guard']:RegisterProtection('anti_tazer', Protection)
    end
end)

return Protection
