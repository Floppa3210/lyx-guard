--[[
    LyxGuard - Magneto Detection Module

    "Magneto" hace que las entidades (vehiculos, objetos, peds) sean atraidas hacia el
    jugador como un iman, causando caos. Se detecta observando entidades cercanas NO
    conducidas por el jugador que se mueven de forma sostenida HACIA el jugador con
    velocidad convergente. Un mundo normal no tiene multiples entidades acelerando hacia
    un punto comun; el iman si.

    Se registra con RegisterDetection() del core (grupo 'normal', ~500ms).
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- ANTI-MAGNETO (Entity magnet / pull-to-player)
-- ═══════════════════════════════════════════════════════════════════════════════

RegisterDetection('magneto', {
    enabled = true,
    punishment = 'warn',
    banDuration = 'medium',
    tolerance = 3,
    checkInterval = 500,
    -- Radio de observacion (metros).
    scanRadius = 30.0,
    -- Velocidad minima (m/s) para considerar que una entidad "se mueve".
    minEntitySpeed = 3.0,
    -- Producto punto minimo (velocidad normalizada . direccion-al-jugador) para
    -- considerar que la entidad se dirige hacia el jugador. 1.0 = directo.
    minTowardDot = 0.85,
    -- Cuantas entidades convergiendo simultaneamente son sospechosas.
    minConvergingEntities = 4,
    ignoreGracePeriod = false
}, function(config, state)
    state.data.lastCheck = state.data.lastCheck or GetGameTimer()

    if GetGameTimer() - state.data.lastCheck < (config.checkInterval or 500) then
        return false
    end
    state.data.lastCheck = GetGameTimer()

    -- Admins/spectate legitimos.
    if LocalPlayer.state.isSpectating or LocalPlayer.state.adminInvisible then
        return false
    end

    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        return false
    end

    local pcoords = GetEntityCoords(ped)
    local myVehicle = GetVehiclePedIsIn(ped, false)

    local radius = config.scanRadius or 30.0
    local radiusSq = radius * radius
    local minSpeed = config.minEntitySpeed or 3.0
    local minDot = config.minTowardDot or 0.85
    local minConverging = config.minConvergingEntities or 4

    local converging = 0

    local function _InspectPool(poolName)
        local pool = GetGamePool(poolName)
        if type(pool) ~= 'table' then return end

        for i = 1, #pool do
            local ent = pool[i]
            if ent and ent ~= 0 and DoesEntityExist(ent) and ent ~= ped and ent ~= myVehicle then
                -- Ignorar entidades ocupadas/poseidas por el propio jugador (arrastre legitimo).
                if not (poolName == 'CVehicle' and ent == myVehicle) then
                    local ecoords = GetEntityCoords(ent)
                    local dx = pcoords.x - ecoords.x
                    local dy = pcoords.y - ecoords.y
                    local dz = pcoords.z - ecoords.z
                    local distSq = dx * dx + dy * dy + dz * dz

                    if distSq <= radiusSq and distSq > 0.01 then
                        local vel = GetEntityVelocity(ent)
                        local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z)

                        if speed >= minSpeed then
                            local dist = math.sqrt(distSq)
                            -- Producto punto entre velocidad normalizada y direccion al jugador.
                            local dot = ((vel.x * dx) + (vel.y * dy) + (vel.z * dz)) / (speed * dist)
                            if dot >= minDot then
                                converging = converging + 1
                            end
                        end
                    end
                end
            end
        end
    end

    _InspectPool('CObject')
    _InspectPool('CVehicle')
    _InspectPool('CPed')

    if converging >= minConverging then
        return true, {
            convergingEntities = converging,
            minRequired = minConverging,
            scanRadius = radius,
            type = 'MAGNETO'
        }
    end

    return false
end)

print('[LyxGuard] Magneto detection module loaded')
