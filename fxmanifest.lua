-- LyxGuard - Modular Anti-Cheat for FiveM/ESX

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'lyx-guard'
author 'LyxDevelopment'
description 'Anticheat modular con panel y telemetria avanzada'
version '4.0.1'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/vendor/fontawesome/css/*.css',
    'html/vendor/fontawesome/webfonts/*'
}

-- Orden de carga:
-- 1) Config y shared
-- 2) Modulos server core
-- 3) Detecciones y panel
shared_scripts {
    '@es_extended/imports.lua',
    'config.lua',
    'shared/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bootstrap.lua',
    'server/migrations.lua',
    'server/utils.lua',
    'server/exhaustive_logs.lua',
    'server/ban_system.lua',
    'server/connection_security.lua',
    'server/punishments.lua',
    'server/quarantine.lua',
    'server/webhooks.lua',
    'server/detections.lua',
    'server/trigger_protection.lua',
    'server/admin_config.lua',
    'server/panel.lua',
    'server/main.lua'
}

client_scripts {
    'client/core.lua',
    'client/protection_loader.lua',
    'client/protections/*.lua',
    'client/protection_registrar.lua',
    'client/detections/*.lua',
    'client/panel.lua',
    'client/main.lua'
}

dependencies {
    'es_extended',
    'oxmysql'
}

exports {
    'IsPlayerImmune',
    'BanPlayer',
    'UnbanPlayer',
    'GetPlayerWarnings',
    'LogDetection',
    'GetQuarantineState',
    'GetLogger',
    'PushExhaustiveLog',
    'TrackExhaustivePlayerAction',
    'GetExhaustiveTimeline',
    'FlushExhaustiveLogs'
}
