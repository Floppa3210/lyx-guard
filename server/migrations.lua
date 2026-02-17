--[[
    LyxGuard - Versioned DB Migrations

    Goals:
    - Replace ad-hoc SQL / manual imports with a versioned migration runner
    - Keep schema changes idempotent and production-safe (no DROP TABLE)
]]

LyxGuard = LyxGuard or {}
LyxGuard.Migrations = LyxGuard.Migrations or {}

local MIGRATIONS_TABLE = 'lyxguard_schema_migrations'

local function _Exec(query, params)
    local ok, err = pcall(function()
        return MySQL.Sync.execute(query, params or {})
    end)
    if not ok then
        if LyxGuardLib and LyxGuardLib.Error then
            LyxGuardLib.Error('[MIGRATIONS] Query failed: %s', tostring(err))
        else
            print(('[LyxGuard][MIGRATIONS] Query failed: %s'):format(tostring(err)))
        end
        return false
    end
    return true
end

local function _FetchAll(query, params)
    local ok, res = pcall(function()
        return MySQL.Sync.fetchAll(query, params or {})
    end)
    if not ok then
        if LyxGuardLib and LyxGuardLib.Error then
            LyxGuardLib.Error('[MIGRATIONS] Fetch failed: %s', tostring(res))
        else
            print(('[LyxGuard][MIGRATIONS] Fetch failed: %s'):format(tostring(res)))
        end
        return nil
    end
    return res or {}
end

local function _ColumnExists(tableName, columnName)
    local rows = _FetchAll([[
        SELECT COUNT(*) AS c
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND COLUMN_NAME = ?
    ]], { tableName, columnName })

    local c = rows and rows[1] and tonumber(rows[1].c) or 0
    return c > 0
end

local function _EnsureMigrationsTable()
    return _Exec(([[
        CREATE TABLE IF NOT EXISTS %s (
            version INT UNSIGNED NOT NULL PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]]):format(MIGRATIONS_TABLE))
end

local function _GetAppliedVersions()
    local applied = {}
    local rows = _FetchAll(('SELECT version FROM %s'):format(MIGRATIONS_TABLE))
    for _, r in ipairs(rows or {}) do
        local v = tonumber(r.version)
        if v then applied[v] = true end
    end
    return applied
end

local function _ApplyMigration(m)
    local msg = ('[LyxGuard][MIGRATIONS] Applying v%d: %s'):format(m.version, m.name)
    if LyxGuardLib and LyxGuardLib.Info then
        LyxGuardLib.Info(msg)
    else
        print(msg)
    end

    local ok, err = pcall(m.up)
    if not ok then
        if LyxGuardLib and LyxGuardLib.Error then
            LyxGuardLib.Error('[MIGRATIONS] Migration v%d failed: %s', m.version, tostring(err))
        else
            print(('[LyxGuard][MIGRATIONS] Migration v%d failed: %s'):format(m.version, tostring(err)))
        end
        return false
    end

    _Exec(('INSERT IGNORE INTO %s (version, name) VALUES (?, ?)'):format(MIGRATIONS_TABLE), { m.version, m.name })
    return true
end

local function _EnsureColumn(tableName, columnName, alterSql)
    if _ColumnExists(tableName, columnName) then return true end
    return _Exec(alterSql)
end

local MIGRATIONS = {
    {
        version = 1,
        name = 'core_tables',
        up = function()
            -- Bans (include tokens for HWID/token bans)
            _Exec([[
                CREATE TABLE IF NOT EXISTS lyxguard_bans (
                    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                    identifier VARCHAR(255) NOT NULL,
                    steam VARCHAR(255),
                    discord VARCHAR(255),
                    license VARCHAR(255),
                    fivem VARCHAR(255),
                    ip VARCHAR(64),
                    tokens JSON DEFAULT NULL,
                    player_name VARCHAR(100),
                    reason TEXT NOT NULL,
                    ban_date DATETIME DEFAULT CURRENT_TIMESTAMP,
                    unban_date DATETIME,
                    permanent TINYINT(1) DEFAULT 0,
                    banned_by VARCHAR(100) DEFAULT 'LyxGuard',
                    unbanned_by VARCHAR(100),
                    unban_reason TEXT,
                    active TINYINT(1) DEFAULT 1,
                    INDEX idx_identifier (identifier),
                    INDEX idx_license (license),
                    INDEX idx_steam (steam),
                    INDEX idx_discord (discord),
                    INDEX idx_active (active),
                    INDEX idx_ban_date (ban_date)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            ]])

            -- Detections
            _Exec([[
                CREATE TABLE IF NOT EXISTS lyxguard_detections (
                    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                    player_name VARCHAR(100) NOT NULL,
                    identifier VARCHAR(255) NOT NULL,
                    steam VARCHAR(255),
                    discord VARCHAR(255),
                    detection_type VARCHAR(100) NOT NULL,
                    details JSON,
                    coords VARCHAR(100),
                    punishment VARCHAR(50) NOT NULL,
                    detection_date DATETIME DEFAULT CURRENT_TIMESTAMP,
                    server_id INT DEFAULT NULL,
                    INDEX idx_identifier (identifier),
                    INDEX idx_type (detection_type),
                    INDEX idx_date (detection_date)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            ]])

            -- Warnings
            _Exec([[
                CREATE TABLE IF NOT EXISTS lyxguard_warnings (
                    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                    identifier VARCHAR(255) NOT NULL,
                    player_name VARCHAR(100),
                    reason TEXT NOT NULL,
                    warned_by VARCHAR(100) DEFAULT 'LyxGuard',
                    warn_date DATETIME DEFAULT CURRENT_TIMESTAMP,
                    expires_at DATETIME,
                    active TINYINT(1) DEFAULT 1,
                    INDEX idx_identifier (identifier),
                    INDEX idx_active (active),
                    INDEX idx_identifier_active (identifier, active)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            ]])

            -- Whitelist (level/notes used by admin_config.lua)
            _Exec([[
                CREATE TABLE IF NOT EXISTS lyxguard_whitelist (
                    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                    identifier VARCHAR(255) NOT NULL,
                    player_name VARCHAR(100),
                    level ENUM('full','vip','none') NOT NULL DEFAULT 'full',
                    added_by VARCHAR(100) DEFAULT 'Admin',
                    notes TEXT,
                    date DATETIME DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE KEY uniq_identifier (identifier)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            ]])

            -- Offline cache for HWID/token bans
            _Exec([[
                CREATE TABLE IF NOT EXISTS lyxguard_player_cache (
                    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                    identifier VARCHAR(255) NOT NULL,
                    player_name VARCHAR(100) NOT NULL,
                    steam VARCHAR(255),
                    discord VARCHAR(255),
                    license VARCHAR(255),
                    fivem VARCHAR(255),
                    ip VARCHAR(64),
                    tokens JSON,
                    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
                    play_time INT DEFAULT 0,
                    INDEX idx_identifier (identifier),
                    INDEX idx_license (license),
                    INDEX idx_name (player_name),
                    INDEX idx_last_seen (last_seen)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            ]])

            -- Money logs (created ad-hoc previously in detections.lua)
            _Exec([[
                CREATE TABLE IF NOT EXISTS lyxguard_money_logs (
                    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                    identifier VARCHAR(255) NOT NULL,
                    player_name VARCHAR(100),
                    account VARCHAR(50),
                    amount INT,
                    reason VARCHAR(255),
                    log_date DATETIME DEFAULT CURRENT_TIMESTAMP,
                    INDEX idx_identifier (identifier),
                    INDEX idx_log_date (log_date)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            ]])

            -- Backfill/ensure columns for legacy installs (CREATE TABLE IF NOT EXISTS does not add columns).
            _EnsureColumn('lyxguard_bans', 'tokens', 'ALTER TABLE lyxguard_bans ADD COLUMN tokens JSON DEFAULT NULL AFTER ip')
            _EnsureColumn('lyxguard_bans', 'unban_reason', 'ALTER TABLE lyxguard_bans ADD COLUMN unban_reason TEXT DEFAULT NULL AFTER unbanned_by')

            _EnsureColumn('lyxguard_whitelist', 'level',
                "ALTER TABLE lyxguard_whitelist ADD COLUMN level ENUM('full','vip','none') NOT NULL DEFAULT 'full' AFTER player_name")
            _EnsureColumn('lyxguard_whitelist', 'notes', 'ALTER TABLE lyxguard_whitelist ADD COLUMN notes TEXT DEFAULT NULL AFTER added_by')
        end
    },
    {
        version = 2,
        name = 'ban_hardening_token_hashes_fingerprint',
        up = function()
            -- Ban hardening:
            -- - token_hashes: deterministic hashes of player tokens for exact matching (avoid weak LIKE-only checks)
            -- - identifier_fingerprint: stable fingerprint across key identifiers for anti-spoof/ban evasion
            _EnsureColumn('lyxguard_bans', 'token_hashes',
                'ALTER TABLE lyxguard_bans ADD COLUMN token_hashes JSON DEFAULT NULL AFTER tokens')
            _EnsureColumn('lyxguard_bans', 'identifier_fingerprint',
                'ALTER TABLE lyxguard_bans ADD COLUMN identifier_fingerprint VARCHAR(128) DEFAULT NULL AFTER token_hashes')

            -- Optional lookup index (safe if already exists due IF NOT EXISTS behavior differences).
            -- Some MySQL variants do not support IF NOT EXISTS on ADD INDEX; ignore failures.
            pcall(function()
                _Exec('ALTER TABLE lyxguard_bans ADD INDEX idx_identifier_fingerprint (identifier_fingerprint)')
            end)
        end
    }
}

function LyxGuard.Migrations.Apply()
    if not MySQL or not MySQL.Sync then
        print('^1[LyxGuard][MIGRATIONS]^7 MySQL not ready')
        return false
    end

    if not _EnsureMigrationsTable() then
        return false
    end

    local applied = _GetAppliedVersions()
    table.sort(MIGRATIONS, function(a, b) return a.version < b.version end)

    for _, m in ipairs(MIGRATIONS) do
        if not applied[m.version] then
            local ok = _ApplyMigration(m)
            if not ok then
                return false
            end
        end
    end

    if LyxGuardLib and LyxGuardLib.Info then
        LyxGuardLib.Info('[MIGRATIONS] OK')
    else
        print('^2[LyxGuard][MIGRATIONS]^7 OK')
    end
    return true
end

print('^2[LyxGuard]^7 migrations module loaded')
