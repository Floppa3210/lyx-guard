# Politica de Seguridad

## Reporte de vulnerabilidades
Si encontras una vulnerabilidad, no la publiques en un issue abierto.

Canal recomendado:
- Abrir issue privado en GitHub Security Advisories del repositorio.

Incluir en el reporte:
- descripcion del vector
- impacto esperado
- pasos de reproduccion
- version/commit afectado

## Alcance
Se considera vulnerabilidad, entre otros:
- bypass de permisos en acciones admin
- ejecucion de eventos criticos sin validacion
- anti-replay/token bypass
- omisiones de ban hardening por spoof evidente

## Tiempos objetivo
- confirmacion inicial: 72 horas
- evaluacion tecnica: 7 dias
- parche inicial (si aplica): 30 dias

