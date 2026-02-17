# LyxGuard - Instalacion y Configuracion (Servidor)

Este documento explica como instalar y configurar `lyx-guard` de forma segura en un servidor FiveM/ESX.

Recomendacion fuerte: correr **`lyx-guard` + `lyx-panel`** juntos.
`lyx-guard` protege el servidor por si mismo, pero la integracion con LyxPanel mejora el control de acciones admin y la trazabilidad/auditoria.

## 1) Requisitos
- FiveM (artefacto actualizado).
- `es_extended` (ESX).
- `oxmysql`.
- Recomendado: `lyx-panel`.

## 2) Instalacion (archivos)
1. Copiar carpeta `lyx-guard` a:
   - `resources/[local]/lyx-guard`
2. Copiar tambien `lyx-panel` (recomendado) a:
   - `resources/[local]/lyx-panel`

## 3) server.cfg (orden recomendado)
```cfg
ensure oxmysql
ensure es_extended

ensure lyx-guard
ensure lyx-panel
```

## 4) Base de datos
LyxGuard aplica migraciones versionadas al iniciar.

Puntos a revisar:
- `oxmysql` conectando OK (host/user/pass/database).
- Permisos MySQL: `CREATE`, `ALTER`, `INDEX`, `INSERT`, `UPDATE`, `SELECT`.

## 5) Configuracion basica (defaults)
Archivo: `config.lua`

### 5.1 Perfil runtime
```lua
Config.RuntimeProfile = 'default'
```

Perfiles:
- `rp_light`: mas tolerante (minimiza falsos positivos).
- `production_high_load`: recomendado para servers con picos de eventos altos.
- `hostile`: endurecido contra spoof/flood/payloads anomales.

### 5.2 Logging exhaustivo (archivos)
```lua
Config.ExhaustiveLogs = {
  enabled = true,
  writeJsonl = true,
  writeText = true
}
```

Salida:
- `logs/` (incluye `.gitkeep`, la carpeta se usa en runtime)

### 5.3 Proteccion de eventos (conceptos)
LyxGuard protege:
- allowlist de eventos/namespaces
- schema validation (tipos/rangos/longitudes, limites de profundidad)
- rate-limit y escalado por patron
- anti-replay para rutas sensibles

## 6) Integracion con LyxPanel (dependencia cruzada)
Si `lyx-panel` esta activo:
- mejor coherencia en permisos/auditoria
- mejor deteccion de spoof de acciones admin
- mejor correlacion de incidentes (correlation_id)

Si `lyx-panel` NO esta activo:
- LyxGuard sigue protegiendo el servidor.
- ciertas rutas integradas se degradan/deshabilitan.

## 7) Troubleshooting rapido
### Falsos positivos
- usar `rp_light` o `production_high_load`
- revisar logs exhaustivos (timeline previo a warn/ban)
- subir limites de spam si tu server dispara eventos legitimos en rafagas

### Alto uso de CPU por logs
- desactivar `writeText` o `writeJsonl` si necesitas
- aumentar throttles (config)

### No se crean logs
- confirmar que `Config.ExhaustiveLogs.enabled` sea true
- verificar permisos de escritura del recurso

## 8) Checklist recomendado (produccion)
- `Config.EventFirewall.enabled = true`
- perfil consistente con carga real (`production_high_load` si hay picos)
- logs exhaustivos activados al menos en fase de estabilizacion
- `lyx-panel` activo si usas panel in-game

