--[[
    LyxGuard v4.0 - Economy Detection Module

    Detecciones de manipulación de economía y dinero.
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. ANTI-MONEY DROP (Detect money spawning near player)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('moneydrop', {
    enabled = true,
    punishment = 'notify',
    tolerance = 3,
    checkInterval = 3000,
    maxPickupsNearby = 30,
    searchRadius = 10.0
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()
    state.data.spikes = state.data.spikes or 0

    if GetGameTimer() - state.data.lastCheck < config.checkInterval then
        return false
    end
    state.data.lastCheck = GetGameTimer()

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local pickupCount = 0
    local radiusSq = config.searchRadius * config.searchRadius

    -- Use object pool to find pickups (more reliable method)
    local objects = GetGamePool('CPickup')
    if objects then
        for _, pickup in ipairs(objects) do
            if DoesEntityExist(pickup) then
                local pickupCoords = GetEntityCoords(pickup)
                local dx = pickupCoords.x - coords.x
                local dy = pickupCoords.y - coords.y
                local dz = pickupCoords.z - coords.z
                local distSq = dx*dx + dy*dy + dz*dz
                
                if distSq <= radiusSq then
                    pickupCount = pickupCount + 1
                end
            end
        end
    end

    if pickupCount > config.maxPickupsNearby then
        state.data.spikes = state.data.spikes + 1

        if state.data.spikes >= (config.tolerance or 3) then
            state.data.spikes = 0
            return true, {
                pickupCount = pickupCount,
                maxAllowed = config.maxPickupsNearby,
                sustainedHits = config.tolerance or 3
            }
        end
    else
        state.data.spikes = math.max(0, state.data.spikes - 1)
    end

    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. ANTI-CASINO EXPLOIT (Rapid chip gain)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('casinoexploit', {
    enabled = true,
    punishment = 'notify',
    tolerance = 3,
    -- This would need integration with casino scripts
    -- Placeholder for server-side implementation
}, function(config, state)
    return false
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. ANTI-JOB EXPLOIT (Suspicious job payouts)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('jobexploit', {
    enabled = true,
    punishment = 'notify',
    tolerance = 5,
    checkInterval = 60000,
    maxPaymentsPerMinute = 10 -- Max job payments per minute
}, function(config, state)
    -- This needs server-side tracking
    -- Client can't reliably track economy
    return false
end)

print('[LyxGuard] Economy detection module loaded')
