--[[
    LyxGuard v4.0 - Shared Functions
    Funciones compartidas entre cliente y servidor
]]

-- ═══════════════════════════════════════════════════════════════════════════════
-- LOCALES
-- ═══════════════════════════════════════════════════════════════════════════════

Locales = {
    es = {
        teleport = 'Teleport detectado',
        noclip = 'Noclip detectado',
        speedhack = 'Speed hack detectado',
        superjump = 'Súper salto detectado',
        flyhack = 'Fly hack detectado',
        underground = 'Bajo el mapa detectado',
        wallbreach = 'Atravesar paredes detectado',
        godmode = 'Modo dios detectado',
        healthhack = 'Hack de vida detectado',
        armorhack = 'Hack de armadura detectado',
        rapidfire = 'Disparo rápido detectado',
        infiniteammo = 'Munición infinita detectada',
        explosion = 'Explosión ilegal detectada',
        cagetrap = 'Trampa de jaula detectada',
        vehiclegodmode = 'Vehículo inmortal detectado',
        blacklist_weapon = 'Arma prohibida detectada',
        blacklist_vehicle = 'Vehículo prohibido detectado',
        blacklist_ped = 'Modelo prohibido detectado',
        injection = 'Inyección de código detectada',
        afkfarming = 'AFK farming detectado',
        resourcevalidation = 'Recursos inválidos detectados',
        honeypot_event = 'Evento trampa detectado',
        -- PL-Protect parity / detecciones unificadas (v4.3)
        aimbot = 'Aimbot detectado',
        aimbot_ultra = 'Aimbot (ultra) detectado',
        magic_bullet = 'Bala mágica detectada',
        norecoil = 'Sin retroceso detectado',
        no_recoil = 'Sin retroceso detectado',
        no_props = 'No-props (props ocultas) detectado',
        magneto = 'Magneto (imán de entidades) detectado',
        vehicle_invisible = 'Vehículo invisible detectado',
        anti_taser = 'Abuso de tazer detectado',
        damage_modifier = 'Daño modificado detectado',
        citizen_exploit = 'Exploit de citizen/recurso detectado',
        god_mode = 'Modo dios detectado',
        infinite_ammo = 'Munición infinita detectada',
        infinite_stamina = 'Estamina infinita detectada'
    },
    en = {
        teleport = 'Teleport detected',
        noclip = 'Noclip detected',
        speedhack = 'Speed hack detected',
        superjump = 'Super jump detected',
        flyhack = 'Fly hack detected',
        underground = 'Under map detected',
        wallbreach = 'Wall breach detected',
        godmode = 'God mode detected',
        healthhack = 'Health hack detected',
        armorhack = 'Armor hack detected',
        rapidfire = 'Rapid fire detected',
        infiniteammo = 'Infinite ammo detected',
        explosion = 'Illegal explosion detected',
        cagetrap = 'Cage trap detected',
        vehiclegodmode = 'Vehicle god mode detected',
        blacklist_weapon = 'Blacklisted weapon detected',
        blacklist_vehicle = 'Blacklisted vehicle detected',
        blacklist_ped = 'Blacklisted model detected',
        injection = 'Code injection detected',
        afkfarming = 'AFK farming detected',
        resourcevalidation = 'Invalid resources detected',
        honeypot_event = 'Honeypot event detected',
        -- PL-Protect parity / unified detections (v4.3)
        aimbot = 'Aimbot detected',
        aimbot_ultra = 'Aimbot (ultra) detected',
        magic_bullet = 'Magic bullet detected',
        norecoil = 'No recoil detected',
        no_recoil = 'No recoil detected',
        no_props = 'No-props (hidden props) detected',
        magneto = 'Magneto (entity magnet) detected',
        vehicle_invisible = 'Invisible vehicle detected',
        anti_taser = 'Tazer abuse detected',
        damage_modifier = 'Damage modifier detected',
        citizen_exploit = 'Citizen/resource exploit detected',
        god_mode = 'God mode detected',
        infinite_ammo = 'Infinite ammo detected',
        infinite_stamina = 'Infinite stamina detected'
    }
}

function GetLocale(key)
    local lang = Config and Config.Locale or 'es'
    return Locales[lang] and Locales[lang][key] or key
end
