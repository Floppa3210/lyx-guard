--[[







    LyxGuard v4.0 - MODULAR CONFIGURATION








    TIPOS DE CASTIGO:
    - 'none'        : Solo loggear
    - 'notify'      : Notificar admins
    - 'screenshot'  : Captura + notificar
    - 'warn'        : Advertir (maximo = ban)
    - 'kick'        : Expulsar
    - 'ban_temp'    : Ban temporal
    - 'ban_perm'    : Ban permanente
    - 'teleport'    : Teleportar a spawn
    - 'freeze'      : Congelar temporal
    - 'kill'        : Matar
]]

Config = {}
-- -----------------------------------------------------------------------------
-- GENERAL
-- -----------------------------------------------------------------------------

Config.Debug = false -- v4.1 HOTFIX: Desactivado - causaba spam masivo en consola
Config.Locale = 'es'
Config.ResourceName = 'lyx-guard'

-- Runtime profile selector:
-- - 'default'
-- - 'rp_light'             (RP liviano, minimiza falsos positivos)
-- - 'production_high_load' (alta carga)
-- - 'hostile'              (entorno hostil / ataques frecuentes)
Config.RuntimeProfile = 'default'

-- Optional profile overrides (applied at end of this file).
Config.ProfilePresets = {
    rp_light = {
        TriggerProtection = {
            massiveTriggersPerMinute = 200000,
            spamScale = 6.5,
            spamFlagCooldownMs = 14000,
            massiveFlagCooldownMs = 25000,
            minSessionSecondsForSpamFlag = 75,
            guardPanelEventProtection = {
                actionSecurity = {
                    tokenTtlMs = 8 * 60 * 1000,
                    nonceTtlMs = 8 * 60 * 1000,
                    maxUsedNonces = 4096,
                    maxClockSkewMs = 240000,
                }
            }
        },

        EventFirewall = {
            enabled = true,
            strictLyxGuardAllowlist = true,
            maxArgs = 36,
            maxDepth = 9,
            maxKeysPerTable = 320,
            maxTotalKeys = 3600,
            maxStringLen = 8192,
            maxTotalStringLen = 36000
        },

        Quarantine = {
            minNotifyIntervalMs = 6000,
            defaultReasonCooldownMs = 20000,
            reasonCooldownMs = {
                heartbeat_missing = 210000,
                modules_low = 210000,
                modules_missing = 210000,
                event_spam = 45000,
                event_spam_massive = 60000,
                lyxpanel_admin_event_rate_limit = 30000,
                lyxpanel_admin_event_payload = 45000,
                lyxpanel_admin_event_schema = 45000,
                lyxpanel_admin_event_no_session = 60000,
                lyxpanel_admin_event_not_allowlisted = 45000,
                lyxpanel_admin_event_spoof = 120000,
                lyxguard_event_schema = 60000,
                lyxguard_panel_event_schema = 120000,
                lyxguard_panel_event_token = 120000,
                lyxguard_panel_event_replay = 180000,
                lyxguard_panel_event_spoof = 120000,
                txadmin_event_spoof = 180000,
                restricted_event_spoof = 90000,
                restricted_event_spoof_high = 180000
            }
        },

        Advanced = {
            heartbeat = {
                tolerance = 5,
                intervalMs = 13000,
                timeoutMs = 50000,
                graceSeconds = 75,
                integrityFlagCooldownMs = 120000
            }
        },

        BanHardening = {
            enableTokenHashes = true,
            enableIdentifierFingerprint = true,
            tokenHashScanLimit = 4500,
            legacyTokenLikeFallback = true
        }
    },

    production_high_load = {
        TriggerProtection = {
            massiveTriggersPerMinute = 140000,
            spamScale = 5.0,
            spamFlagCooldownMs = 10000,
            massiveFlagCooldownMs = 20000,
            minSessionSecondsForSpamFlag = 60,
            guardPanelEventProtection = {
                actionSecurity = {
                    tokenTtlMs = 6 * 60 * 1000,
                    nonceTtlMs = 6 * 60 * 1000,
                    maxUsedNonces = 3072,
                    maxClockSkewMs = 180000,
                }
            }
        },

        EventFirewall = {
            enabled = true,
            strictLyxGuardAllowlist = true,
            maxArgs = 28,
            maxDepth = 8,
            maxKeysPerTable = 260,
            maxTotalKeys = 2600,
            maxStringLen = 6144,
            maxTotalStringLen = 28000
        },

        Quarantine = {
            minNotifyIntervalMs = 5000,
            defaultReasonCooldownMs = 15000,
            reasonCooldownMs = {
                heartbeat_missing = 180000,
                modules_low = 180000,
                modules_missing = 180000,
                event_spam = 30000,
                event_spam_massive = 45000,
                lyxpanel_admin_event_rate_limit = 20000,
                lyxpanel_admin_event_payload = 35000,
                lyxpanel_admin_event_schema = 35000,
                lyxpanel_admin_event_no_session = 60000,
                lyxpanel_admin_event_not_allowlisted = 30000,
                lyxpanel_admin_event_spoof = 90000,
                lyxguard_event_schema = 45000,
                lyxguard_panel_event_schema = 90000,
                lyxguard_panel_event_token = 90000,
                lyxguard_panel_event_replay = 120000,
                lyxguard_panel_event_spoof = 90000,
                txadmin_event_spoof = 120000,
                restricted_event_spoof = 70000,
                restricted_event_spoof_high = 120000
            }
        },

        Advanced = {
            heartbeat = {
                tolerance = 4,
                intervalMs = 12000,
                timeoutMs = 45000,
                graceSeconds = 60,
                integrityFlagCooldownMs = 90000
            }
        },

        BanHardening = {
            enableTokenHashes = true,
            enableIdentifierFingerprint = true,
            tokenHashScanLimit = 3500,
            legacyTokenLikeFallback = true
        }
    },

    hostile = {
        TriggerProtection = {
            massiveTriggersPerMinute = 70000,
            spamScale = 3.0,
            spamFlagCooldownMs = 5000,
            massiveFlagCooldownMs = 10000,
            minSessionSecondsForSpamFlag = 20,
            guardPanelEventProtection = {
                actionSecurity = {
                    tokenTtlMs = 2 * 60 * 1000,
                    nonceTtlMs = 3 * 60 * 1000,
                    maxUsedNonces = 1536,
                    maxClockSkewMs = 120000,
                }
            }
        },

        EventFirewall = {
            enabled = true,
            strictLyxGuardAllowlist = true,
            maxArgs = 16,
            maxDepth = 6,
            maxKeysPerTable = 140,
            maxTotalKeys = 1200,
            maxStringLen = 3072,
            maxTotalStringLen = 12000
        },

        Quarantine = {
            minNotifyIntervalMs = 3000,
            defaultReasonCooldownMs = 8000,
            reasonCooldownMs = {
                heartbeat_missing = 90000,
                modules_low = 90000,
                modules_missing = 90000,
                event_spam = 10000,
                event_spam_massive = 15000,
                lyxpanel_admin_event_rate_limit = 10000,
                lyxpanel_admin_event_payload = 12000,
                lyxpanel_admin_event_schema = 12000,
                lyxpanel_admin_event_no_session = 20000,
                lyxpanel_admin_event_not_allowlisted = 10000,
                lyxpanel_admin_event_spoof = 30000,
                lyxguard_event_schema = 15000,
                lyxguard_panel_event_schema = 30000,
                lyxguard_panel_event_token = 30000,
                lyxguard_panel_event_replay = 45000,
                lyxguard_panel_event_spoof = 30000,
                txadmin_event_spoof = 45000,
                restricted_event_spoof = 20000,
                restricted_event_spoof_high = 45000
            },
            strikeWeights = {
                lyxpanel_admin_event_spoof = 2,
                lyxguard_panel_event_spoof = 2,
                lyxguard_event_schema = 2,
                lyxguard_panel_event_schema = 2,
                lyxguard_panel_event_token = 2,
                lyxguard_panel_event_replay = 3,
                txadmin_event_spoof = 3,
                restricted_event_spoof = 2,
                restricted_event_spoof_high = 3,
                lyxpanel_admin_event_not_allowlisted = 2,
                lyxpanel_admin_event_schema = 2,
                blacklisted_event = 2
            }
        },

        Advanced = {
            heartbeat = {
                tolerance = 3,
                intervalMs = 9000,
                timeoutMs = 30000,
                graceSeconds = 30,
                integrityFlagCooldownMs = 45000
            }
        },

        BanHardening = {
            enableTokenHashes = true,
            enableIdentifierFingerprint = true,
            tokenHashScanLimit = 6000,
            legacyTokenLikeFallback = true
        }
    }
}
-- -----------------------------------------------------------------------------
-- RISK SCORE (Server-side accumulator)
-- Suma senales "debiles" y aplica sancion cuando cruza umbrales.
-- Util para evitar bans por 1 sola deteccion dudosa.
-- -----------------------------------------------------------------------------

Config.Risk = {
    enabled = true,
    -- By default, do not auto-kick/ban purely from risk score; Quarantine handles escalation.
    enforcePunishments = false,

    -- Decay: cada decayMs resta decayPoints (minimo 0)
    decayMs = 5 * 60 * 1000, -- 5 min
    decayPoints = 15,

    -- Umbrales (puntos acumulados)
    thresholds = {
        kick = 80,
        tempBan = 140,
        permBan = 220,
        tempBanDuration = 'long',
    },

    -- Cooldown entre sanciones por risk score (ms)
    actionCooldownMs = 60 * 1000,

    -- Puntos por senal (MarkPlayerSuspicious reason)
    points = {
        -- NOTE: Many of these are handled by Quarantine escalation (warn->warn->ban),
        -- so keep the risk points low to avoid false kicks/bans on busy servers.
        heartbeat_missing = 10,
        teleport_server = 10,
        entity_firewall = 10,
        event_spam = 5,
        event_spam_massive = 10,
        event_payload_anomaly = 10,
        lyxguard_event_not_allowlisted = 15,
        blacklisted_event = 15,
        money_exploit = 25,
        transaction_spam = 15,
        economy_anomaly = 30,
        inventory_anomaly = 25,
        state_anomaly = 20,
        damage_mod = 15,
        dps_exploit = 20,
        lyxpanel_admin_event_rate_limit = 25,
        lyxpanel_admin_event_payload = 40,
        lyxpanel_admin_event_schema = 50,
        lyxpanel_admin_event_no_session = 25,
        lyxpanel_admin_event_not_allowlisted = 80,
        lyxpanel_admin_event_spoof = 200,
        lyxguard_event_schema = 80,
        lyxguard_panel_event_schema = 200,
        lyxguard_panel_event_token = 220,
        lyxguard_panel_event_replay = 260,
        lyxguard_panel_event_spoof = 220,
        txadmin_event_spoof = 260,
        restricted_event_spoof = 120,
        restricted_event_spoof_high = 240,
        honeypot_command = 260,
        burst_pattern = 45,
    },

    defaultPoints = 10
}
-- -----------------------------------------------------------------------------
-- BURST PATTERN DETECTION
-- Detecta rafagas de senales sospechosas en ventanas cortas.
-- No reemplaza el rate-limit: agrega correlacion multi-senal.
-- -----------------------------------------------------------------------------

Config.BurstPattern = {
    enabled = true,
    windowMs = 45000, -- 45s
    signalThreshold = 10, -- total de senales sospechosas en la ventana
    uniqueReasonThreshold = 3, -- cantidad minima de razones distintas
    escalationCooldownMs = 45000, -- evitar re-escalar continuamente
    addRiskPoints = 35, -- incremento extra de riesgo cuando detecta patron
}

-- -----------------------------------------------------------------------------
-- SERVER ANOMALY DETECTION (economy / inventory / player state)
-- Adds weak signals for risk-score accumulation without immediate hard punish.
-- -----------------------------------------------------------------------------

Config.ServerAnomaly = {
    enabled = true,
    intervalMs = 12000,
    flagCooldownMs = 30000,

    economy = {
        enabled = true,
        maxAbsMoney = 100000000,
        maxAbsBank = 250000000,
        maxAbsBlack = 100000000,
        maxDeltaMoney = 2500000,
        maxDeltaBank = 5000000,
        maxDeltaBlack = 3000000,
    },

    inventory = {
        enabled = true,
        maxTotalItems = 5000,
        maxDistinctItems = 300,
        maxSingleItemCount = 500,
    },

    state = {
        enabled = true,
        maxHealth = 300,
        maxArmor = 200,
        maxSpeed = 550.0,
    }
}
-- -----------------------------------------------------------------------------
-- QUARANTINE (Warn -> Warn -> 90-day Ban)
-- Cuando se detecta actividad sospechosa, se le muestra una alerta al jugador por 5 minutos.
-- 2 advertencias; si vuelve a ocurrir (3er strike) => ban temporal 90 dias.
-- -----------------------------------------------------------------------------

Config.Quarantine = {
    enabled = true,

    -- Alert on client for this long (ms)
    alertDurationMs = 5 * 60 * 1000, -- 5 min

    -- Strike accumulation window (ms). After this idle time, strikes reset.
    strikeWindowMs = 30 * 60 * 1000, -- 30 min

    -- Escalation: 1/2 = warning, 3rd = ban
    strikesToBan = 3,

    -- Ban duration in SECONDS (BanPlayer/LyxGuardLib.GetUnbanTime uses seconds)
    banSeconds = 90 * 24 * 3600, -- 90 dias

    -- Avoid spamming the client with repeated notifications
    minNotifyIntervalMs = 3000,

    -- Optional global cooldown between strikes for the same reason.
    -- 0 = disabled.
    defaultReasonCooldownMs = 0,

    -- Reasons that should contribute to quarantine strikes (MarkPlayerSuspicious reason).
    -- Keep this list tight to avoid false bans.
    reasons = {
        -- Trigger protection / event firewall
        -- Regular event spam can happen on busy servers; keep telemetry, avoid quarantine strike by default.
        event_spam = false,
        event_spam_massive = true,
        event_payload_anomaly = true,
        lyxguard_event_not_allowlisted = true,
        lyxpanel_admin_event_rate_limit = true,
        lyxpanel_admin_event_payload = true,
        lyxpanel_admin_event_schema = true,
        lyxpanel_admin_event_no_session = true,
        lyxpanel_admin_event_not_allowlisted = true,
        lyxpanel_admin_event_spoof = true,
        lyxguard_event_schema = true,
        lyxguard_panel_event_schema = true,
        lyxguard_panel_event_token = true,
        lyxguard_panel_event_replay = true,
        lyxguard_panel_event_spoof = true,
        txadmin_event_spoof = true,
        restricted_event_spoof = true,
        restricted_event_spoof_high = true,
        honeypot_command = true,
        burst_pattern = true,
        blacklisted_event = true,

        -- Server-side anomaly correlation (risk score handles escalation).
        economy_anomaly = false,
        inventory_anomaly = false,
        state_anomaly = false,

        -- Integrity / missing heartbeat
        heartbeat_missing = true,
        modules_low = true,
        modules_missing = true,

        -- Entity firewall server-side
        entity_firewall = true,
    },

    -- Optional per-reason weights (>=1). Example:
    -- strikeWeights = { blacklisted_event = 2 }
    strikeWeights = {},

    -- Per-reason strike cooldowns (ms): repeat signals inside cooldown refresh alert but do not add strike.
    reasonCooldownMs = {
        heartbeat_missing = 120000,
        modules_low = 120000,
        modules_missing = 120000,
        event_spam = 15000,
        event_spam_massive = 30000,
        lyxpanel_admin_event_rate_limit = 15000,
        lyxpanel_admin_event_payload = 30000,
        lyxpanel_admin_event_schema = 30000,
        lyxpanel_admin_event_no_session = 60000,
        lyxpanel_admin_event_not_allowlisted = 30000,
        lyxpanel_admin_event_spoof = 60000,
        lyxguard_event_schema = 45000,
        lyxguard_panel_event_schema = 60000,
        lyxguard_panel_event_token = 60000,
        lyxguard_panel_event_replay = 120000,
        lyxguard_panel_event_spoof = 60000,
        txadmin_event_spoof = 120000,
        restricted_event_spoof = 60000,
        restricted_event_spoof_high = 120000,
        honeypot_command = 120000,
        burst_pattern = 45000
    }
}
-- -----------------------------------------------------------------------------
-- TRIGGER PROTECTION (Event Spam) - High limits by default
-- -----------------------------------------------------------------------------

Config.TriggerProtection = {
    enabled = true,

    -- Per-player total triggers per 60s before flagging "massive".
    -- Keep high: legit servers can generate a lot of traffic.
    massiveTriggersPerMinute = 140000,

    -- Scale per-event spam thresholds globally (applied to SpamCheckedEvents maxAllowed).
    spamScale = 5.0,

    -- Baseline adaptativo por carga real del servidor.
    -- Ajusta el spamScale segun jugadores conectados y franja horaria.
    adaptiveBaseline = {
        enabled = true,
        useUtc = false,
        basePlayers = 32,
        playerStep = 16,
        maxPlayerBonus = 2.0,
        peakStartHour = 18,
        peakEndHour = 23,
        peakMultiplier = 1.15,
        offPeakMultiplier = 1.0,
        maxScale = 12.0
    },

    -- Avoid repeated suspicious flags every tick once a threshold is exceeded.
    spamFlagCooldownMs = 7000,
    massiveFlagCooldownMs = 15000,

    -- Ignore mild spam flags shortly after connect (unless it's clearly severe).
    minSessionSecondsForSpamFlag = 45,

    -- txAdmin spoof protection:
    -- If a non-privileged player tries to trigger txAdmin-style events, block and permaban.
    txAdminEventProtection = {
        enabled = true,
        eventPrefix = 'txsv:',
        allowedAce = {
            'txadmin.all',
            'command',
            'lyxguard.admin',
            'lyxpanel.admin'
        },
        punish = {
            enabled = true,
            permanent = true,
            durationSeconds = 0,
            reason = 'Cheating detected (txAdmin event spoof)',
            by = 'LyxGuard TriggerProtection'
        }
    },

    -- LyxPanel admin-event spoof protection (2nd independent layer).
    -- Even if lyx-panel firewall is misconfigured/disabled, this blocks non-admin triggers.
    panelAdminEventProtection = {
        enabled = true,
        eventPrefix = 'lyxpanel:action:',
        allowedAce = {
            'lyxpanel.admin',
            'lyxpanel.access',
            'lyxguard.admin',
            'command',
            'txadmin.all'
        },
        -- Also protect non-action critical panel events (staff/reports control path).
        protectedEvents = {
            ['lyxpanel:setStaffStatus'] = true,
            ['lyxpanel:requestStaffSync'] = true,
            ['lyxpanel:reports:claim'] = true,
            ['lyxpanel:reports:resolve'] = true,
            ['lyxpanel:reports:get'] = true
        },
        punish = {
            enabled = true,
            permanent = true,
            durationSeconds = 0,
            reason = 'Cheating detected (LyxPanel admin event spoof)',
            by = 'LyxGuard TriggerProtection',
            cooldownMs = 15000
        }
    },

    -- LyxGuard panel event spoof protection.
    -- Blocks non-admin clients trying to call lyxguard:panel:* actions directly.
    guardPanelEventProtection = {
        enabled = true,
        eventPrefix = 'lyxguard:panel:',

        -- Extra strict schema validation for lyxguard:panel:* payloads.
        -- Helps block direct TriggerServerEvent spoof with malformed args.
        schemaValidation = true,

        -- Events that can be safely ignored without punishment.
        -- open/close may be called from UI flow or accidental keybind attempts.
        excludedEvents = {
            ['lyxguard:panel:open'] = true,
            ['lyxguard:panel:close'] = true
        },

        -- Optional custom schema overrides (merged in trigger_protection.lua).
        -- Set an entry to `false` to disable default schema for that event.
        schemas = {
            -- ['lyxguard:panel:myCustomEvent'] = { minArgs = 1, maxArgs = 1, types = { [1] = 'string' } }
        },

        allowedAce = {
            'lyxguard.panel',
            'lyxguard.admin',
            'command',
            'txadmin.all'
        },

        -- Session token + nonce anti-replay for lyxguard:panel:* actions.
        actionSecurity = {
            enabled = true,
            requireForPanelEvents = true,
            tokenTtlMs = 5 * 60 * 1000,
            nonceTtlMs = 5 * 60 * 1000,
            maxUsedNonces = 2048,
            maxClockSkewMs = 180000,
            contextTtlMs = 15000,
            tokenMinLen = 24,
            tokenMaxLen = 128,
            nonceMinLen = 16,
            nonceMaxLen = 128,
            correlationMinLen = 10,
            correlationMaxLen = 128,
        },

        punish = {
            enabled = true,
            permanent = true,
            durationSeconds = 0,
            cooldownMs = 15000,
            reason = 'Cheating detected (LyxGuard panel event spoof)',
            by = 'LyxGuard TriggerProtection'
        }
    },

    -- Extra blacklisted events (client->server) merged into trigger_protection.lua.
    -- Add only events that should NEVER be callable directly by normal players.
    blacklistedEvents = {
        -- Economy abuse
        'esx:addMoney',
        'esx:removeMoney',
        'esx:setMoney',
        'esx:addAccountMoney',
        'esx:setJob',
        'esx:setJobGrade',

        -- Legacy ambulance/jail abuse
        'esx_ambulancejob:revive',
        'esx_jail:sendToJail',
        'esx_jailer:sendToJail',

        -- Billing/vehicle ownership abuse
        'esx_billing:sendBill',
        'esx_vehicleshop:setVehicleOwned',

        -- Known cheat loaders/menus
        'mellotrainer:adminTempBan',
        'mellotrainer:adminKick',
        'hentailover:xdlol',
        'gcPhone:_internalAddMessage'
    },

    -- Sensitive events with explicit allow-rules.
    -- Unlike blacklistedEvents, these can define allowed jobs/groups/ACE and
    -- optional punishment policy per event.
    restrictedEvents = {
        -- Revive endpoints (allow medics + panel/guard staff).
        ['esx_ambulancejob:revive'] = {
            allowJobs = { 'ambulance', 'ems', 'paramedic' },
            allowGroups = { 'superadmin', 'admin', 'mod', 'helper', 'master', 'owner' },
            allowPermissionLevels = { 'full', 'vip' },
            punish = false,
            detection = 'restricted_event_spoof',
            reason = 'Revive no autorizado bloqueado'
        },
        ['paramedic:revive'] = {
            allowJobs = { 'ambulance', 'ems', 'paramedic' },
            allowGroups = { 'superadmin', 'admin', 'mod', 'helper', 'master', 'owner' },
            allowPermissionLevels = { 'full', 'vip' },
            punish = false,
            detection = 'restricted_event_spoof',
            reason = 'Revive no autorizado bloqueado'
        },
        ['ems:revive'] = {
            allowJobs = { 'ambulance', 'ems', 'paramedic' },
            allowGroups = { 'superadmin', 'admin', 'mod', 'helper', 'master', 'owner' },
            allowPermissionLevels = { 'full', 'vip' },
            punish = false,
            detection = 'restricted_event_spoof',
            reason = 'Revive no autorizado bloqueado'
        },

        -- High confidence cheat signatures.
        ['adminmenu:allowall'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Admin event malicioso detectado'
        },
        ['adminmenu:setsalary'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Admin event malicioso detectado'
        },
        ['adminmenu:giveDirtyMoney'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Admin event malicioso detectado'
        },
        ['adminmenu:giveBank'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Admin event malicioso detectado'
        },
        ['adminmenu:giveCash'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Admin event malicioso detectado'
        },
        ['mellotrainer:adminKick'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Trainer event malicioso detectado'
        },
        ['mellotrainer:adminTempBan'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Trainer event malicioso detectado'
        },
        ['banfuncReturnTruzz:banac'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Intento de ban remoto malicioso detectado'
        },
        ['hcheat:tempDisableDetection'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Intento de desactivar detecciones detectado'
        },
        ['AntiLynx8:anticheat'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Firma AntiLynx detectada'
        },
        ['AntiLynx8R4A:anticheat'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Firma AntiLynx detectada'
        },
        ['AntiLynxR6:detection'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Firma AntiLynx detectada'
        },
        ['AntiLynxR4:detect'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Firma AntiLynx detectada'
        },
        ['AntiLynxR4:kick'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Firma AntiLynx detectada'
        },
        ['ynx8:anticheat'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Firma YNX/Lynx detectada'
        },
        ['lynx8:anticheat'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Firma YNX/Lynx detectada'
        },
        ['js:jailuser'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Evento de menu malicioso (jailuser) detectado'
        },
        ['js:jadfwmiluser'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Evento ofuscado (dfwm) detectado'
        },
        ['xk3ly-barbasz:getfukingmony'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Money exploit conocido detectado'
        },
        ['xk3ly-farmer:paycheck'] = {
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Money exploit conocido detectado'
        },

        -- Privileged ESX mutations.
        ['esx:setJob'] = {
            allowPermissionLevels = { 'full' },
            punish = false,
            detection = 'restricted_event_spoof',
            reason = 'Mutacion de job no autorizada'
        },
        ['esx_society:setJob'] = {
            allowPermissionLevels = { 'full' },
            punish = false,
            detection = 'restricted_event_spoof',
            reason = 'Mutacion de job no autorizada'
        },
        ['esx_society:setJobSalary'] = {
            allowPermissionLevels = { 'full' },
            punish = false,
            detection = 'restricted_event_spoof',
            reason = 'Cambio de salario no autorizado'
        },
        ['NB:recruterplayer'] = {
            allowPermissionLevels = { 'full' },
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Reclutamiento no autorizado detectado'
        },
        ['NB:destituerplayer'] = {
            allowPermissionLevels = { 'full' },
            punish = true,
            detection = 'restricted_event_spoof_high',
            reason = 'Destitucion no autorizada detectada'
        }
    }
}

-- ---------------------------------------------------------------------------
-- Server Event Firewall (used by server/trigger_protection.lua)
-- ---------------------------------------------------------------------------
Config.EventFirewall = {
    enabled = true,
    strictLyxGuardAllowlist = true,

    -- Keep limits conservative enough for legit traffic but block obvious payload abuse.
    maxArgs = 24,
    maxDepth = 8,
    maxKeysPerTable = 200,
    maxTotalKeys = 2000,
    maxStringLen = 4096,
    maxTotalStringLen = 20000
}
-- -----------------------------------------------------------------------------
-- PANEL DE ADMINISTRACION
-- -----------------------------------------------------------------------------

Config.Panel = {
    enabled = true,
    key = 'F8',               -- Tecla para abrir el panel
    soundEnabled = true,      -- Sonido en detecciones
    autoRefreshInterval = 30, -- Segundos entre actualizaciones
    acePermissions = {
        'lyxguard.panel',
        'lyxguard.admin',
        'lyxguard.role.mod',
        'lyxguard.role.helper',
    },
    allowedGroups = {         -- Grupos ESX con acceso
        'superadmin',
        'admin',
        'mod',
        'helper',
        'master',
        'owner'
    }
}
-- -----------------------------------------------------------------------------
-- SISTEMA DE CASTIGOS
-- -----------------------------------------------------------------------------

Config.Punishments = {
    enabled = true,

    -- Duration presets used by LyxGuardLib.GetUnbanTime (SECONDS)
    -- Keys are lowercase because most configs use 'short'/'medium'/'long'.
    banDurations = {
        short = 3600,         -- 1 hora
        medium = 86400,       -- 1 dia
        long = 604800,        -- 1 semana
        verylong = 2592000,   -- 30 dias
        permanent = 0         -- 0 = permanente
    },

    -- Legacy presets (HOURS). Prefer `banDurations` above.
    tempBanDurations = {
        short = 1,     -- 1 hora
        medium = 24,   -- 1 dia
        long = 168,    -- 1 semana
        verylong = 720 -- 1 mes
    },

    warnings = {
        enabled = false, -- privacy + quota: enable only if you really want this and you have an API key
        maxWarnings = 3,
        expiryHours = 24,
        actionOnMax = 'ban_temp',
        banDurationOnMax = 'medium'
    },

    freezeDuration = 30,

    spawnPoint = { x = -269.4, y = -955.3, z = 31.2 },

    messages = {
        warn = 'ADVERTENCIA: %s | %d/%d',
        kick = 'Expulsado: %s',
        ban = 'Baneado: %s | Duracion: %s\nApela: discord.gg/XXXXX',
        freeze = 'Congelado %ds: %s',
        teleport = 'Teleportado: %s'
    }
}

-- ----------------------------------------------------------------------------
-- BAN HARDENING (anti spoof / anti ban evasion)
-- ----------------------------------------------------------------------------
Config.BanHardening = {
    -- Save deterministic token hashes for exact matching (instead of weak LIKE only).
    enableTokenHashes = true,

    -- Save stable identifier fingerprint (license/steam/discord/fivem + token hashes).
    enableIdentifierFingerprint = true,

    -- Fallback scan size for DB engines without JSON_OVERLAPS.
    tokenHashScanLimit = 3000,

    -- Token match must be supported by at least N identifier matches (license/steam/discord/fivem).
    -- Helps avoid false positives while still catching ban evasion.
    minIdentifierMatchesOnTokenMatch = 1,

    -- Minimum token hash overlap for hash-based ban hits.
    minTokenHashMatches = 1,

    -- Keep compatibility with legacy bans that only stored raw `tokens`.
    legacyTokenLikeFallback = true
}
-- -----------------------------------------------------------------------------
-- SEGURIDAD DE CONEXION (Anti-VPN, VAC, Name Filter)
-- -----------------------------------------------------------------------------

Config.Connection = {
    AntiVPN = {
        -- Privacy + availability: external IP/VPN APIs can fail or leak player IPs.
        -- Keep disabled by default; enable only if you accept the tradeoffs and have an API key.
        enabled = false,
        apiUrl = 'https://vpnapi.io/api/',
        apiKey = '', -- Obtener en vpnapi.io (100 queries/dia gratis)
        rejectMessage = 'Conectar via VPN no esta permitido. Desactiva tu VPN para conectar.'
    },

    VACBanCheck = {
        enabled = false, -- Requiere steam_webApiKey en server.cfg
        rejectMessage = 'Estas baneado en Steam VAC y no puedes conectar a este servidor.'
    },

    NameFilter = {
        enabled = true,
        blockNonAlphanumeric = false,
        minLength = 3,
        maxLength = 32,
        blacklistedWords = {
            'admin', 'moderator', 'owner', 'staff', 'console',
            'nigger', 'nigga', 'faggot', 'nazi', 'hitler'
        },
        rejectMessage = 'Tu nombre contiene caracteres o palabras no permitidas.'
    },

    MinIdentifiers = 2,
    HideIP = true
}
-- -----------------------------------------------------------------------------
-- PERMISOS / INMUNIDAD  (v4.4 ULTRA PROFESIONAL)
-- Sistema avanzado de whitelist con configuracion individual por persona
-- -----------------------------------------------------------------------------

Config.Permissions = {
    enabled = true,
-- -----------------------------------------------------------------------------
    -- NIVEL 1: INMUNIDAD TOTAL (El anticheat NO detecta NADA)
    -- Para owners/desarrolladores del servidor
-- -----------------------------------------------------------------------------

    -- Grupos ESX con inmunidad total
    immuneGroups = {
        -- 'superadmin',  -- Descomenta si quieres que superadmin sea 100% inmune
        -- 'admin',       -- Descomenta si quieres que admin sea 100% inmune
        -- 'owner',
    },

    -- Identifiers con inmunidad total (license:xxx, steam:xxx, discord:xxx)
    immuneIdentifiers = {
        -- 'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        -- 'steam:xxxxxxxxxxxxxxx',
        -- 'discord:xxxxxxxxxxxxxxxxxx',
    },

    -- Permisos ACE que dan inmunidad total
    acePermissions = {
        'lyxguard.immune', -- Inmunidad total
        'lyxguard.admin',  -- Panel admin + inmunidad
        'lyxguard.bypass'  -- Bypass de todas las detecciones
    },

    vipAcePermissions = {
        'lyxguard.vip',
        'lyxguard.role.mod',
        'lyxguard.role.helper',
    },

    -- Si true, txAdmin admins son inmunes (NO recomendado para testing)
    txAdminImmune = false,
-- -----------------------------------------------------------------------------
    -- NIVEL 2: WHITELIST VIP (Detecciones reducidas/personalizadas)
    -- Para admins/mods que necesitan usar herramientas pero no inmunidad total
    -- El anticheat SI los monitorea pero con reglas especiales
-- -----------------------------------------------------------------------------

    vipWhitelist = {
        enabled = true,

        -- Grupos ESX que son VIP (detecciones reducidas)
        vipGroups = { 'admin', 'mod', 'helper' },

        -- Detecciones que se IGNORAN para VIPs (el resto sigue activo)
        ignoredDetections = {
            'teleport',      -- Los admins usan teleport legitimamente
            'noclip',        -- Para tareas de admin
            'speedhack',     -- A veces usan velocidad para moverse rapido
            'vehicle_spawn', -- Spawnean vehiculos para testing
            'godmode',       -- A veces se ponen godmode para moderar
            'flyhack',       -- Vuelan para supervisar
        },

        -- Detecciones que SIEMPRE se aplican a VIPs (seguridad critica)
        alwaysDetect = {
            'injection', -- Inyeccion de codigo = siempre banear
            'explosion', -- Spam de explosiones = siempre detectar
            -- Cualquier deteccion NO listada aqui ni en ignoredDetections = sigue normal
        },

        -- Multiplicador de tolerancia para VIPs (2 = doble de tolerancia)
        toleranceMultiplier = 2.0,
    },
-- -----------------------------------------------------------------------------
    -- NIVEL 3: CONFIGURACION INDIVIDUAL POR PERSONA
    -- Para dar permisos especificos a jugadores especificos
    -- Esto OVERRIDE todo lo anterior
-- -----------------------------------------------------------------------------

    individualWhitelist = {
        enabled = true,

        -- Lista de jugadores con configuracion personalizada
        -- Cada entrada es: identifier = { configuracion }
        players = {
-- -----------------------------------------------------------------------------
            -- EJEMPLO 1: Admin que puede hacer de todo excepto explosiones
-- -----------------------------------------------------------------------------
            -- ['license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'] = {
            --     name = 'NombreDelAdmin',      -- Solo para referencia
            --     immuneLevel = 'vip',          -- 'full' = inmune total, 'vip' = reducido, 'none' = normal
            --     ignoredDetections = {         -- Detecciones a ignorar para esta persona
            --         'teleport', 'noclip', 'godmode', 'flyhack', 'speedhack'
            --     },
            --     forcedDetections = {          -- Detecciones que SIEMPRE aplican
            --         'explosion', 'injection'
            --     },
            --     toleranceMultiplier = 3.0,    -- 3x mas tolerancia
            --     notes = 'Admin de construccion, necesita noclip/fly'
            -- },
-- -----------------------------------------------------------------------------
            -- EJEMPLO 2: Streamer VIP que no debe ser baneado accidentalmente
-- -----------------------------------------------------------------------------
            -- ['discord:123456789012345678'] = {
            --     name = 'StreamerFamoso',
            --     immuneLevel = 'vip',
            --     ignoredDetections = { 'flyhack', 'teleport' }, -- A veces lag causa falsos positivos
            --     toleranceMultiplier = 2.0,
            --     notes = 'Streamer con 10k viewers, evitar falsos positivos'
            -- },
-- -----------------------------------------------------------------------------
            -- EJEMPLO 3: Owner con inmunidad total
-- -----------------------------------------------------------------------------
            -- ['steam:xxxxxxxxxxxxxxx'] = {
            --     name = 'ElOwner',
            --     immuneLevel = 'full',  -- Inmunidad total
            --     notes = 'Dueno del servidor'
            -- },
        }
    },
-- -----------------------------------------------------------------------------
    -- CONFIGURACION DE LOGGING PARA WHITELISTED
    -- Aunque no se castigue, registrar las detecciones?
-- -----------------------------------------------------------------------------

    logging = {
        logImmuneDetections = true,   -- Loggear cuando inmunes triggerean detecciones
        logVipDetections = true,      -- Loggear detecciones de VIPs (aunque ignoradas)
        sendWebhookForImmune = false, -- Enviar a Discord detecciones de inmunes
        sendWebhookForVip = true,     -- Enviar a Discord detecciones de VIPs
    }
}

-- -----------------------------------------------------------------------------
-- EXHAUSTIVE FILE LOGGING (panel + anticheat)
-- -----------------------------------------------------------------------------
Config.ExhaustiveLogs = {
    enabled = true,
    directory = 'logs', -- relative to lyx-guard resource folder
    writeJsonl = true,
    writeText = true,
    flushIntervalMs = 2000,
    flushBatchSize = 30,
    maxFileBytes = 2 * 1024 * 1024,

    -- Timeline used for sanctions context (e.g. 60 seconds before ban).
    timelineSeconds = 60,
    timelineRetentionSeconds = 15 * 60,
    timelineMaxEntries = 1200,

    -- Throttle for high-volume "observed" events.
    throttleDefaultMs = 1500,

    -- Optional compression for rotated files.
    compressRotated = false,       -- if true, creates .zip for rotated logs
    compressionDeleteOriginal = false, -- if true, removes original after successful zip
    compressionMinBytes = 64 * 1024
}
-- -----------------------------------------------------------------------------
-- DISCORD WEBHOOKS
-- -----------------------------------------------------------------------------

Config.Discord = {
    enabled = true,
    webhooks = {
        detections =
        '', -- URL webhook
        bans =
        '',
        kicks =
        '',
        warnings =
        '',
        logs =
        '',
        screenshots =
        '',
        alerts =
        ''
    },
    serverName = 'LudopatiaRP',
    serverLogo = '',
    serverFooter = 'LyxGuard v4.0',

    -- Mencionar roles en bans/alertas criticas
    mentionRoles = {
        enabled = false,
        roleIds = {
            -- '<@&123456789012345678>'  -- Formato de Discord
        }
    }
}
-- -----------------------------------------------------------------------------
-- CAPTURAS DE PANTALLA
-- -----------------------------------------------------------------------------

Config.Screenshot = {
    enabled = true,
    resource = 'screenshot-basic', -- Recurso para screenshots
    quality = 0.85,
    uploadToWebhook = true
}
-- -----------------------------------------------------------------------------
-- DETECCIONES DE MOVIMIENTO
-- Cada deteccion sigue la misma estructura para facil modificacion
-- -----------------------------------------------------------------------------

Config.Movement = {
    -- PLANTILLA para anadir mas:
    -- nombreDeteccion = {
    --     enabled = true/false,
    --     punishment = 'tipo',
    --     banDuration = 'duracion',
    --     tolerance = numero,
    --     ... parametros adicionales
    -- },

    teleport = {
        enabled = true,
        punishment = 'notify',
        banDuration = 'medium',
        tolerance = 1,
        maxDistance = 150.0
    },

    noclip = {
        enabled = true,
        punishment = 'warn',
        banDuration = 'long',
        tolerance = 3,
        minHeight = 5.0
    },

    speedHack = {
        enabled = true,
        punishment = 'kick',
        banDuration = 'medium',
        tolerance = 5,
        maxSpeeds = {
            onFoot = 12.0,
            running = 18.0,
            swimming = 8.0,
            vehicle = 300.0
        }
    },

    superJump = {
        enabled = true,
        punishment = 'teleport',
        banDuration = 'short',
        tolerance = 3,
        maxJumpVelocity = 8.0
    },

    flyHack = {
        enabled = true,
        punishment = 'warn',
        banDuration = 'long',
        tolerance = 5,     -- v4.1 HOTFIX: Aumentado de 1 a 5 (prevenir falsos positivos durante loading)
        maxAirTime = 20000 -- v4.1 HOTFIX: Aumentado de 10000 a 20000ms
    },

    underground = {
        enabled = true,
        punishment = 'teleport',
        banDuration = 'short',
        tolerance = 1,
        minZ = -50.0
    },

    wallBreach = {
        enabled = true,
        punishment = 'teleport',
        banDuration = 'medium',
        tolerance = 2
    }
}
-- -----------------------------------------------------------------------------
-- DETECCIONES DE COMBATE
-- -----------------------------------------------------------------------------

Config.Combat = {
    godMode = {
        enabled = true,
        punishment = 'ban_temp',
        banDuration = 'long',
        tolerance = 2,
        damageThreshold = 300, -- Dano minimo para verificar
        checkInterval = 3000,  -- Verificar cada 3 segundos
        minDamageEvents = 5    -- Eventos de dano minimos
    },

     invisible = {
         enabled = true,
         punishment = 'ban_temp',
         banDuration = 'medium',
         tolerance = 2,
         minAlpha = 50,
         checkInterval = 3000
     },

    healthHack = {
        enabled = true,
        punishment = 'kill',
        banDuration = 'medium',
        tolerance = 1,
        maxHealth = 200,
        buffer = 50
    },

    armorHack = {
        enabled = true,
        punishment = 'kill',
        banDuration = 'medium',
        tolerance = 1,
        maxArmor = 100,
        buffer = 10
    },
-- -----------------------------------------------------------------------------

    rapidFire = {
        enabled = true,
        punishment = 'ban_temp',
        banDuration = 'medium',
        tolerance = 1,
        fireDelayTolerance = 0.5, -- 50% de tolerancia
        consecutiveViolations = 5 -- Violaciones consecutivas para ban
    },

    infiniteAmmo = {
        enabled = true,
        punishment = 'ban_temp',
        banDuration = 'long',
        tolerance = 1,
        shotsBeforeCheck = 15,    -- Disparos antes de verificar
        ammoTolerancePercent = 10 -- 10% margen de error
    },

    fastReload = {
        enabled = true,
        punishment = 'ban_temp',
        banDuration = 'medium',
        tolerance = 2,
        reloadSpeedTolerance = 0.3 -- 30% del tiempo normal
    },

    noRecoil = {
        enabled = true,
        punishment = 'warn',
        tolerance = 5,
        checkInterval = 50,
        minRecoilAngle = 0.1, -- Grados minimos de retroceso
        consecutiveShotsToCheck = 10
    },

    noSpread = {
        enabled = true,
        punishment = 'warn',
        tolerance = 10,
        checkInterval = 100,
        maxPerfectHits = 15 -- Headshots perfectos sospechosos
    },

    explosiveSpam = {
        enabled = true,
        punishment = 'ban_perm',
        tolerance = 1,
        maxExplosionsPerSecond = 2,
        trackingWindow = 3000
    }
}
-- -----------------------------------------------------------------------------
-- DETECCIONES ULTRA (NUEVAS)
-- -----------------------------------------------------------------------------

Config.Ultra = {
    citizenExploit = {
        enabled = true,
        punishment = 'ban_perm',
        tolerance = 1,
        checkInterval = 30000,
        suspiciousResourceNames = {
            'ai', 'godmode', 'cheat', 'mod', 'menu', 'hack', 'trainer',
            'immortal', 'unlimited', 'god', 'norecoil', 'aimbot', 'esp',
            'wallhack', 'triggerbot', 'nocd', 'infinite', 'bypass'
        }
    },

    aimbotUltra = {
        enabled = true,
        punishment = 'ban_temp',
        banDuration = 'long',
        tolerance = 1,
        minAimSpeedThreshold = 300.0,
        suspiciousSnapThreshold = 200.0,
        consecutiveSnapsForBan = 5,
        trackingWindow = 5000,
        checkInterval = 50
    },

    healthRegen = {
        enabled = true,
        punishment = 'ban_temp',
        banDuration = 'medium',
        tolerance = 2,
        maxHealthGainPerSecond = 5,
        monitoringWindow = 3000,
        minHealthGainForDetection = 50
    },

    ammoExploit = {
        enabled = true,
        punishment = 'ban_temp',
        banDuration = 'medium',
        tolerance = 2,
        maxAmmoGain = 100,
        shotsBeforeCheck = 10,
        checkInterval = 1000
    },

    vehicleSpawn = {
        enabled = true,
        punishment = 'warn',
        tolerance = 3,
        maxVehiclesPerMinute = 3,
        checkInterval = 5000,
        blacklistedVehicles = {
            'hydra', 'lazer', 'khanjali', 'rhino', 'hunter', 'savage',
            'akula', 'strikeforce', 'bombushka', 'volatol', 'titan'
        }
    },

    weaponSpawn = {
        enabled = true,
        punishment = 'warn',
        tolerance = 2,
        checkInterval = 2000,
        maxWeaponsPerMinute = 5
    },

    modelExploit = {
        enabled = true,
        punishment = 'kick',
        tolerance = 3,
        checkInterval = 5000,
        maxModelChangesPerMinute = 3,
        blacklistedModels = {
            'a_c_chicken', 'a_c_hen', 'a_c_pigeon', 'a_c_seagull',
            'slod_human', 'slod_large_quadped', 's_m_m_movspace_01'
        }
    },

    moneyExploit = {
        enabled = true,
        punishment = 'ban_temp',
        banDuration = 'long',
        tolerance = 1,
        maxMoneyGainPerMinute = 500000,
        checkInterval = 5000
    }
}
-- -----------------------------------------------------------------------------
-- DETECCIONES DE ENTIDADES
-- -----------------------------------------------------------------------------

Config.Entities = {
    explosion = {
        enabled = true,
        punishment = 'ban_temp',
        banDuration = 'long',
        tolerance = 1,
        maxPerMinute = 3,
        -- Blacklisted explosion types (FiveM explosion type IDs)
        -- Full list: https://docs.fivem.net/docs/game-references/explosion-types/
        blacklistedTypes = {
            0,   -- GRENADE
            2,   -- MOLOTOV
            4,   -- PLANE_ROCKET
            6,   -- TANK_SHELL
            7,   -- ROCKET
            8,   -- WATER
            11,  -- GAS_CANISTER
            14,  -- TRAIN
            16,  -- BARREL
            17,  -- PROPANE
            18,  -- BLIMP
            20,  -- FLAME
            21,  -- TANKER
            22,  -- TRUCK
            23,  -- BULLET
            24,  -- SMOKE_GL
            25,  -- SMOKE
            26,  -- BEEHIVE
            27,  -- FLARE
            28,  -- GAS_CANISTER_2
            29,  -- EXTINGUISHER
            30,  -- FIREWORK
            31,  -- SNOWBALL
            32,  -- PROXMINE
            33,  -- VALKYRIE_CANNON
            34,  -- AIR_DEFENCE
            35,  -- PIPEBOMB
            36,  -- VEHICLE_MINE
            37,  -- EXPLOSIVE_AMMO
            38,  -- APC_SHELL
            39,  -- CLUSTER_MINE
            40,  -- HUNTER_BARRAGE
            41,  -- HUNTER_MISSILE
            42,  -- TORPEDO
            43,  -- TORPEDO_UNDERWATER
            44,  -- BOMBUSHKA_CANNON
            45,  -- ORBITAL_CANNON
            46,  -- SUBMARINE_BIG
        },
        -- Auto-block explosions near spawn (anti-griefing)
        protectedZones = {
            { x = -269.4, y = -955.3, z = 31.2, radius = 50.0 }, -- Hospital spawn
        }
    },

    cageTrap = {
        enabled = true,
        punishment = 'ban_temp',
        banDuration = 'long',
        tolerance = 1
    },

    vehicleGodMode = {
        enabled = true,
        punishment = 'kick',
        banDuration = 'medium',
        tolerance = 2,
        damageThreshold = 1000
    },
-- -----------------------------------------------------------------------------
    -- ENTITY FIREWALL (Anti-EntitySpawn v2)
    -- Server-side budgets per player + repeated model/hash detection with progressive escalation.
    -- This is intentionally conservative to avoid breaking legitimate scripts.
-- -----------------------------------------------------------------------------
    entityFirewall = {
        enabled = true,

        -- Time window for budgets (ms)
        windowMs = 10000,

        -- Budgets per player per window
        budgets = {
            -- High limits by default to avoid false positives on busy servers.
            -- The firewall still cancels abusive creation when these limits are exceeded.
            vehicles = 15,
            peds = 35,
            objects = 120,
        },

        -- If the same model/hash is spawned too many times within the window, flag
        maxSameModel = 25,

        -- Progressive escalation strikes (per player)
        strikes = {
            decayMs = 60000, -- 1 min without violations => -1 strike
            kickAt = 4,
            tempBanAt = 6,
            permBanAt = 9,
            tempBanDuration = 'long',
        },

        -- For obvious abuse: cancel entity creation immediately when blacklisted/spam detected
        cancelOnViolation = true,
    },


    -- Server-side PTFX spam (grief) protection.
    -- Disabled by default to avoid breaking legit VFX-heavy scripts.
    ptfx = {
        enabled = false,
        punishment = 'notify',
        tolerance = 1,
        maxPerMinute = 60
    },

    -- Server-side clearPedTasksEvent spam protection (can be used to troll/interrupt players).
    clearPedTasks = {
        enabled = false,
        punishment = 'warn',
        tolerance = 2,
        maxPerMinute = 30
    },
-- -----------------------------------------------------------------------------
    -- ANTI-YANK FROM VEHICLE (Player Protection)
    -- Protects players from being forcefully removed from vehicles
-- -----------------------------------------------------------------------------
    antiYank = {
        enabled = true,
        punishment = 'warn',
        banDuration = 'short',
        tolerance = 2,
        -- If victim is in a locked vehicle or driving, prevent yanking
        protectLockedVehicles = true,
        protectDrivers = true,
        -- Grace period after entering vehicle (ms)
        gracePeriod = 2000,
        -- Jobs that CAN yank players (police, etc)
        allowedJobs = {
            'police',
            'sheriff',
            'fib'
        }
    }
}
-- -----------------------------------------------------------------------------
-- BLACKLISTS
-- Listas faciles de modificar
-- -----------------------------------------------------------------------------

Config.Blacklists = {
    weapons = {
        enabled = true,
        punishment = 'warn',
        banDuration = 'short',
        removeWeapon = true,
        list = {
            'WEAPON_MINIGUN',
            'WEAPON_RAILGUN',
            'WEAPON_STUNGUN_MP',
            'WEAPON_RPG',
            -- Anadir mas aqui
        }
    },

    vehicles = {
        enabled = true,
        punishment = 'warn',
        banDuration = 'short',
        deleteVehicle = true,
        list = {
            'hydra',
            'lazer',
            'rhino',
            'khanjali',
            'oppressor2',
            -- Anadir mas aqui
        }
    },

    peds = {
        enabled = false,
        punishment = 'kick',
        banDuration = 'medium',
        forceReset = true,
        defaultModel = 'mp_m_freemode_01',
        list = {
            -- Anadir modelos prohibidos aqui
        }
    }
}
-- -----------------------------------------------------------------------------
-- DETECCIONES AVANZADAS
-- -----------------------------------------------------------------------------

Config.Advanced = {
    injection = {
        enabled = true,
        punishment = 'ban_perm',
        tolerance = 1,
        checkInterval = 30000,
        knownExecutors = {
            'eulen', 'hammafia', 'sakura', 'redengine', 'skript',
            'lynx', 'brutan', 'cipher', 'sentinel', 'desudo'
        }
    },

    afkFarming = {
        enabled = true,
        punishment = 'kick',
        tolerance = 1,
        maxAFKTime = 900000 -- 15 minutos
    },

    resourceValidation = {
        enabled = true,
        punishment = 'kick',
        tolerance = 1,
        requiredResources = {
            'es_extended',
            'lyx-guard'
        }
    },

    -- Heartbeat client -> server (anti tamper / module down detection)
    heartbeat = {
        enabled = true,
        -- Quarantine handles escalation (warn->warn->ban). Keep direct punishment as NONE to reduce false kicks.
        punishment = 'none',
        tolerance = 3,     -- misses before punishment escalation
        intervalMs = 10000, -- client send interval
        timeoutMs = 30000, -- how long without heartbeat counts as a miss
        graceSeconds = 30, -- time after join before enforcing
        -- Avoid repeated strikes/flags every heartbeat when a module list is missing/low.
        integrityFlagCooldownMs = 60000,
        -- Optional module integrity checks (heartbeat v2). Kept conservative by default.
        minDetections = 0,
        minProtections = 0,
        requiredDetections = {}, -- exact names from client/detections registry (optional)
        requiredProtections = {}, -- exact names from client/protections registry (optional)
    },

    honeypotEvent = {
        enabled = true,
        punishment = 'ban_perm',
        tolerance = 1,
        events = {
            '365TageGechillt',
            'f0ba1292-b68d-4d95-8823-6230cdf282b6',
            '265df2d8-421b-4727-b01d-b92fd6503f5e',
            'c65a46c5-5485-4404-bacf-06a106900258'
        }
    },

    -- Honeypot for known cheat-style chat commands.
    -- If a player executes any command in this list, it is treated as high-confidence cheat behavior.
    honeypotCommands = {
        enabled = true,
        punishment = 'ban_perm',
        tolerance = 1,
        commands = {
            'lynx',
            'lynxmenu',
            'hammafia',
            'brutan',
            'redengine',
            'eulen',
            'executor',
            'desudo'
        }
    }
}
-- -----------------------------------------------------------------------------
-- COMO ANADIR UNA NUEVA DETECCION:
-- -----------------------------------------------------------------------------
--[[
    1. Anadir config aqui en la seccion apropiada:

       miNuevaDeteccion = {
           enabled = true,
           punishment = 'warn',
           banDuration = 'short',
           tolerance = 3,
           -- tus parametros personalizados
       },

    2. Crear archivo en client/detections/ (o anadir a uno existente):

       RegisterDetection('miNuevaDeteccion', Config.Movement.miNuevaDeteccion,
           function(config, state)
               -- Tu logica aqui
               -- Retorna true, {detalles} si detecta algo
               return false
           end)

    3. Listo! Se registra automaticamente
]]



-- ---------------------------------------------------------------------------
-- PROFILE OVERRIDES (applied after full config load)
-- ---------------------------------------------------------------------------

local function _DeepMerge(dst, src)
    if type(dst) ~= 'table' or type(src) ~= 'table' then return dst end
    for k, v in pairs(src) do
        if type(v) == 'table' then
            if type(dst[k]) ~= 'table' then dst[k] = {} end
            _DeepMerge(dst[k], v)
        else
            dst[k] = v
        end
    end
    return dst
end

do
    local profileName = tostring(Config.RuntimeProfile or 'default')
    if profileName ~= '' and profileName ~= 'default' then
        local preset = Config.ProfilePresets and Config.ProfilePresets[profileName] or nil
        if type(preset) == 'table' then
            _DeepMerge(Config, preset)
            print(('[LyxGuard] Runtime profile applied: %s'):format(profileName))
        else
            print(('[LyxGuard] Runtime profile not found: %s (using default)'):format(profileName))
        end
    end
end

