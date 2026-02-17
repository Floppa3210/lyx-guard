# LyxGuard

Anticheat modular para FiveM (ESX) con enfoque server-first, validacion estricta de eventos y telemetria exhaustiva.

## Estado
- Proyecto activo
- Idioma principal: Espanol
- Licencia: MIT

## Caracteristicas principales
- Detecciones modulares (movimiento, combate, armas, entidades, inyeccion, eventos).
- Firewall de eventos en servidor con allowlist + schema validation.
- Anti-spoof para rutas criticas (token de sesion + nonce + anti-replay).
- Sistema de riesgo acumulativo y cuarentena progresiva.
- Bans endurecidos (identificadores multiples, hashes de token, fingerprint).
- Logging exhaustivo en JSONL y texto, con timeline previo a sancion.
- Perfiles de ejecucion:
  - `rp_light`
  - `production_high_load`
  - `hostile`

## Requisitos
- FiveM server (recomendado artefacto actualizado).
- `es_extended`
- `oxmysql`

## Instalacion
1. Copiar `lyx-guard` a `resources/[local]/lyx-guard`.
2. Asegurar dependencias en `server.cfg`:
```cfg
ensure oxmysql
ensure es_extended
ensure lyx-guard
```
3. Reiniciar servidor.
4. Revisar logs de arranque para confirmar migraciones y modulos.

## Configuracion rapida
- Archivo principal: `config.lua`
- Perfil runtime:
```lua
Config.RuntimeProfile = 'production_high_load'
```
- Logging exhaustivo:
```lua
Config.ExhaustiveLogs = {
  enabled = true,
  writeJsonl = true,
  writeText = true
}
```

## Seguridad (modelo)
- Todo lo sensible se valida en servidor.
- El cliente se usa para telemetria y verificaciones auxiliares, no como autoridad.
- Se bloquea ejecucion dinamica riesgosa (`load`/`loadstring`) en bootstrap.

## Estructura
- `client/` detecciones y telemetria cliente.
- `server/` sanciones, firewall, detecciones server-side, logs, migraciones.
- `shared/` utilidades comunes.
- `html/` interfaz del panel interno de guard.

## Roadmap
El roadmap de trabajo y decisiones se mantiene en:
- `README_ROADMAP_CONVERSACION.md` (raiz del workspace de desarrollo)

## Contribuir
Revisar:
- `CONTRIBUTING.md`
- `SECURITY.md`

## Licencia
Este proyecto se distribuye bajo licencia MIT. Ver `LICENSE`.

