--[[
    LyxGuard v4.0 - Entity Detections Module
    
    Detecciones de entidades (vehículos, peds, objetos, explosiones).
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. ANTI-EXPLOSION
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('explosion', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'long',
    tolerance = 1,
    maxPerMinute = 3,
    resetInterval = 60000
}, function(config, state)
    state.data.count = state.data.count or 0
    state.data.lastReset = state.data.lastReset or GetGameTimer()
    
    -- Reset contador cada minuto
    if GetGameTimer() - state.data.lastReset > config.resetInterval then
        state.data.count = 0
        state.data.lastReset = GetGameTimer()
    end
    
    -- Esta detección se activa via evento, no via polling
    -- Ver el event handler abajo
    return false
end)

-- Event handler para explosiones
AddEventHandler('explosionEvent', function(sender, ev)
    if sender == PlayerId() then
        local state = DetectionStates['explosion']
        if state then
            state.data.count = (state.data.count or 0) + 1
            
            local config = GetDetectionConfig('explosion')
            if state.data.count > config.maxPerMinute then
                TriggerDetection('explosion', {
                    count = state.data.count,
                    type = ev.explosionType
                }, config)
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. ANTI-CAGETRAP
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('cagetrap', {
    enabled = true,
    punishment = 'ban_temp',
    banDuration = 'long',
    tolerance = 1,
    checkRadius = 5.0,
    cageProps = {
        'prop_fnclink_03e', 'prop_fnclink_05a', 'prop_fncwood06a',
        'prop_barrier_work05', 'prop_sec_barrier_ld_01a'
    }
}, function(config, state)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local nearbyCount = 0
    
    for _, prop in ipairs(config.cageProps) do
        local obj = GetClosestObjectOfType(pos.x, pos.y, pos.z, config.checkRadius, GetHashKey(prop), false, false, false)
        if obj ~= 0 then
            nearbyCount = nearbyCount + 1
        end
    end
    
    -- Si hay múltiples props de jaula cerca, es sospechoso
    if nearbyCount >= 3 then
        return true, {propsNearby = nearbyCount}
    end
    
    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. ANTI-VEHICLEGODMODE
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('vehiclegodmode', {
    enabled = true,
    punishment = 'kick',
    banDuration = 'medium',
    tolerance = 2,
    damageThreshold = 1000
}, function(config, state)
    if not Helpers.IsInVehicle() then return false end
    
    state.data.lastHealth = state.data.lastHealth or 1000
    state.data.damageReceived = state.data.damageReceived or 0
    
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    local health = GetEntityHealth(veh) + GetVehicleBodyHealth(veh) + GetVehicleEngineHealth(veh)
    
    local damage = state.data.lastHealth - health
    if damage > 0 then
        state.data.damageReceived = state.data.damageReceived + damage
    end
    
    -- Si recibió mucho daño pero el vehículo sigue perfecto
    if state.data.damageReceived > config.damageThreshold then
        if health >= state.data.lastHealth - 100 then
            state.data.damageReceived = 0
            return true, {damageReceived = state.data.damageReceived}
        end
        state.data.damageReceived = 0
    end
    
    state.data.lastHealth = health
    return false
end)
