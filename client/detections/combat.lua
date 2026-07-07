--[[
    LyxGuard v4.0 - Combat Detections Module

    Detecciones relacionadas con combate y daño.

    NOTA (unificacion v4.3): las detecciones 'godmode', 'rapidfire' e 'infiniteammo'
    fueron consolidadas para evitar registros duplicados del mismo nombre:
      - 'godmode'      -> ahora vive en client/detections/player_state.lua ('god_mode')
      - 'rapidfire'    -> ahora vive en client/detections/weapons.lua
      - 'infiniteammo' -> ahora vive en client/detections/weapon_exploits.lua ('infinite_ammo')
    Este archivo conserva solo 'healthhack' y 'armorhack' (nombres unicos).
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. ANTI-HEALTHHACK
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('healthhack', {
    enabled = true,
    punishment = 'kill',
    banDuration = 'medium',
    tolerance = 1,
    maxHealth = 200,
    buffer = 50
}, function(config, state)
    local health = GetEntityHealth(PlayerPedId())

    if health > config.maxHealth + config.buffer then
        return true, { health = health, maxAllowed = config.maxHealth }
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. ANTI-ARMORHACK
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('armorhack', {
    enabled = true,
    punishment = 'kill',
    banDuration = 'medium',
    tolerance = 1,
    maxArmor = 100,
    buffer = 10
}, function(config, state)
    local armor = GetPedArmour(PlayerPedId())

    if armor > config.maxArmor + config.buffer then
        return true, { armor = armor, maxAllowed = config.maxArmor }
    end

    return false
end)
