--[[ ════════════════════════════════════════════════════════════════════════════

     LyxGuard — CONFIGURACIÓN FÁCIL  (config_easy.lua)
     ──────────────────────────────────────────────────────────────────────────
     Este es el archivo que TENÉS que tocar para configurar el anticheat.
     Es simple y casi todo son interruptores (true = activado / false = apagado).

     ¿Cómo funciona?
       1) Elegís un PRESET (qué tan duro castiga el AC).           -> Config.Preset
       2) Prendés o apagás cada protección con true / false.       -> Config.Easy
       3) (Opcional) Si querés decidir vos el castigo de cada cosa -> Config.Preset='custom'
                     completás Config.CustomPreset.
       4) Elegís dónde se guardan los cambios del panel.           -> Config.PanelPersistence

     Todo lo TÉCNICO y avanzado (umbrales, intervalos, listas, etc.) sigue en
     config.lua. No necesitás abrirlo salvo que quieras afinar valores finos.
     Este archivo se carga DESPUÉS de config.lua y solo cambia:
        - si cada detección está activada (enabled)
        - qué castigo aplica (punishment / banDuration), según el preset elegido.

════════════════════════════════════════════════════════════════════════════ ]]

-- ─────────────────────────────────────────────────────────────────────────────
-- 1) PRESET GLOBAL — qué tan estricto es el anticheat
-- ─────────────────────────────────────────────────────────────────────────────
--   'estricto'    (RECOMENDADO) Cheat claro = BAN PERMANENTE. Mano dura.
--   'balanceado'  Cheat grave = ban temporal largo. Menos riesgo de falsos bans.
--   'suave'       Todo en aviso/warn. Cero ban automático (para observar y calibrar).
--   'custom'      Vos decidís el castigo de cada detección abajo (Config.CustomPreset).
--   'manual'      No toco los castigos: se usan los de config.lua tal cual (avanzado).
Config.Preset = 'estricto'

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) PROTECCIONES — prendé/apagá cada una con true / false
-- ─────────────────────────────────────────────────────────────────────────────
-- El nombre es el de la detección. Poné false para desactivarla por completo.
Config.Easy = {

    -- ── Movimiento ───────────────────────────────────────────────────────────
    teleport        = true,   -- Teleport / warp de posición
    noclip          = true,   -- Atravesar paredes / volar sin colisión
    speedHack       = true,   -- Velocidad anormal (a pie / vehículo)
    superJump       = true,   -- Salto sobrehumano
    flyHack         = true,   -- Volar sin vehículo
    underground     = true,   -- Meterse bajo el mapa
    wallBreach      = true,   -- Atravesar geometría

    -- ── Combate ──────────────────────────────────────────────────────────────
    godMode         = true,   -- Invulnerabilidad (CHEAT CLARO)
    invisible       = true,   -- Invisibilidad de jugador
    healthHack      = true,   -- Vida por encima del máximo
    armorHack       = true,   -- Chaleco por encima del máximo
    rapidFire       = true,   -- Cadencia de disparo imposible
    infiniteAmmo    = true,   -- Munición infinita
    fastReload      = true,   -- Recarga instantánea
    noRecoil        = true,   -- Sin retroceso
    noSpread        = true,   -- Sin dispersión de bala
    explosiveSpam   = true,   -- Spam de explosivos
    antiTaser       = true,   -- Abuso de táser

    -- ── Exploits graves / Ultra ──────────────────────────────────────────────
    citizenExploit  = true,   -- Recursos/menús de cheat cargados (CHEAT CLARO)
    aimbotUltra     = true,   -- Aimbot (CHEAT CLARO)
    healthRegen     = true,   -- Regeneración de vida anormal
    ammoExploit     = true,   -- Exploit de munición
    vehicleSpawn    = true,   -- Spawnear vehículos ilegales (CHEAT CLARO)
    weaponSpawn     = true,   -- Spawnear armas ilegales (CHEAT CLARO)
    modelExploit    = true,   -- Cambio de modelo ilegal (CHEAT CLARO)
    moneyExploit    = false,  -- (Cliente) dinero: OFF, la autoridad real es server-side

    -- ── Entidades / mundo ────────────────────────────────────────────────────
    explosion       = true,   -- Explosiones ilegítimas
    cageTrap        = true,   -- Cage / trap de props
    vehicleGodMode  = true,   -- Vehículo indestructible
    entityFirewall  = true,   -- Firewall de spawns de entidades
    ptfx            = true,   -- Spam de partículas
    clearPedTasks   = true,   -- Abuso de clearPedTasks (anti-ragdoll, etc.)
    projectile      = true,   -- Proyectiles ilegítimos
    weaponDamage    = true,   -- Daño de arma manipulado
    entityRemoved   = true,   -- Borrado masivo de entidades
    antiYank        = true,   -- Anti-tirón de vehículo (sacar del auto)
    superPunch      = true,   -- Puñetazo con daño/empuje imposible
    audioFlood      = true,   -- Flood de audio
    magneto         = true,   -- Imán de entidades
    noProps         = true,   -- Ocultar props del mundo
    vehicleInvisible = true,  -- Vehículo invisible

    -- ── Listas negras ────────────────────────────────────────────────────────
    weapons         = true,   -- Armas prohibidas (lista en config.lua)
    vehicles        = true,   -- Vehículos prohibidos (lista en config.lua)
    peds            = false,  -- Modelos de ped prohibidos (OFF hasta cargar lista)

    -- ── Inyección / avanzado ─────────────────────────────────────────────────
    injection       = true,   -- Inyección de código / executors (CHEAT CLARO)
    afkFarming      = true,   -- Farmeo AFK
    resourceValidation = true,-- Recursos requeridos ausentes/alterados
    heartbeat       = true,   -- Cliente sin heartbeat (posible desync/tamper)
    honeypotEvent   = true,   -- Evento trampa disparado (CHEAT CLARO)
    honeypotCommands = true,  -- Comando trampa de menú de cheat (CHEAT CLARO)
}

-- ─────────────────────────────────────────────────────────────────────────────
-- 3) PRESET PERSONALIZADO — solo se usa si Config.Preset = 'custom'
-- ─────────────────────────────────────────────────────────────────────────────
-- Definí el castigo que quieras para cada detección. Lo que NO completes acá
-- usa el castigo del preset 'estricto' como respaldo.
--   punishment:  'none' | 'notify' | 'screenshot' | 'warn' | 'kick'
--                'ban_temp' | 'ban_perm' | 'teleport' | 'freeze' | 'kill'
--   banDuration: 'short' | 'medium' | 'long' | 'verylong' | 'permanent'
Config.CustomPreset = {
    -- Ejemplos (descomentá y editá lo que quieras):
    -- vehicleSpawn = { punishment = 'ban_perm' },
    -- aimbotUltra  = { punishment = 'ban_perm' },
    -- speedHack    = { punishment = 'kick' },
    -- teleport     = { punishment = 'ban_temp', banDuration = 'medium' },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- 4) PERSISTENCIA DEL PANEL — dónde se guardan los cambios hechos desde el panel
-- ─────────────────────────────────────────────────────────────────────────────
--   'database'  (RECOMENDADO) Guarda en MySQL. Sobrevive reinicios. Multi-server ok.
--   'json'      Guarda en un archivo overrides.json dentro del recurso.
--   'off'       No guarda: los cambios del panel son temporales (se pierden al reiniciar).
Config.PanelPersistence = 'database'


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  A PARTIR DE ACÁ ES LÓGICA INTERNA — normalmente NO necesitás tocar nada. ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Clasificación de cada detección por severidad. Los presets asignan el castigo
-- según esta clase. (blatant = cheat inequívoco; minor = puede dar falsos positivos.)
local TIER = {
    -- blatant: cheat que no admite duda -> el más duro
    godMode='blatant', invisible='blatant', citizenExploit='blatant', aimbotUltra='blatant',
    vehicleSpawn='blatant', weaponSpawn='blatant', modelExploit='blatant', injection='blatant',
    honeypotEvent='blatant', honeypotCommands='blatant',
    -- severe: muy grave
    healthHack='severe', armorHack='severe', healthRegen='severe', ammoExploit='severe',
    infiniteAmmo='severe', noclip='severe', flyHack='severe', vehicleGodMode='severe',
    explosion='severe', moneyExploit='severe', magneto='severe', weapons='severe', vehicles='severe',
    -- medium: sospechoso claro pero menos catastrófico
    speedHack='medium', teleport='medium', superJump='medium', rapidFire='medium',
    fastReload='medium', noRecoil='medium', noSpread='medium', explosiveSpam='medium',
    cageTrap='medium', superPunch='medium', projectile='medium', weaponDamage='medium',
    entityRemoved='medium', peds='medium', ptfx='medium',
    -- minor: heurísticas con posible ruido -> castigo suave
    underground='minor', wallBreach='minor', antiTaser='minor', audioFlood='minor',
    noProps='minor', vehicleInvisible='minor', afkFarming='minor', entityFirewall='minor',
    clearPedTasks='minor', resourceValidation='minor', heartbeat='minor', antiYank='minor',
}

-- Definición de los 3 presets integrados: por cada clase, qué castigo aplica.
local PRESETS = {
    estricto = {
        blatant = { punishment = 'ban_perm',  banDuration = 'permanent' },
        severe  = { punishment = 'ban_temp',  banDuration = 'long' },
        medium  = { punishment = 'kick' },
        minor   = { punishment = 'warn',      banDuration = 'short' },
    },
    balanceado = {
        blatant = { punishment = 'ban_temp',  banDuration = 'long' },
        severe  = { punishment = 'ban_temp',  banDuration = 'medium' },
        medium  = { punishment = 'warn',      banDuration = 'short' },
        minor   = { punishment = 'notify' },
    },
    suave = {
        blatant = { punishment = 'warn',      banDuration = 'short' },
        severe  = { punishment = 'warn',      banDuration = 'short' },
        medium  = { punishment = 'notify' },
        minor   = { punishment = 'notify' },
    },
}

-- Secciones de Config donde viven las detecciones (nombre de clave = nombre detección).
local SECTIONS = { 'Movement', 'Combat', 'Ultra', 'Entities', 'Advanced', 'Blacklists' }

-- Devuelve el castigo a aplicar para una detección según el preset activo.
local function _ResolvePunishment(presetName, key)
    if presetName == 'custom' then
        local c = Config.CustomPreset and Config.CustomPreset[key]
        if c and c.punishment then return c end
        -- Respaldo: lo no definido en custom usa 'estricto'.
        local tier = TIER[key] or 'medium'
        return PRESETS.estricto[tier]
    end
    local table_ = PRESETS[presetName]
    if not table_ then return nil end
    local tier = TIER[key] or 'medium'
    return table_[tier]
end

-- Se exponen las tablas y el resolver como global para que el panel (server-side)
-- pueda reutilizar la misma lógica de presets sin duplicarla.
LyxGuardEasy = {
    TIER = TIER,
    PRESETS = PRESETS,
    SECTIONS = SECTIONS,
    -- Devuelve { punishment, banDuration } para (preset, detección).
    ResolvePunishment = _ResolvePunishment,
    -- Lista de nombres de preset integrados (sin 'custom'/'manual').
    PresetNames = { 'estricto', 'balanceado', 'suave' },
}

-- Aplica Config.Easy (on/off) y el preset (castigos) sobre las secciones ya cargadas.
do
    local preset = tostring(Config.Preset or 'estricto')

    -- 'manual' => no tocar castigos, pero SÍ respetar los on/off de Config.Easy.
    local applyPunishments = (preset ~= 'manual')

    -- Validación amistosa del preset elegido.
    if applyPunishments and preset ~= 'custom' and not PRESETS[preset] then
        print(('^3[LyxGuard]^7 config_easy: preset desconocido "%s" -> usando "estricto".'):format(preset))
        preset = 'estricto'
    end

    local toggled, punished = 0, 0

    for _, sectionName in ipairs(SECTIONS) do
        local section = Config[sectionName]
        if type(section) == 'table' then
            for key, settings in pairs(section) do
                if type(settings) == 'table' and settings.enabled ~= nil then
                    -- (a) on/off
                    if Config.Easy[key] ~= nil then
                        settings.enabled = Config.Easy[key] and true or false
                        toggled = toggled + 1
                    end
                    -- (b) castigo según preset (si corresponde y la detección quedó activa)
                    if applyPunishments and settings.enabled then
                        local p = _ResolvePunishment(preset, key)
                        if p and p.punishment then
                            settings.punishment = p.punishment
                            if p.banDuration then
                                settings.banDuration = p.banDuration
                            end
                            punished = punished + 1
                        end
                    end
                end
            end
        end
    end

    print(('^2[LyxGuard]^7 config_easy aplicado: preset="%s" | %d detecciones on/off | %d castigos asignados')
        :format(preset, toggled, punished))
end
