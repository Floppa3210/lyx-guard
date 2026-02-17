# PACK PARITY PASS 4 (PLAN DE CIERRE PRIORIZADO)

Fecha: 2026-02-17  
Objetivo: plan accionable para cerrar pendientes sin romper el core de seguridad.

## Fase A - Hardening inmediato (core actual)

- [x] Firewall fail-closed configurable por perfil (`hostile`).
  - Implementado via `Config.Security.adminEventFirewall.sessionStateFailOpen` (default `true`, `hostile=false`).
- [x] Cobertura 100% de schema/rate-limit en TODOS los `RegisterNetEvent` sensibles (core).
- [x] QA offline obligatorio antes de release:
  - `node lyx-panel/tools/qa/check_events.js`
  - `node lyx-guard/tools/qa/check_events.js`
  - runner: `tools/qa/run_all_checks.ps1`
- [x] Revisar y cerrar cualquier accion admin con bypass indirecto (best-effort + QA de cobertura).

Criterio de cierre:
- Ningun evento critico sin permiso + rate + schema + envelope valido.

## Fase B - Panel ingame avanzado (sin SaaS externo)

1. Ticket workflow completo dentro del panel:
   - crear
   - asignar
   - responder
   - cerrar
   - historial
2. Auditoria con filtros guardables + panel de alertas.
3. Dashboard de salud operativo:
   - estado guard/panel
   - heartbeat
   - riesgo por jugador
4. Mejoras UX finales:
   - paginacion consistente
   - mensajes de error estandar
   - acciones en lote con confirmacion fuerte.

Criterio de cierre:
- Flujo staff de moderacion 100% desde UI sin comandos manuales.

## Fase C - Anticheat pro (server-first)

1. Expandir detecciones server-side de economia/inventario por anomalias correladas.
2. Mejorar motor de score:
   - pesos por perfil
   - enfriamiento por razon
   - evidencia automatica por umbral.
3. Endurecer anti-spoof:
   - mayor telemetria de identidad
   - sancion escalada por reincidencia multi-senal.
4. Matriz de falsos positivos por deteccion (documentada).

Criterio de cierre:
- Baja tasa de falsos positivos con trazabilidad completa de cada sancion.

## Fase D - Opcional SaaS separado (si realmente se quiere paridad comercial)

1. Crear repo separado de backend web:
   - Node.js + API externa
   - auth OAuth2
   - roles multi-tenant
2. Integrar panel web externo solo por API segura (no mezclar con recurso Lua).
3. Si se decide ecommerce/licencias:
   - modulo aislado
   - secretos fuera del recurso FiveM
   - auditoria de seguridad independiente.

Criterio de cierre:
- Ninguna logica de pagos/licencias dentro del core ingame.

## Decision recomendada

- Mantener `lyx-panel` + `lyx-guard` como core open source de seguridad/admin.
- Tratar el stack comercial tipo SaaS como proyecto separado y opcional.
