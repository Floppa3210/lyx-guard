# PACK PARITY PASS 2 (EVIDENCIA TECNICA)

Fecha: 2026-02-17  
Objetivo: demostrar con archivos/lineas que bloques del pack ya existen en Lyx.

## 1) Anti-spoof de acciones admin (token + nonce + anti-replay)

- `lyx-panel/server/main.lua:39`
- `lyx-panel/server/main.lua:40`
- `lyx-panel/server/main.lua:188`
- `lyx-panel/server/main.lua:226`
- `lyx-panel/server/main.lua:251`
- `lyx-panel/server/main.lua:252`
- `lyx-panel/server/main.lua:259`
- `lyx-panel/server/main.lua:2522`

Resultado: **implementado**.

## 2) Firewall admin (allowlist + schema + rate-limit + sancion)

- `lyx-panel/server/event_firewall.lua:1651`
- `lyx-panel/server/event_firewall.lua:1669`
- `lyx-panel/server/event_firewall.lua:2409`
- `lyx-panel/server/event_firewall.lua:2412`
- `lyx-panel/server/event_firewall.lua:2478`
- `lyx-panel/server/event_firewall.lua:2497`
- `lyx-panel/server/event_firewall.lua:2517`
- `lyx-panel/server/event_firewall.lua:2551`

Resultado: **implementado**.

## 3) Auditoria avanzada + export

- `lyx-panel/server/main.lua:1817`
- `lyx-panel/server/main.lua:1843`
- `lyx-panel/client/main.lua:235`
- `lyx-panel/client/main.lua:241`
- `lyx-panel/html/js/app_extended.js:1186`
- `lyx-panel/html/js/app_extended.js:1241`

Resultado: **implementado**.

## 4) Permisos granulares (rol + individual) desde panel

- `lyx-panel/server/main.lua:2072`
- `lyx-panel/server/main.lua:2143`
- `lyx-panel/server/main.lua:2178`
- `lyx-panel/server/migrations.lua:247`
- `lyx-panel/server/migrations.lua:254`
- `lyx-panel/server/migrations.lua:265`
- `lyx-panel/server/permissions_store.lua:74`

Resultado: **implementado**.

## 5) Dry-run de acciones destructivas + permiso dedicado wipe

- `lyx-panel/server/actions.lua:3305`
- `lyx-panel/server/actions.lua:3307`
- `lyx-panel/server/actions.lua:3348`
- `lyx-panel/server/actions.lua:3146`
- `lyx-panel/server/actions.lua:3158`
- `lyx-panel/server/actions.lua:3276`
- `lyx-panel/server/actions.lua:3287`

Resultado: **implementado**.

## 6) Ticket system (workflow in-game)

- `lyx-panel/server/tickets.lua:144` (comando `/ticket`)
- `lyx-panel/server/migrations.lua:387` (campos workflow + asignacion/cierre)
- `lyx-panel/server/actions.lua:3368` (assign/reply/close/reopen)
- `lyx-panel/html/index.html:50` (pestaña Tickets)
- `lyx-panel/html/js/app_extended.js:208` (UI load/assign/reply/close/reopen)

Resultado: **implementado** (crear/asignar/responder/cerrar/reabrir + historial).

## 7) Screenshot evidence

- `lyx-panel/server/actions.lua:2150`
- `lyx-panel/server/actions.lua:2162`
- `lyx-panel/server/actions.lua:2174`
- `lyx-panel/server/actions.lua:2221`
- `lyx-guard/config.lua:1167`

Resultado: **implementado**.

## 8) Dependencia cruzada panel <-> guard

- `lyx-panel/server/bootstrap.lua:103`
- `lyx-panel/server/bootstrap.lua:133`
- `lyx-panel/server/bootstrap.lua:140`
- `lyx-panel/server/actions_extended.lua:111`
- `lyx-panel/server/actions_extended.lua:584`

Resultado: **implementado** (degradacion controlada y advertencias).

## 9) Hardening anticheat server-side

- `lyx-guard/server/trigger_protection.lua:2229` (txAdmin spoof)
- `lyx-guard/server/trigger_protection.lua:2234` (LyxPanel spoof)
- `lyx-guard/server/trigger_protection.lua:2239` (LyxGuard panel spoof)
- `lyx-guard/server/trigger_protection.lua:2365` (strict allowlist namespace)
- `lyx-guard/server/trigger_protection.lua:2442` (schema validation)
- `lyx-guard/server/trigger_protection.lua:2262` (nonce replay)

Resultado: **implementado**.

## 10) Quarantine (2 avisos, 3ra -> ban 90 dias)

- `lyx-guard/server/quarantine.lua:5`
- `lyx-guard/server/quarantine.lua:6`
- `lyx-guard/server/quarantine.lua:122`
- `lyx-guard/server/quarantine.lua:123`
- `lyx-guard/server/quarantine.lua:169`
- `lyx-guard/server/quarantine.lua:214`

Resultado: **implementado**.

## 11) Logs exhaustivos + timeline + evidence pack

- `lyx-guard/server/exhaustive_logs.lua:25`
- `lyx-guard/server/exhaustive_logs.lua:26`
- `lyx-guard/server/exhaustive_logs.lua:27`
- `lyx-guard/server/exhaustive_logs.lua:472`
- `lyx-guard/server/exhaustive_logs.lua:513`
- `lyx-guard/server/exhaustive_logs.lua:554`
- `lyx-guard/server/punishments.lua:487`
- `lyx-guard/server/punishments.lua:779`

Resultado: **implementado**.

## 12) Perfiles de carga + anti-vpn opcional + ban hardening DB

- `lyx-guard/config.lua:45`
- `lyx-guard/config.lua:48`
- `lyx-guard/config.lua:399`
- `lyx-guard/config.lua:940`
- `lyx-guard/config.lua:1105`
- `lyx-guard/server/migrations.lua:236`
- `lyx-guard/server/migrations.lua:241`
- `lyx-guard/server/migrations.lua:243`

Resultado: **implementado** (anti-vpn opcional/desactivado por defecto).
