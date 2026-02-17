# Perfil Produccion Alta Carga (LyxPanel + LyxGuard)

Este perfil esta pensado para servidores ESX con picos de eventos altos y para reducir falsos positivos sin desactivar seguridad.

## 1) LyxPanel

Archivo: `lyx-panel/config.lua`

Opciones recomendadas finales en `Config.RuntimeProfile`:
- `rp_light`
- `production_high_load`
- `hostile`

Recomendacion:
- RP liviano / foco en falsos positivos bajos: `rp_light`
- Produccion con carga alta normal: `production_high_load`
- Entorno con ataques/flood: `hostile`

Ejemplo:
```lua
Config.RuntimeProfile = 'production_high_load'
```

## 2) LyxGuard

Archivo: `lyx-guard/config.lua`

Opciones en `Config.RuntimeProfile`:
- `default`
- `rp_light`
- `production_high_load`
- `hostile`

Recomendacion:
- Servidor normal: `default`
- Alta carga / muchos eventos por minuto: `production_high_load`
- Entorno hostil / ataques frecuentes: `hostile`

Ejemplo:
```lua
Config.RuntimeProfile = 'production_high_load'
```

## 3) Valores clave que ajusta el perfil alto

LyxPanel:
- `Security.adminEventFirewall.maxEventsPerWindow`
- `Security.adminEventFirewall.maxArgs`
- `Security.adminEventFirewall.actionSecurity.tokenTtlMs`
- `Security.adminEventFirewall.actionSecurity.nonceTtlMs`
- `ActionLimits.guardSafeMs`
- `RefreshInterval`

LyxGuard:
- `TriggerProtection.massiveTriggersPerMinute`
- `TriggerProtection.spamScale`
- `EventFirewall.maxArgs/maxStringLen/maxTotalKeys`
- `TriggerProtection.guardPanelEventProtection.actionSecurity.*`
- `Quarantine.reasonCooldownMs`

## 4) Modo Hostil (mas cerrado)

Usalo solo si el servidor esta recibiendo ataques frecuentes (spoof de eventos admin, flood o payloads maliciosos).

LyxPanel:
```lua
Config.RuntimeProfile = 'hostile'
```

LyxGuard:
```lua
Config.RuntimeProfile = 'hostile'
```

Valores exactos del modo hostil activo:

LyxPanel (`lyx-panel/config.lua`):
- `Security.adminEventFirewall.maxEventsPerWindow = 90`
- `Security.adminEventFirewall.windowMs = 7000`
- `Security.adminEventFirewall.maxArgs = 8`
- `Security.adminEventFirewall.maxDepth = 4`
- `Security.adminEventFirewall.maxKeysPerTable = 48`
- `Security.adminEventFirewall.maxTotalKeys = 240`
- `Security.adminEventFirewall.maxStringLen = 320`
- `Security.adminEventFirewall.sessionStateFailOpen = false` (fail-closed si no se puede validar sesion)
- `Security.adminEventFirewall.actionSecurity.tokenTtlMs = 120000`
- `Security.adminEventFirewall.actionSecurity.nonceTtlMs = 180000`
- `Security.adminEventFirewall.actionSecurity.maxUsedNonces = 2048`

LyxGuard (`lyx-guard/config.lua`):
- `TriggerProtection.massiveTriggersPerMinute = 70000`
- `TriggerProtection.spamScale = 3.0`
- `TriggerProtection.spamFlagCooldownMs = 5000`
- `TriggerProtection.massiveFlagCooldownMs = 10000`
- `EventFirewall.maxArgs = 16`
- `EventFirewall.maxDepth = 6`
- `EventFirewall.maxKeysPerTable = 140`
- `EventFirewall.maxTotalKeys = 1200`
- `EventFirewall.maxStringLen = 3072`
- `EventFirewall.maxTotalStringLen = 12000`

Detecciones criticas reforzadas:
- `lyxguard_panel_event_spoof`
- `lyxguard_panel_event_schema`
- `lyxpanel_admin_event_spoof`
- `txadmin_event_spoof`

## 5) Recomendacion de despliegue

1. Activar perfiles en ambos recursos.
2. Reiniciar `lyx-guard` y `lyx-panel`.
3. Revisar logs de 20-30 minutos.
4. Si hay ruido de eventos legitimos, subir solo estos parametros:
   - `Config.TriggerProtection.massiveTriggersPerMinute`
   - `Config.Security.adminEventFirewall.maxEventsPerWindow`

## 6) Nota importante

Sin entorno real no se puede calibrar al 100%. Este perfil ya deja limites altos y mantiene el bloqueo de payload/eventos anomalos y spoofing.
