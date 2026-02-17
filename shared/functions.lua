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
        honeypot_event = 'Evento trampa detectado'
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
        honeypot_event = 'Honeypot event detected'
    }
}

function GetLocale(key)
    local lang = Config and Config.Locale or 'es'
    return Locales[lang] and Locales[lang][key] or key
end
