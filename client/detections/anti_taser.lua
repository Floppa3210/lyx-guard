--[[
    LyxGuard v4.3 - Anti-Taser Exploit Detection

    Migrado del antiguo client/protections/anti_tazer.lua al framework unificado
    RegisterDetection. Detecta abuso de tazer (WEAPON_STUNGUN): disparos repetidos
    mas rapido que el cooldown fisico del arma (cheat de tazer rapido / cadena).

    Fix respecto al modulo viejo: usa deteccion de FLANCO de disparo (rising edge)
    en vez de refrescar el cooldown en cada tick mientras se mantiene el gatillo,
    lo que generaba falsos positivos con disparo continuo.

    PL-Protect parity: "Anti Taser".
]]

local WEAPON_STUNGUN = GetHashKey('WEAPON_STUNGUN')
local WEAPON_STUNGUN_MP = GetHashKey('WEAPON_STUNGUN_MP')

RegisterDetection('anti_taser', {
    enabled = true,
    punishment = 'warn',
    banDuration = 'short',
    tolerance = 3,
    checkInterval = 50,
    -- Cooldown fisico minimo entre descargas legitimas del tazer (ms).
    minShotIntervalMs = 3000
}, function(config, state)
    if Helpers and Helpers.IsPlayerImmune and Helpers.IsPlayerImmune() then return false end

    state.data.lastShotMs = state.data.lastShotMs or 0
    state.data.wasShooting = state.data.wasShooting or false
    state.data.violations = state.data.violations or 0

    local now = GetGameTimer()
    if now - (state.data.lastCheck or 0) < (config.checkInterval or 50) then
        return false
    end
    state.data.lastCheck = now

    local ped = PlayerPedId()
    local _, weapon = GetCurrentPedWeapon(ped, true)

    -- Solo evaluar si tiene equipado el tazer.
    if weapon ~= WEAPON_STUNGUN and weapon ~= WEAPON_STUNGUN_MP then
        state.data.wasShooting = false
        return false
    end

    local shooting = IsPedShooting(ped)

    -- Flanco de subida: transicion de "no disparando" -> "disparando" = 1 descarga.
    if shooting and not state.data.wasShooting then
        local minInterval = tonumber(config.minShotIntervalMs) or 3000
        local sinceLast = now - state.data.lastShotMs

        if state.data.lastShotMs > 0 and sinceLast < minInterval then
            state.data.violations = state.data.violations + 1
            if state.data.violations >= (config.tolerance or 3) then
                state.data.violations = 0
                state.data.lastShotMs = now
                state.data.wasShooting = true
                return true, {
                    type = 'TASER_COOLDOWN_BYPASS',
                    intervalMs = sinceLast,
                    minAllowedMs = minInterval
                }
            end
        else
            -- Descarga con intervalo legitimo: decae el contador.
            state.data.violations = math.max(0, state.data.violations - 1)
        end

        state.data.lastShotMs = now
    end

    state.data.wasShooting = shooting
    return false
end, 'fast')

print('^2[LyxGuard]^7 Anti-Taser detection loaded (unified framework)')
