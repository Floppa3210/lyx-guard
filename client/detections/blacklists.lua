--[[
    LyxGuard v4.0 - Blacklist Detections Module
    
    Detecciones basadas en listas negras (armas, vehículos, etc).
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. BLACKLIST WEAPONS
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('blacklist_weapon', {
    enabled = true,
    punishment = 'warn',
    banDuration = 'short',
    tolerance = 1,
    removeWeapon = true,
    list = {
        'WEAPON_MINIGUN',
        'WEAPON_RAILGUN',
        'WEAPON_STUNGUN_MP',
        'WEAPON_RPG',
        -- Añade más armas aquí
    }
}, function(config, state)
    local ped = PlayerPedId()
    
    for _, weapon in ipairs(config.list) do
        local hash = GetHashKey(weapon)
        if HasPedGotWeapon(ped, hash, false) then
            if config.removeWeapon then
                RemoveWeaponFromPed(ped, hash)
            end
            return true, {weapon = weapon}
        end
    end
    
    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. BLACKLIST VEHICLES
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('blacklist_vehicle', {
    enabled = true,
    punishment = 'warn',
    banDuration = 'short',
    tolerance = 1,
    deleteVehicle = true,
    list = {
        'hydra',
        'lazer',
        'rhino',
        'khanjali',
        'oppressor2',
        -- Añade más vehículos aquí
    }
}, function(config, state)
    if not Helpers.IsInVehicle() then return false end
    
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    local model = GetEntityModel(veh)
    
    for _, v in ipairs(config.list) do
        if model == GetHashKey(v) then
            if config.deleteVehicle then
                TaskLeaveVehicle(PlayerPedId(), veh, 16)
                Wait(1000)
                DeleteEntity(veh)
            end
            return true, {vehicle = v}
        end
    end
    
    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. BLACKLIST PED MODELS
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('blacklist_ped', {
    enabled = true,
    punishment = 'kick',
    banDuration = 'medium',
    tolerance = 1,
    forceReset = true,
    defaultModel = 'mp_m_freemode_01',
    list = {
        -- Añade modelos prohibidos aquí
        -- 'a_c_chimp',
    }
}, function(config, state)
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    
    for _, m in ipairs(config.list) do
        if model == GetHashKey(m) then
            if config.forceReset then
                local newModel = GetHashKey(config.defaultModel)
                RequestModel(newModel)
                while not HasModelLoaded(newModel) do Wait(10) end
                SetPlayerModel(PlayerId(), newModel)
                SetModelAsNoLongerNeeded(newModel)
            end
            return true, {model = m}
        end
    end
    
    return false
end)
