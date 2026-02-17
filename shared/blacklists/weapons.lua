--[[
    LyxGuard - Weapons Blacklist
    Complete list of blacklisted weapons
    Based on Icarus + FIREAC
]]

return {
    -- Military/Heavy Weapons
    [GetHashKey('WEAPON_MG')] = "Combat MG",
    [GetHashKey('WEAPON_COMBATMG')] = "Combat MG",
    [GetHashKey('WEAPON_COMBATMG_MK2')] = "Combat MG Mk II",
    [GetHashKey('WEAPON_GUSENBERG')] = "Gusenberg Sweeper",
    
    -- Explosives
    [GetHashKey('WEAPON_RPG')] = "RPG",
    [GetHashKey('WEAPON_GRENADELAUNCHER')] = "Grenade Launcher",
    [GetHashKey('WEAPON_GRENADELAUNCHER_SMOKE')] = "Smoke Grenade Launcher",
    [GetHashKey('WEAPON_MINIGUN')] = "Minigun",
    [GetHashKey('WEAPON_FIREWORK')] = "Firework Launcher",
    [GetHashKey('WEAPON_RAILGUN')] = "Railgun",
    [GetHashKey('WEAPON_RAILGUNXM3')] = "Railgun XM3",
    [GetHashKey('WEAPON_HOMINGLAUNCHER')] = "Homing Launcher",
    [GetHashKey('WEAPON_COMPACTLAUNCHER')] = "Compact Grenade Launcher",
    [GetHashKey('WEAPON_EMPLAUNCHER')] = "EMP Launcher",
    
    -- Throwables
    [GetHashKey('WEAPON_GRENADE')] = "Grenade",
    [GetHashKey('WEAPON_BZGAS')] = "BZ Gas",
    [GetHashKey('WEAPON_MOLOTOV')] = "Molotov",
    [GetHashKey('WEAPON_STICKYBOMB')] = "Sticky Bomb",
    [GetHashKey('WEAPON_PROXMINE')] = "Proximity Mine",
    [GetHashKey('WEAPON_PIPEBOMB')] = "Pipe Bomb",
    
    -- Alien/Future Weapons
    [GetHashKey('WEAPON_RAYPISTOL')] = "Up-n-Atomizer",
    [GetHashKey('WEAPON_RAYCARBINE')] = "Unholy Hellbringer",
    [GetHashKey('WEAPON_RAYMINIGUN')] = "Widowmaker",
    
    -- Other dangerous
    [GetHashKey('WEAPON_HAZARDCAN')] = "Jerry Can (Hazard)",
    [GetHashKey('WEAPON_PETROLCAN')] = "Jerry Can",
}
