<div align="center">

# LyxGuard

<img src="docs/banner.svg" alt="LyxGuard Banner" width="720" />

### Anticheat modular **server-first** para FiveM/ESX

<p align="center">
  <strong>Anti-spoof</strong> • <strong>Firewall de eventos</strong> • <strong>Quarantine</strong> • <strong>Logs exhaustivos</strong>
</p>

<p align="center">
  <a href="docs/INSTALL_SERVER.md">📦 Instalacion</a> •
  <a href="docs/DEEP_DIVE.md">🔬 Deep Dive</a> •
  <a href="docs/CONFIG_REFERENCE.md">⚙️ Config</a> •
  <a href="docs/COMPARISON.md">🆚 Comparaciones</a>
</p>

[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=for-the-badge)](LICENSE)
![FiveM](https://img.shields.io/badge/FiveM-resource-black?style=for-the-badge)
![ESX](https://img.shields.io/badge/ESX-supported-green?style=for-the-badge)
[![CI](https://img.shields.io/github/actions/workflow/status/Floppa3210/lyx-guard/qa.yml?style=for-the-badge)](https://github.com/Floppa3210/lyx-guard/actions/workflows/qa.yml)
[![Stars](https://img.shields.io/github/stars/Floppa3210/lyx-guard?style=for-the-badge&logo=github)](https://github.com/Floppa3210/lyx-guard/stargazers)

</div>

---

## Estado del proyecto
- Licencia: `MIT`
- Estado: `Activo`
- Enfoque: bloquear abuso real (spoof admin, flood, payloads anomales) y dejar evidencia trazable
- Instalacion recomendada: **`lyx-guard` + `lyx-panel` juntos**

> Importante: podes ejecutar `lyx-guard` solo, pero la instalacion soportada/recomendada es tener ambos activos (`lyx-guard` + `lyx-panel`). Si falta uno, hay degradacion/inhabilitacion de features dependientes y perdes cobertura/correlacion.

## Que incluye (resumen)
- Firewall server-side:
  - allowlist
  - schema validation
  - rate-limit
  - anti-replay en rutas sensibles
- Anti-spoof:
  - intento de ejecutar eventos admin (LyxPanel/txAdmin/recursos sensibles) sin permisos
- Score de riesgo + quarantine progresiva (reduce falsos positivos).
- Logging exhaustivo a archivos:
  - JSONL + texto
  - timeline previo a warn/ban
  - correlation_id
- Perfiles runtime:
  - `rp_light`
  - `production_high_load`
  - `hostile`

<div align="center">

## Por que usar LyxGuard

</div>

<table>
<tr>
<td width="50%">

### Server-first (lo que importa)

```text
- Bloqueo antes del handler (pre-handler)
- Anti-spoof de eventos admin
- Payload hygiene (deep tables / strings enormes)
```

</td>
<td width="50%">

### Evidencia y operacion

```text
- Logs exhaustivos (JSONL + timeline)
- Quarantine/escalado (menos falsos positivos)
- Perfiles runtime (rp_light/high_load/hostile)
```

</td>
</tr>
</table>

## Instalacion rapida
1. Copiar `lyx-guard` a `resources/[local]/lyx-guard`.
2. Recomendado: copiar `lyx-panel` a `resources/[local]/lyx-panel`.
3. En `server.cfg`:
```cfg
ensure oxmysql
ensure es_extended
ensure lyx-guard
ensure lyx-panel
```
4. Reiniciar y revisar consola (migraciones + firewall + modulos).

Guia completa:
- `docs/INSTALL_SERVER.md`

## Configuracion (entry points)
Archivo: `config.lua`

Perfil runtime:
```lua
Config.RuntimeProfile = 'default' -- rp_light | production_high_load | hostile
```

Logging exhaustivo:
```lua
Config.ExhaustiveLogs.enabled = true
```

Referencia completa de opciones:
- `docs/CONFIG_REFERENCE.md`

## Testing / QA offline
Check de cobertura de schemas/allowlists (recomendado antes de release):
```bash
node tools/qa/check_events.js
```

## Estructura del proyecto
```text
lyx-guard/
  fxmanifest.lua
  config.lua
  README.md
  LICENSE
  SECURITY.md
  CONTRIBUTING.md

  server/         # trigger protection + sanciones + logs
  client/         # checks auxiliares (no authority)
  shared/         # utilidades + blacklists + logger
  database/       # SQL legacy (si aplica)
  logs/           # salida runtime (gitkeep)
  html/           # UI (si aplica)
  tools/qa/       # checks offline
  docs/           # documentacion
```

## Contribuir
Si queres aportar:
- Prioriza cambios pequenos y medibles.
- Si agregas deteccion:
  - umbral
  - metadata de log
  - plan anti falsos positivos

Ver:
- `CONTRIBUTING.md`
- `SECURITY.md`
