# LyxGuard - Config Reference

Este documento resume las opciones mas importantes de `config.lua` y sus defaults "stock".
LyxGuard tiene muchas opciones; este archivo prioriza las que afectan seguridad, falsos positivos y operacion.

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

## 9) Defaults recomendados por entorno (resumen)
- RP liviano: `Config.RuntimeProfile = 'rp_light'`
- Produccion con picos: `Config.RuntimeProfile = 'production_high_load'`
- Hostil (spoof/flood): `Config.RuntimeProfile = 'hostile'`

