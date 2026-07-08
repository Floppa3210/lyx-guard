# LyxGuard - Config Reference

Este documento resume las opciones mas importantes de `config.lua` y sus defaults "stock".
LyxGuard tiene muchas opciones; este archivo prioriza las que afectan seguridad, falsos positivos y operacion.

## 0) Configuración fácil (`config_easy.lua`) — EMPEZÁ ACÁ

A partir de v4.4 hay un archivo simple pensado para configurar el AC sin miedo:
`config_easy.lua`. Se carga **después** de `config.lua` y solo cambia si cada detección
está activada y qué castigo aplica, según un preset. Todo lo técnico (umbrales, listas,
intervalos) sigue en `config.lua`.

**1. Preset global** — `Config.Preset`:
- `'estricto'` (default, recomendado): cheat claro = **ban permanente**. Mano dura.
- `'balanceado'`: cheat grave = ban temporal largo. Menos riesgo de falsos bans.
- `'suave'`: todo en aviso/warn, cero ban automático (modo observación/calibración).
- `'custom'`: vos decidís el castigo de cada detección en `Config.CustomPreset`.
- `'manual'`: no toca castigos; usa los de `config.lua` tal cual.

**2. Interruptores** — `Config.Easy`: un `true/false` por detección (prende/apaga).

**3. Preset personalizado** — `Config.CustomPreset` (solo si `Config.Preset='custom'`):
```lua
Config.CustomPreset = {
    vehicleSpawn = { punishment = 'ban_perm' },
    speedHack    = { punishment = 'kick' },
    teleport     = { punishment = 'ban_temp', banDuration = 'medium' },
}
```
Lo que no definas usa el preset `estricto` como respaldo.

**4. Persistencia del panel** — `Config.PanelPersistence`:
- `'database'` (default, recomendado): guarda los cambios del panel en MySQL (sobreviven reinicios).
- `'json'`: guarda en `overrides.json` dentro del recurso.
- `'off'`: cambios del panel temporales (se pierden al reiniciar).

**Defaults preconfigurados (preset estricto):** spawn de vehículo/arma ilegal, aimbot,
injection/executor, godmode, modelExploit y honeypots → **ban permanente**. `moneyExploit`
viene apagado (la autoridad económica real es server-side). Heurísticas con posible ruido
(underground, noProps, antiTaser…) → warn, para evitar bans por falso positivo.

> El panel de admin (página *Configuración de Admin → Detecciones*) permite editar TODAS las
> detecciones en vivo, elegir preset y guardar. Los cambios se aplican a los jugadores
> conectados sin reiniciar y se persisten según `Config.PanelPersistence`.

## 1) General
- `Config.Debug` (default: `false`)
- `Config.Locale` (default: `es`)
- `Config.ResourceName` (default: `lyx-guard`)
- `Config.RuntimeProfile` (default: `default`)

Perfiles soportados:
- `default`
- `rp_light`
- `production_high_load`
- `hostile`

## 2) Firewall de eventos (Config.EventFirewall)
Usado por `server/trigger_protection.lua` para higiene de payload y controles de abuso.

Defaults clave:
- `enabled = true`
- `strictLyxGuardAllowlist = true`
- `maxArgs = 24`
- `maxDepth = 8`
- `maxKeysPerTable = 200`
- `maxTotalKeys = 2000`
- `maxStringLen = 4096`
- `maxTotalStringLen = 20000`

## 3) Trigger protection (Config.TriggerProtection)
Controla limites de spam/flood y protecciones de eventos sensibles.

Recomendacion:
- en servers con mucha carga, usar `production_high_load`
- en ataques reales (spoof/flood), usar `hostile`

## 4) Panel (Config.Panel)
- `enabled = true`
- `key = 'F8'`
- `autoRefreshInterval = 30`
- `acePermissions` y `allowedGroups` controlan acceso

## 5) Punishments (Config.Punishments)
Incluye presets de duracion y mensajes.

Notas:
- evitar ban permanente en señales de baja confianza
- preferir escalado via quarantine/score

## 6) Quarantine (Config.Quarantine)
Reduce falsos positivos con enfriamientos por razon y escalado progresivo.

## 7) Logging exhaustivo (Config.ExhaustiveLogs)
Escritura a archivos locales dentro del recurso:
- carpeta: `logs/` (default)
- formatos:
  - JSONL (`writeJsonl = true`)
  - texto (`writeText = true`)

Defaults clave:
- `enabled = true`
- `flushIntervalMs = 2000`
- `flushBatchSize = 30`
- `maxFileBytes = 2 MB`
- timeline:
  - `timelineSeconds = 60` (contexto previo a sancion)
  - `timelineRetentionSeconds = 15 min`
  - `timelineMaxEntries = 1200`

## 8) Discord (Config.Discord)
Defaults:
- `enabled = true`
- webhooks vacios por defecto (completalos si queres notificaciones)

## 9) Detecciones client-side (Config.Movement / Combat / Ultra / Entities / Advanced / Blacklists)

Las detecciones del cliente se registran con `RegisterDetection(name, cfg, handler, group)`
y reciben su config desde el servidor via el callback `lyxguard:getConfig`
(secciones enviadas: `movement`, `combat`, `entities`, `ultra`, `advanced`, `blacklists`).

> Nota (v4.3): a partir de esta version el callback tambien envia `Config.Ultra`,
> por lo que las detecciones Ultra (`aimbot_ultra`, `health_regen`, `ammo_exploit`,
> `vehicle_spawn`, `weapon_spawn`, `model_exploit`, `citizen_exploit`) ya son
> tuneables desde `config.lua` sin editar los `.lua` del cliente.

Estructura comun de cada deteccion:
```lua
miDeteccion = {
    enabled = true,            -- on/off
    punishment = 'warn',       -- none|notify|screenshot|warn|kick|ban_temp|ban_perm|teleport|freeze|kill
    banDuration = 'medium',    -- short|medium|long|verylong|permanent
    tolerance = 3,             -- violaciones antes de disparar (lo aplica el core)
    -- ...parametros propios de cada deteccion (umbral, radio, intervalo, etc.)
}
```

Secciones y ejemplos de claves:
- `Config.Movement`: `teleport`, `noclip`, `speedHack`, `superJump`, `flyHack`, `underground`, `wallBreach`.
- `Config.Combat`: `godMode`, `healthHack`, `armorHack`, `rapidFire`, `infiniteAmmo`, `fastReload`, `noRecoil`, `noSpread`, `explosiveSpam`, **`antiTaser`** (nuevo).
- `Config.Ultra`: `citizenExploit`, `aimbotUltra`, `healthRegen`, `ammoExploit`, `vehicleSpawn`, `weaponSpawn`, `modelExploit`, `moneyExploit`.
- `Config.Entities`: `explosion`, `cageTrap`, `vehicleGodMode`, `entityFirewall`, `projectile`, `weaponDamage`, `antiYank`, `superPunch`, `audioFlood`, `magneto`, **`noProps`** (nuevo), **`vehicleInvisible`** (nuevo).
- `Config.Advanced`: `injection`, `afkFarming`, `resourceValidation`, `heartbeat`, `honeypotEvent`, `honeypotCommands`.
- `Config.Blacklists`: `weapons`, `vehicles`, `peds`.

Notas de operacion:
- El `tolerance` se aplica de forma centralizada en `client/core.lua` para todas las detecciones.
- Detecciones economicas del cliente (`money_exploit`) vienen **desactivadas** por defecto:
  el dinero en cliente es evadible; la autoridad real es server-side
  (`Config.ServerAnomaly.economy`).
- Toda deteccion cliente debe existir en `LyxGuardLib.DETECTIONS` (shared/lib.lua)
  o como clave de estas secciones de Config; de lo contrario el servidor la descarta
  en `IsValidDetection`.

## 10) Defaults recomendados por entorno (resumen)
- RP liviano: `Config.RuntimeProfile = 'rp_light'`
- Produccion con picos: `Config.RuntimeProfile = 'production_high_load'`
- Hostil (spoof/flood): `Config.RuntimeProfile = 'hostile'`

