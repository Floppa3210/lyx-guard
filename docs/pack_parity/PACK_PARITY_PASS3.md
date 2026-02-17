# PACK PARITY PASS 3 (BRECHAS Y RIESGOS REALES)

Fecha: 2026-02-17  
Objetivo: marcar lo que falta respecto al pack y los riesgos residuales actuales.

## 1) Brechas funcionales (faltantes reales)

### Bloques NO implementados (SaaS/comercial)

- Web panel externo Node.js/Express/TypeScript (multi-tenant).
- OAuth2 Discord / login web dedicado.
- Product management y key management comercial.
- E-commerce (Stripe/PayPal, webhook de pagos, suscripciones).
- Discord bot para ventas/licencias (`/products`, `/redeemkey`, etc).
- Config sharing comunitario (biblioteca publica, ratings, share-code, expiracion).
- Upload/file manager web completo (galeria, busqueda, storage analytics).
- Live stream continuo de pantalla de jugadores en panel web externo.

### Bloques PARCIALES

- Ticket system: hay base de datos y lectura, pero no portal SaaS completo de soporte multicanal.
- Analytics: hay dashboard NUI, no stack BI/web avanzado con historicos completos estilo SaaS.
- Multi-language: existe base de locales, no suite i18n completa de producto comercial.

## 2) Riesgos residuales detectados

1. `lyx-panel/server/event_firewall.lua` (session state fallback)
- Estado: **mitigado**.
- Ahora es configurable por perfil via `Config.Security.adminEventFirewall.sessionStateFailOpen`.
  - Default: `true` (fail-open, evita romper produccion si el provider de sesion no esta disponible).
  - `hostile`: `false` (fail-closed, bloquea acciones que requieren sesion si no se puede validar).

2. Sin pruebas E2E reales en servidor productivo
- Actualmente no hay entorno FiveM activo para validacion real de carga y falsos positivos.
- Recomendacion: smoke tests con bots + replay de eventos antes de release estable.

3. Diferencia de alcance (ingame security vs SaaS comercial)
- Intentar meter ecommerce/bot/pagos dentro del recurso Lua aumenta superficie de ataque.
- Recomendacion: separar arquitectura en dos proyectos:
  - Core ingame seguro (actual)
  - Plataforma externa opcional (nuevo backend).

## 3) Conclusiones de PASS 3

- Lyx **no tiene todo** lo del pack comercial, y eso es correcto por alcance actual.
- En seguridad server-side y control admin ingame, la cobertura es alta.
- Lo que falta pertenece en su mayoria al eje SaaS/comercial, no al core anticheat.
