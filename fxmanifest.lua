--[[
    ██╗  ██╗   ██╗██╗  ██╗     ██████╗ ██╗   ██╗ █████╗ ██████╗ ██████╗
    ██║  ╚██╗ ██╔╝╚██╗██╔╝    ██╔════╝ ██║   ██║██╔══██╗██╔══██╗██╔══██╗
    ██║   ╚████╔╝  ╚███╔╝     ██║  ███╗██║   ██║███████║██████╔╝██║  ██║
    ██║    ╚██╔╝   ██╔██╗     ██║   ██║██║   ██║██╔══██║██╔══██╗██║  ██║
    ███████╗██║   ██╔╝ ██╗    ╚██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝
    ╚══════╝╚═╝   ╚═╝  ╚═╝     ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝

    LyxGuard v4.0 - Modular Anti-Cheat System with Panel

    ARQUITECTURA ESCALABLE:
    - Cada detección es un módulo independiente
    - Añadir detecciones: crear archivo en client/detections/
    - Config centralizado pero extensible
    - Panel de monitoreo en tiempo real
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'lyx-guard'
author 'LyxDevelopment'
description 'Modular Anti-Cheat System v4.0 with Panel'
version '4.0.0'

-- NUI Panel
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

-- Orden de carga importante:
-- 1. Config primero (define opciones globales)
-- 2. Shared (utilidades)
-- 3. Core (API de detecciones)
-- 4. Detecciones individuales
-- 5. Panel (NUI handler)
-- 6. Main (bootstrap)

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua',
    'shared/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- Load order is important: bootstrap/migrations first, then core modules.
    'server/bootstrap.lua',
    'server/migrations.lua',
    'server/utils.lua',
    'server/exhaustive_logs.lua',    -- Exhaustive JSONL/text logging + player timeline
    'server/ban_system.lua',          -- Enhanced HWID ban system
    'server/connection_security.lua', -- Anti-VPN, VAC check, name filter
    'server/punishments.lua',
    'server/quarantine.lua',          -- Warn->Warn->Ban escalation for suspicious signals
    'server/webhooks.lua',
    'server/detections.lua',
    'server/trigger_protection.lua', -- v4.1: Event spam/blacklist protection
    'server/admin_config.lua',       -- v4.1: Admin config callbacks (whitelist, permissions, detections)
    'server/panel.lua',
    'server/main.lua'
}


client_scripts {
    'client/core.lua',                 -- API modular
    'client/protection_loader.lua',    -- Protection module loader
    'client/protections/*.lua',        -- All protection modules
    'client/protection_registrar.lua', -- Auto-register protections
    'client/detections/*.lua',         -- Legacy detection modules
    'client/panel.lua',                -- NUI Panel handler
    'client/main.lua'                  -- Bootstrap
}

dependencies {
    'es_extended',
    'oxmysql'
}

-- Exports públicos
exports {
    'IsPlayerImmune',
    'BanPlayer',
    'UnbanPlayer',
    'GetPlayerWarnings',
    'LogDetection',
    'GetQuarantineState',
    'GetLogger', -- v2.1: Structured logging system
    'PushExhaustiveLog',
    'TrackExhaustivePlayerAction',
    'GetExhaustiveTimeline',
    'FlushExhaustiveLogs'
}
