# LyxGuard - Comparaciones y Alcance

Este documento compara el enfoque de LyxGuard con:
- anticheats open source (ejemplos locales en `anticheat-copiar`)
- anticheats de pago conocidos (referencia: FiveGuard y similares)

## 1) Alcance real de LyxGuard
LyxGuard se enfoca en lo que mas dano real produce en servidores:
- spoof de eventos admin (txAdmin/paneles/recursos sensibles)
- flood/spam de triggers
- payloads anomales para romper handlers (tablas profundas/strings enormes)
- proteccion de recursos y modulos (heartbeat/tamper)

NO promete "magia":
- aimbot perfecto es dificil sin falsos positivos
- el objetivo es reducir lo que rompe economias/servidor y dar evidencia para moderacion

## 2) Diferencia clave vs anticheats "cliente-first"
Anticheats centrados en cliente sufren:
- el cliente se dumpea
- el cheater parchea el script
- hooks y bypasses

LyxGuard prioriza server-side:
- bloquea eventos antes del handler
- valida payload
- aplica rate-limit
- registra evidencia

El cliente se usa solo como senal auxiliar.

## 3) Lo que vimos en ejemplos locales (anticheat-copiar)
En anticheats de internet se repiten patrones peligrosos:
- loaders por HTTP + `load/loadstring` (backdoors clasicos)
- ofuscacion extrema sin razon
- dominios raros y ejecucion remota

LyxGuard evita esas rutas:
- no ejecuta codigo descargado
- no usa `loadstring`
- mantiene validaciones y listas locales

## 4) Comparacion conceptual con FiveGuard (y similares)
Anticheats tipo FiveGuard suelen ofrecer:
- safe-events / proteccion fuerte de eventos
- detecciones server-side de abuso comun
- evidencia (screenshot/logs)
- panel y auditoria (segun producto)

LyxGuard ya cubre conceptos clave:
- firewall (allowlist + schema + rate-limit)
- anti-replay en rutas sensibles
- anti-spoof de eventos admin
- logs exhaustivos con timeline previo
- perfiles runtime para distintos entornos

Diferencia importante:
- LyxGuard es open source y busca un core seguro y auditable.
- Features SaaS/comerciales (web panel externo, licencias, ecommerce) no son parte del core.

## 5) Objetivo de calidad (nivel "pro")
Para competir con anticheats fuertes:
- server-side authority siempre
- logs/evidencia siempre para sanciones graves
- minimizar falsos positivos con quarantine/escalado
- perfiles de tuning consistentes con carga real

LyxGuard esta construido alrededor de esos principios.

