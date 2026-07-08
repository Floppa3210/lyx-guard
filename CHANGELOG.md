# Changelog — LyxGuard

## v4.4 — Configuración fácil, presets y panel dinámico

Objetivo: que cualquiera pueda configurar el AC sin miedo. Configuración simple y
mayormente booleana, presets con defaults sensatos y un panel que edita TODAS las
detecciones en vivo. Todo aditivo: no rompe `config.lua` ni el pipeline server.

### Configuración fácil (`config_easy.lua`)
- Nuevo archivo boolean-first y documentado en español. Se carga después de `config.lua`
  y solo ajusta `enabled` + `punishment`/`banDuration` de cada detección según un preset.
- `Config.Preset`: `estricto` (default), `balanceado`, `suave`, `custom`, `manual`.
- `Config.Easy`: un `true/false` por detección (prende/apaga).
- `Config.CustomPreset`: el usuario decide el castigo de cada detección (fallback = estricto).
- Clasificación interna por severidad (blatant/severe/medium/minor) → cada preset asigna
  el castigo por clase. Cheat claro (spawn vehículo/arma, aimbot, injection, godmode,
  modelExploit, honeypots) = **ban permanente** en estricto. `moneyExploit` off por defecto.
- La lógica de presets se expone como `LyxGuardEasy` para reutilizarla desde el panel.

### Panel dinámico (todas las detecciones)
- La página de detecciones ya no está hardcoded a 14: se genera dinámicamente desde el
  servidor con TODAS las detecciones, agrupadas (Movimiento/Combate/Ultra/Entidades/
  Avanzado/Listas negras), con toggle + castigo, buscador y contador de activas.
- Selector de preset + botón "Aplicar preset" que setea los castigos de golpe.
- Nuevos callbacks: `getAllDetections`, `getPresetPunishments` (+ bridges NUI).

### Persistencia + aplicación en vivo
- `Config.PanelPersistence`: `database` (default), `json` u `off`.
- Migración v4: tablas `lyxguard_config_overrides` y `lyxguard_config_meta`.
- Los cambios del panel se persisten y se **re-envían a los clientes conectados**
  (`lyxguard:updateDetectionConfig`) para aplicarse sin reiniciar el recurso.
- Al arrancar, los overrides persistidos se cargan y aplican automáticamente.

## v4.3 — Unificacion del client-side de detecciones

Objetivo: consolidar el client-side en un unico framework, eliminar duplicacion y
codigo muerto, corregir bugs de evidencia, completar paridad PL-Protect y endurecer
los syncs sensibles. Sin cambios de comportamiento en el server-side (solo se amplio
la entrega de config y la lista de detecciones validas). Cambios aditivos: no rompe
configuraciones existentes.

### Unificacion de framework
- Un unico framework de deteccion: `RegisterDetection` (client/core.lua). Se retiro el
  sistema paralelo `client/protections/` viejo y su loader/registrar redundantes.
- Eliminados `client/protection_loader.lua` y `client/protection_registrar.lua`
  (habia **dos loops** de ejecucion sobre tablas distintas). Ahora hay un solo loop.
  Los exports `RegisterProtection`/`GetProtection`/`SetProtectionEnabled` se movieron a
  `client/core.lua` (compatibilidad preservada).
- Borrados 11 modulos `anti_*` duplicados/rotos que ignoraban `Config` (leian claves
  inexistentes) y duplicaban detecciones ya presentes:
  `anti_godmode, anti_health, anti_armor, anti_teleport, anti_speed, anti_noclip,
  anti_magicbullet, anti_weapon, anti_vehicle, anti_aimbot, anti_explosion`.
- Conservados `anti_entity` y `anti_yank` (event-driven, config-correctos).
  `anti_tazer` migrado a `client/detections/anti_taser.lua` (framework unificado).

### Deduplicacion de detecciones (colisiones de nombre)
Se resolvieron ~10 nombres registrados por duplicado (que corrian 2+ veces). Quedo una
sola implementacion por nombre (la mejor):
- `aimbot` → combat_advanced.lua · `godmode`/`god_mode` → player_state.lua
- `superjump` → misc.lua · `infinite_ammo` → weapon_exploits.lua
- `rapidfire` → weapons.lua · `resource_injection` → injection.lua
- `explosion_spam` → spam.lua · `invisible` → player_state.lua

### Bugs corregidos
- "Report-after-reset": `flyhack` y `vehiclegodmode` ya no envian evidencia en 0
  (se captura el valor antes de resetear el contador).
- `functionhook`: reescrito (antes solo comprobaba `type()==function`, inutil); ahora
  detecta reemplazo/hook de natives criticas por identidad de referencia.
- `executor_detection`: eliminado codigo muerto (`suspiciousFunctions` sin usar);
  ahora detecta globales de ejecutor reales en `_G`.
- `damage_modifier`: usaba el hash del *setter* como getter (no leia ni reseteaba);
  ahora usa `GetPlayerWeaponDamageModifier` / `SetPlayerWeaponDamageModifier`.
- `no_recoil` (combat_advanced): deshabilitado (falso negativo permanente por
  `GetWeaponRecoilShakeAmplitude<=0`). El no-recoil real vive en weapons.lua.
- `anti_yank`: `GetPedSeatIndex` pasa a ser `local` (no contamina el namespace global).

### Paridad PL-Protect / cobertura
- Nueva deteccion **anti-taser** (`anti_taser`) con fix de cooldown por flanco de disparo.
- `LyxGuardLib.DETECTIONS` sincronizado 1:1 con los nombres realmente registrados
  (antes decenas de detecciones cliente legitimas se descartaban en el servidor por
  `IsValidDetection`).
- Nuevos bloques de config tuneables: `Config.Entities.noProps`,
  `Config.Entities.vehicleInvisible`, `Config.Combat.antiTaser`.
- `Locales` (es/en) añadidos para las detecciones nuevas.
- `money_exploit` (client) **desactivado** por defecto: evadible; la autoridad economica
  es server-side (`Config.ServerAnomaly.economy`).

### Config / seguridad
- `lyxguard:getConfig` ahora envia `Config.Ultra` al cliente → las 8 detecciones Ultra
  son tuneables desde `config.lua`.
- Los syncs `lyxguard:sync:playerData` / `sync:weapons` se enrutan por el
  **Secure Bridge (HMAC + nonce)** cuando esta disponible, con fallback seguro a
  `TriggerServerEvent` (el servidor valida rangos igual).

### QA
- `node tools/qa/check_events.js` pasa (cobertura allowlist/schema intacta).
- Todos los `.lua` del recurso verificados con `luac -p`.
