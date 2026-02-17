# Contribuir a LyxGuard

Gracias por colaborar.

## Flujo recomendado
1. Crear rama desde `main`.
2. Hacer cambios atomicos por tema.
3. Ejecutar validaciones locales basicas (sintaxis y coherencia).
4. Abrir PR con contexto tecnico claro.

## Reglas de calidad
- Seguridad primero: cualquier accion critica debe validar permiso, rate-limit y payload.
- Evitar duplicacion de utilidades.
- Mantener nombres y estructura consistentes.
- No introducir ejecucion dinamica riesgosa.

## Estilo de PR
Incluir:
- Problema que resuelve.
- Riesgos y regresiones posibles.
- Archivos afectados.
- Pasos de prueba.

## Alcance
Se aceptan mejoras de:
- detecciones server-side
- hardening de eventos
- observabilidad y auditoria
- reduccion de falsos positivos

