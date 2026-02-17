# PACK PARITY PASS 1

Fecha: 2026-02-17  
Objetivo: comparar `lyx-panel` + `lyx-guard` contra la lista del pack comercial compartido.

## Veredicto rapido

- Seguridad anticheat/eventos: **fuerte**
- Admin panel ingame: **fuerte**
- Stack SaaS comercial (Node web panel + pagos + key system + bot): **no implementado**

## Matriz por bloques

| Bloque del pack comercial | Estado en Lyx | Resultado |
|---|---|---|
| Firewall admin (permiso/rate/schema) | Existe | SI |
| Anti-spoof (token/nonce/anti-replay) | Existe | SI |
| Logs exhaustivos + correlacion + timeline | Existe | SI |
| Quarantine escalada (warn->warn->ban) | Existe | SI |
| Perfiles de carga (`rp_light`, `production_high_load`, `hostile`) | Existe | SI |
| Detecciones anticheat (weapons/godmode/entity/events/injection) | Existe | SI |
| Permisos por rol y por usuario desde UI | Existe | SI |
| Auditoria con filtros + export | Existe | SI |
| Dry-run en acciones destructivas | Existe | SI |
| Screenshot evidence | Existe | SI |
| Tickets in-game (NUI) | Existe | SI |
| Ticket portal web externo tipo SaaS | No | NO |
| Dashboard/analytics avanzados tipo SaaS | Basico/NUI | PARCIAL |
| Config manager web full + versioning + sharing publico | No completo | PARCIAL/NO |
| Live stream de pantalla en panel web externo | No | NO |
| Node.js backend de panel (Express/TS) | No | NO |
| OAuth2 Discord/login web | No | NO |
| Product management + key management comercial | No | NO |
| Stripe/PayPal + ecommerce | No | NO |
| Discord bot de ventas/comandos | No | NO |
| Config sharing comunitario (rating/share code/library) | No | NO |

## Conclusiones

1. En seguridad real de servidor (lo mas importante), Lyx esta bien encaminado.
2. El pack comercial mezcla anticheat + producto SaaS de ventas/licencias.
3. Hoy Lyx cubre bien el lado tecnico de seguridad/admin ingame, pero no el lado comercial/SaaS.

## Alcance recomendado

- Mantener Lyx como proyecto open source tecnico (seguridad/admin).
- Si queres el bloque SaaS (tienda, licencias, OAuth, bot), hacerlo como proyecto separado para no contaminar el core anticheat.
