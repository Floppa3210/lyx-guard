--[[
    LyxGuard - Anti-Weapon Hack Protection
    Detects players with blacklisted weapons or modified weapon damage
    Based on FIREAC + Icarus detection logic
]]

local Protection = {}
Protection.Name = "Anti-WeaponHack"
Protection.Enabled = true

-- Local references
local PlayerPedId = PlayerPedId
local GetAllPedWeapons = GetAllPedWeapons
local GetSelectedPedWeapon = GetSelectedPedWeapon
local RemoveWeaponFromPed = RemoveWeaponFromPed
local GetWeaponDamageModifier = GetWeaponDamageModifier
local GetPlayerWeaponDamageModifier = GetPlayerWeaponDamageModifier
local IsEntityDead = IsEntityDead
local GetGameTimer = GetGameTimer
local GetHashKey = GetHashKey

-- Configuration
local CHECK_INTERVAL = 2000 -- ms
local MAX_DAMAGE_MODIFIER = 1.5 -- Max allowed weapon damage multiplier
local lastCheck = 0
local violations = {}

-- Blacklisted weapons (from Icarus)
local BLACKLISTED_WEAPONS = {}
local BLACKLISTED_WEAPON_NAMES = {
    'WEAPON_MG',
    'WEAPON_RPG',
    'WEAPON_BZGAS',
    'WEAPON_RAILGUN',
    'WEAPON_MINIGUN',
    'WEAPON_GRENADE',
    'WEAPON_MOLOTOV',
    'WEAPON_PIPEBOMB',
    'WEAPON_PROXMINE',
    'WEAPON_FIREWORK',
    'WEAPON_HAZARDCAN',
    'WEAPON_RAYPISTOL',
    'WEAPON_RAILGUNXM3',
    'WEAPON_RAYMINIGUN',
    'WEAPON_STICKYBOMB',
    'WEAPON_RAYCARBINE',
    'WEAPON_EMPLAUNCHER',
    'WEAPON_HOMINGLAUNCHER',
    'WEAPON_GRENADELAUNCHER',
    'WEAPON_COMPACTLAUNCHER',
    'WEAPON_GRENADELAUNCHER_SMOKE',
}

for _, weaponName in ipairs(BLACKLISTED_WEAPON_NAMES) do
    BLACKLISTED_WEAPONS[GetHashKey(weaponName)] = true
end

-- Callback
Protection.OnDetection = nil

-- Get all weapons the ped has
local function GetPedWeapons(ped)
    local weapons = {}
    
    -- Common weapon hashes to check
    local weaponNames = {
        'WEAPON_PISTOL', 'WEAPON_PISTOL_MK2', 'WEAPON_COMBATPISTOL', 'WEAPON_APPISTOL',
        'WEAPON_PISTOL50', 'WEAPON_SNSPISTOL', 'WEAPON_HEAVYPISTOL', 'WEAPON_VINTAGEPISTOL',
        'WEAPON_SMG', 'WEAPON_SMG_MK2', 'WEAPON_ASSAULTSMG', 'WEAPON_MINISMG',
        'WEAPON_MICROSMG', 'WEAPON_MACHINEPISTOL', 'WEAPON_COMBATPDW',
        'WEAPON_ASSAULTRIFLE', 'WEAPON_ASSAULTRIFLE_MK2', 'WEAPON_CARBINERIFLE',
        'WEAPON_CARBINERIFLE_MK2', 'WEAPON_ADVANCEDRIFLE', 'WEAPON_SPECIALCARBINE',
        'WEAPON_BULLPUPRIFLE', 'WEAPON_COMPACTRIFLE', 'WEAPON_MILITARYRIFLE',
        'WEAPON_MG', 'WEAPON_COMBATMG', 'WEAPON_COMBATMG_MK2', 'WEAPON_GUSENBERG',
        'WEAPON_SNIPERRIFLE', 'WEAPON_HEAVYSNIPER', 'WEAPON_HEAVYSNIPER_MK2',
        'WEAPON_MARKSMANRIFLE', 'WEAPON_MARKSMANRIFLE_MK2',
        'WEAPON_RPG', 'WEAPON_GRENADELAUNCHER', 'WEAPON_GRENADELAUNCHER_SMOKE',
        'WEAPON_MINIGUN', 'WEAPON_FIREWORK', 'WEAPON_RAILGUN', 'WEAPON_HOMINGLAUNCHER',
        'WEAPON_COMPACTLAUNCHER', 'WEAPON_RAYMINIGUN', 'WEAPON_EMPLAUNCHER',
        'WEAPON_GRENADE', 'WEAPON_BZGAS', 'WEAPON_MOLOTOV', 'WEAPON_STICKYBOMB',
        'WEAPON_PROXMINE', 'WEAPON_PIPEBOMB', 'WEAPON_SMOKEGRENADE', 'WEAPON_FLARE',
        'WEAPON_SNOWBALL', 'WEAPON_BALL',
        'WEAPON_KNIFE', 'WEAPON_NIGHTSTICK', 'WEAPON_HAMMER', 'WEAPON_BAT',
        'WEAPON_CROWBAR', 'WEAPON_GOLFCLUB', 'WEAPON_BOTTLE', 'WEAPON_DAGGER',
        'WEAPON_HATCHET', 'WEAPON_MACHETE', 'WEAPON_SWITCHBLADE', 'WEAPON_BATTLEAXE',
        'WEAPON_POOLCUE', 'WEAPON_WRENCH', 'WEAPON_FLASHLIGHT', 'WEAPON_STUNGUN',
        'WEAPON_PUMPSHOTGUN', 'WEAPON_PUMPSHOTGUN_MK2', 'WEAPON_SAWNOFFSHOTGUN',
        'WEAPON_ASSAULTSHOTGUN', 'WEAPON_BULLPUPSHOTGUN', 'WEAPON_MUSKET',
        'WEAPON_HEAVYSHOTGUN', 'WEAPON_DBSHOTGUN', 'WEAPON_AUTOSHOTGUN',
        'WEAPON_COMBATSHOTGUN', 'WEAPON_RAYPISTOL', 'WEAPON_RAYCARBINE',
        'WEAPON_HAZARDCAN',
    }
    
    for _, weaponName in ipairs(weaponNames) do
        local hash = GetHashKey(weaponName)
        if HasPedGotWeapon(ped, hash, false) then
            table.insert(weapons, hash)
        end
    end
    
    return weapons
end

-- Check weapons
local function CheckWeapons()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    
    if IsEntityDead(ped) then return false end
    
    local weapons = GetPedWeapons(ped)
    
    for _, weaponHash in ipairs(weapons) do
        if BLACKLISTED_WEAPONS[weaponHash] then
            -- Remove the weapon
            RemoveWeaponFromPed(ped, weaponHash)
            
            violations.blacklist = (violations.blacklist or 0) + 1
            
            if violations.blacklist >= 2 then
                if Protection.OnDetection then
                    Protection.OnDetection(
                        "Anti-WeaponHack",
                        ("Blacklisted weapon detected: 0x%X"):format(weaponHash),
                        "BAN"
                    )
                end
                violations.blacklist = 0
                return true
            end
        end
    end
    
    -- Check damage modifier
    local damageModifier = GetPlayerWeaponDamageModifier(PlayerId())
    if damageModifier > MAX_DAMAGE_MODIFIER then
        violations.damage = (violations.damage or 0) + 1
        
        if violations.damage >= 3 then
            if Protection.OnDetection then
                Protection.OnDetection(
                    "Anti-WeaponHack",
                    ("Weapon damage modifier too high: %.2f (max: %.2f)"):format(damageModifier, MAX_DAMAGE_MODIFIER),
                    "BAN"
                )
            end
            violations.damage = 0
            return true
        end
    else
        violations.damage = 0
    end
    
    return false
end

-- Main loop
function Protection.Run()
    if not Protection.Enabled then return end
    
    local now = GetGameTimer()
    if now - lastCheck < CHECK_INTERVAL then return end
    lastCheck = now
    
    CheckWeapons()
end

-- Add weapon to blacklist dynamically
function Protection.AddBlacklistedWeapon(weaponHash)
    BLACKLISTED_WEAPONS[weaponHash] = true
end

-- Initialize
function Protection.Init(config)
    if config and config.AntiWeaponHack then
        Protection.Enabled = config.AntiWeaponHack.enabled ~= false
        
        -- Add custom blacklisted weapons from config
        if config.AntiWeaponHack.blacklist then
            for _, weapon in ipairs(config.AntiWeaponHack.blacklist) do
                local hash = GetHashKey(weapon)
                BLACKLISTED_WEAPONS[hash] = true
            end
        end
    end
    
    print('^2[LyxGuard]^7 Anti-WeaponHack protection initialized')
end

-- Self-register
CreateThread(function()
    Wait(100)
    if exports['lyx-guard'] and exports['lyx-guard'].RegisterProtection then
        exports['lyx-guard']:RegisterProtection('anti_weapon', Protection)
    end
end)

return Protection
