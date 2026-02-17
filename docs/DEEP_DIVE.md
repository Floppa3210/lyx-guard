# LyxGuard - Como Funciona (Deep Dive)

Este documento describe LyxGuard a profundidad: proteccion de triggers/eventos, anti-spoof, score/quarantine, sanciones y logging exhaustivo.

## 1) Objetivo de diseno
LyxGuard es un anticheat **server-first**.
El cliente aporta senales auxiliares, pero el servidor es el que:
- valida
- decide
- sanciona
- registra evidencia

## 2) Componentes
Servidor (core):
- `server/trigger_protection.lua`: deteccion/bloqueo de spoof, spam, payloads y namespaces
- `server/punishments.lua`: sanciones (warn/kick/ban)
- `server/quarantine.lua`: escalado progresivo para casos grises
- `server/exhaustive_logs.lua`: logs a archivo + timeline previo a sancion
- `server/ban_system.lua`: persistencia/consultas de bans
- `server/detections.lua`: agregador de detecciones

Cliente (auxiliar):
- `client/protection_loader.lua` + `client/protection_registrar.lua`: loader seguro de modulos
- `client/detections/*.lua`: senales y checks
- `client/protections/*.lua`: protecciones (noclip/godmode/entities/etc)

Shared:
- `shared/structured_logger.lua`: formato consistente (nivel, correlation_id, metadata)
- `shared/blacklists/*.lua`: listas negras versionables

## 3) Firewall y trigger protection (server-side)
La parte mas importante es bloquear el abuso **antes** de que llegue a handlers sensibles.

LyxGuard aplica:
- allowlist de namespaces/eventos criticos
- limites de args, profundidad, keys, largo de strings (payload hygiene)
- schema validation para eventos protegidos
- rate-limit por jugador / evento / ventana de tiempo
- deteccion de patrones (rafagas) ademas de conteos simples

## 4) Anti-spoof (caso real)
Amenaza comun:
Un cheater ejecuta un evento de admin (LyxPanel / txAdmin / otros recursos) sin tener permisos.

LyxGuard lo trata como severidad alta:
- registra intento (actor, evento, payload)
- bloquea
- aplica cooldown por razon
- escala segun reincidencia (perfil runtime)

## 5) Score de riesgo y Quarantine
Por que existe quarantine:
- En FiveM hay ruido (falsos positivos) si baneas por 1 senal debil.
- El objetivo es escalar con evidencia:
  - warning 1
  - warning 2
  - ban (segun politica)

LyxGuard implementa:
- score acumulativo por sesion
- weights por razon
- cooldowns por razon (para no spamear)
- quarantine para restringir/observar antes de ban final

## 6) Sanciones y persistencia
LyxGuard soporta:
- warn
- kick
- ban temporal
- ban permanente

Buenas practicas:
- ban permanente solo para detecciones de alta confianza (spoof admin, loaders, inyeccion clara)
- ban temporal para patrones repetidos con evidencia pero posibilidad de ruido

## 7) Logging exhaustivo (archivos)
Objetivo:
Poder responder siempre:
- que paso
- cuando
- quien lo hizo
- con que payload
- que hizo el jugador en los 60s previos

Formatos:
- JSONL (procesable)
- texto (legible)

Campos tipicos:
- `timestamp_utc`
- `level` (debug/info/warn/high/critical)
- `correlation_id`
- `actor` (player/admin/system)
- `event` / `reason`
- `result`
- `metadata`

## 8) Perfiles (rp_light / production_high_load / hostile)
Los perfiles ajustan:
- limites del firewall
- thresholds de spam
- cooldowns por razon
- tolerancias de heartbeat/modulos

Regla:
- no uses `hostile` en servers tranquilos si no es necesario
- si hay flood/spoof real, `hostile` reduce superficie pero puede bloquear mas ruido legitimo

## 9) Integracion con LyxPanel
Cuando ambos estan activos:
- mejor trazabilidad de acciones admin (panel) + enforcement del guard
- mejor proteccion ante spoof de eventos admin

Sin LyxPanel:
- LyxGuard sigue funcionando y bloqueando ataques a recursos comunes
- solo perdes la capa de correlacion con acciones UI del panel

## 10) Extender LyxGuard de forma segura (guia para devs)
Si agregas una deteccion nueva:
1. Definir severidad y confianza.
2. Definir schema si aplica (eventos).
3. Aplicar rate-limit.
4. Registrar logs con metadata.
5. Agregar a quarantine/score con cooldown por razon.
6. Probar en `rp_light` primero y luego endurecer.

