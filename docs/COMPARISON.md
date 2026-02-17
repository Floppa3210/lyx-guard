# LyxGuard - Comparaciones y Alcance

Este documento compara el enfoque de LyxGuard con:
- anticheats open source 
- anticheats de pago conocidos (referencia: FiveGuard y similares)

## 0) Matriz comparativa (10 anticheats vs LyxGuard)

Notas importantes:
- Esta tabla mezcla (a) info publica/documentada y (b) observaciones de ejemplos locales.
- En anticheats de pago, el feature-set real puede variar por plan/version: valida en sus docs oficiales.
- En anticheats open source "de internet", hay forks infectados/obsoletos: no copiar loaders ni exec remoto.

Leyenda:
- `SI`: existe/documentado claramente
- `PARCIAL`: existe, pero depende de implementacion/plan/integ
- `?`: no confirmado
- `RIESGO`: en ejemplos locales detectamos patrones peligrosos (HTTP+exec, ofuscacion, etc)

### A) Anticheats (publicos) - 10 vs LyxGuard

| Producto | Tipo | Safe events/token | Payload hygiene/schema | Rate-limit | Logs/evidencia | Panel | Nota rapida |
|---|---|---|---|---|---|---|---|
| **LyxGuard (este repo)** | OSS | SI (panel+acciones criticas) | SI | SI | SI (JSONL + timeline) | In-game (opcional) | Server-first, trazabilidad y quarantine |
| FiveGuard | Pago | SI (Safe Events documentado) | ? | ? | ? | Web/Panel | Enfoque fuerte en safe-events; ver docs |
| FiniAC | Pago | ? | ? | ? | ? | Web/Panel | Suite con docs publicas; ver docs |
| WaveShield | Pago | ? | ? | ? | ? | Web/Panel | Suite orientada a panel web; ver docs |
| SpaceShield | Pago | ? | ? | ? | ? | Web/Panel | Producto comercial; ver sitio oficial |
| VanillaAC | ? | ? | ? | ? | ? | ? | Info publica limitada; validar por fuentes |
| Valor Shield | Pago | ? | ? | ? | ? | Web/Panel | Producto comercial; validar por fuentes |
| FiveM Secure | ? | ? | ? | ? | ? | ? | Producto/servicio; validar por fuentes |
| MegaAC | Pago | ? | ? | ? | ? | Web/Panel | Producto comercial; validar por fuentes |
| TrueWard | Pago | ? | ? | ? | ? | Web/Panel | Producto comercial; validar por fuentes |

### B) Ejemplos locales (anticheat-copiar) - referencia tecnica

| Ejemplo local | Tipo | Observacion |
|---|---|---|
| TigoAntiCheat-master | OSS | ejemplo desactualizado; requiere auditoria manual |
| rw-anticheat-main | OSS | ejemplo local; requiere auditoria manual |
| FiveM-AntiCheat-main | OSS | RIESGO: en la copia local se detecto ejecucion dinamica (patron loader/exec) |
| pac-antimagicbullet | OSS | modulo enfocado a magic bullet (no suite) |
| AntiMagicBullet | OSS | modulo enfocado a magic bullet (no suite) |
| midnight | ? | depende del repo; revisar por patrones peligrosos antes de usar |
| WaveShield (copia local) | ? | revisar integridad; hay multiples forks/copies en la wild |
| screenshot-basic | OSS | evidence/screenshot (no es anticheat completo) |

Fuentes publicas (referencias):
- FiveGuard Safe Events (manual/auto): https://docs.fiveguard.net/safe-events/manual-safe-events y https://docs.fiveguard.net/safe-events/auto-safe-events
- FiniAC docs: https://docs.fini.ac/ (y pagina principal: https://fini.ac/)
- WaveShield docs: https://docs.waveshield.xyz/ (y repo: https://github.com/AYZNN/WaveShield)
- SpaceShield: https://spaceshield.one/
- VanillaAC: https://vanilla-ac.com/
- Valor Shield: https://valorshield.net/
- FiveM Secure: https://fivemsecure.com/
- MegaAC: https://megaac.store/
- TrueWard: https://trueward.eu/

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

Observacion basada en nuestro scan local (carpetas de ejemplos):
- se detectaron multiples patrones HIGH de "HTTP fetch + ejecucion dinamica"
- tambien aparecieron muchos indicadores MED/LOW de ofuscacion y telemetria dudosa

Numeros (scan local):
- archivos marcados: 147
- coincidencias HIGH: 106
- coincidencias MED: 821
- coincidencias LOW: 106

Conclusion practica:
- no conviene reciclar codigo de loaders/HTTP/exec
- si se rescatan ideas de detecciones, reescribir y validar del lado server (con schema + rate + logs)

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

Detalles publicos (resumen):
- En guias publicas de FiveGuard se describe el sistema de "safe events" basado en tokens adjuntados a eventos y validacion server-side.

## 5) Objetivo de calidad (nivel "pro")
Para competir con anticheats fuertes:
- server-side authority siempre
- logs/evidencia siempre para sanciones graves
- minimizar falsos positivos con quarantine/escalado
- perfiles de tuning consistentes con carga real

LyxGuard esta construido alrededor de esos principios.

## 6) Referencias (lectura opcional)
- FiveGuard (safe events): https://docs.fiveguard.net/safe-events/manual-safe-events
- Tokenizacion open source (idea similar): https://github.com/BrunoTheDev/salty_tokenizer

