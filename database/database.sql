-- ═══════════════════════════════════════════════════════════════════════════════
-- LYXGUARD + LYXPANEL DATABASE SCHEMA
-- Versión: 4.0.0
-- Compatibilidad: MySQL 5.7+ / MariaDB 10.2+
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- INSTRUCCIONES DE IMPORTACIÓN:
-- 1. Abre tu cliente MySQL (HeidiSQL, phpMyAdmin, o terminal)
-- 2. Selecciona la base de datos de tu servidor FiveM
-- 3. Ejecuta este archivo completo
-- 4. Reinicia lyx-guard y lyx-panel
--
-- Si usas terminal:
--   mysql -u usuario -p nombre_base < database.sql
--
-- NOTA DE SEGURIDAD:
--   Este archivo NO borra datos (sin DROP TABLE) para evitar accidentes en produccion.
--   Si queres resetear tablas en DEV/TEST, usa `database_reset.sql` a proposito.
--
-- ═══════════════════════════════════════════════════════════════════════════════

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ═══════════════════════════════════════════════════════════════════════════════
-- LYXGUARD TABLES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Tabla de bans
-- Almacena todos los bans activos e históricos
CREATE TABLE IF NOT EXISTS `lyxguard_bans` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(255) NOT NULL COMMENT 'Identificador principal (license)',
    `steam` VARCHAR(255) DEFAULT NULL COMMENT 'Steam hex ID',
    `discord` VARCHAR(255) DEFAULT NULL COMMENT 'Discord ID',
    `license` VARCHAR(255) DEFAULT NULL COMMENT 'Rockstar license',
    `fivem` VARCHAR(255) DEFAULT NULL COMMENT 'FiveM ID',
    `ip` VARCHAR(64) DEFAULT NULL COMMENT 'IP al momento del ban (hashed recomendado)',
    `player_name` VARCHAR(100) DEFAULT NULL COMMENT 'Nombre del jugador al ser baneado',
    `reason` TEXT NOT NULL COMMENT 'Razón del ban',
    `ban_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `unban_date` DATETIME DEFAULT NULL COMMENT 'NULL si permanente',
    `permanent` TINYINT(1) NOT NULL DEFAULT 0,
    `banned_by` VARCHAR(100) NOT NULL DEFAULT 'LyxGuard',
    `unbanned_by` VARCHAR(100) DEFAULT NULL,
    `unban_reason` TEXT DEFAULT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_license` (`license`),
    INDEX `idx_steam` (`steam`),
    INDEX `idx_discord` (`discord`),
    INDEX `idx_active` (`active`),
    INDEX `idx_ban_date` (`ban_date`),
    INDEX `idx_active_unban` (`active`, `unban_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de detecciones
-- Log de todas las detecciones del anti-cheat
CREATE TABLE IF NOT EXISTS `lyxguard_detections` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_name` VARCHAR(100) NOT NULL,
    `identifier` VARCHAR(255) NOT NULL,
    `steam` VARCHAR(255) DEFAULT NULL,
    `discord` VARCHAR(255) DEFAULT NULL,
    `detection_type` VARCHAR(100) NOT NULL COMMENT 'Tipo de hack detectado',
    `details` JSON DEFAULT NULL COMMENT 'Detalles adicionales en JSON',
    `coords` VARCHAR(100) DEFAULT NULL COMMENT 'Coordenadas x,y,z',
    `punishment` VARCHAR(50) NOT NULL COMMENT 'Castigo aplicado',
    `detection_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `server_id` INT DEFAULT NULL COMMENT 'ID del servidor si multi-server',
    PRIMARY KEY (`id`),
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_detection_type` (`detection_type`),
    INDEX `idx_detection_date` (`detection_date`),
    INDEX `idx_date_type` (`detection_date`, `detection_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de warnings
-- Sistema de advertencias acumulativas
CREATE TABLE IF NOT EXISTS `lyxguard_warnings` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(255) NOT NULL,
    `player_name` VARCHAR(100) DEFAULT NULL,
    `reason` TEXT NOT NULL,
    `warned_by` VARCHAR(100) NOT NULL DEFAULT 'LyxGuard',
    `warn_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` DATETIME DEFAULT NULL COMMENT 'NULL = nunca expira',
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_active` (`active`),
    INDEX `idx_identifier_active` (`identifier`, `active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de whitelist
-- Jugadores con inmunidad al anticheat
CREATE TABLE IF NOT EXISTS `lyxguard_whitelist` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(255) NOT NULL COMMENT 'Identificador del jugador',
    `player_name` VARCHAR(100) DEFAULT NULL COMMENT 'Nombre del jugador',
    `level` ENUM('full', 'vip', 'none') NOT NULL DEFAULT 'full' COMMENT 'Nivel de inmunidad',
    `added_by` VARCHAR(100) NOT NULL DEFAULT 'Admin',
    `notes` TEXT DEFAULT NULL COMMENT 'Notas del admin',
    `date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE INDEX `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══════════════════════════════════════════════════════════════════════════════
-- LYXPANEL TABLES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Tabla de reportes
-- Sistema de reportes de jugadores
CREATE TABLE IF NOT EXISTS `lyxpanel_reports` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `reporter_id` VARCHAR(255) NOT NULL COMMENT 'Identifier del reportador',
    `reporter_name` VARCHAR(100) NOT NULL,
    `reported_id` VARCHAR(255) DEFAULT NULL COMMENT 'Identifier del reportado (opcional)',
    `reported_name` VARCHAR(100) DEFAULT NULL,
    `reason` TEXT NOT NULL,
    `category` VARCHAR(50) DEFAULT 'general' COMMENT 'hacker, bug, player, etc',
    `priority` ENUM('low', 'medium', 'high', 'critical') NOT NULL DEFAULT 'medium',
    `status` ENUM('open', 'in_progress', 'closed', 'rejected') NOT NULL DEFAULT 'open',
    `assigned_to` VARCHAR(255) DEFAULT NULL COMMENT 'Admin asignado',
    `assigned_name` VARCHAR(100) DEFAULT NULL,
    `admin_notes` TEXT DEFAULT NULL,
    `resolution` TEXT DEFAULT NULL,
    `evidence` TEXT DEFAULT NULL COMMENT 'URLs de evidencia',
    `coords` VARCHAR(100) DEFAULT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    `closed_at` DATETIME DEFAULT NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_reporter` (`reporter_id`),
    INDEX `idx_reported` (`reported_id`),
    INDEX `idx_status` (`status`),
    INDEX `idx_priority` (`priority`),
    INDEX `idx_assigned` (`assigned_to`),
    INDEX `idx_status_priority` (`status`, `priority`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de logs de admin
-- Historial de todas las acciones administrativas
CREATE TABLE IF NOT EXISTS `lyxpanel_logs` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `admin_id` VARCHAR(255) NOT NULL,
    `admin_name` VARCHAR(100) NOT NULL,
    `action` VARCHAR(100) NOT NULL COMMENT 'KICK, BAN, GIVE_MONEY, etc',
    `target_id` VARCHAR(255) DEFAULT NULL,
    `target_name` VARCHAR(100) DEFAULT NULL,
    `details` JSON DEFAULT NULL COMMENT 'Detalles adicionales',
    `ip_address` VARCHAR(64) DEFAULT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_admin` (`admin_id`),
    INDEX `idx_action` (`action`),
    INDEX `idx_target` (`target_id`),
    INDEX `idx_created` (`created_at`),
    INDEX `idx_admin_action` (`admin_id`, `action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de notas de jugadores
-- Notas persistentes sobre jugadores
CREATE TABLE IF NOT EXISTS `lyxpanel_notes` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `target_id` VARCHAR(255) NOT NULL COMMENT 'Jugador objetivo',
    `target_name` VARCHAR(100) DEFAULT NULL,
    `note` TEXT NOT NULL,
    `category` VARCHAR(50) DEFAULT 'general' COMMENT 'warning, info, positive, negative',
    `admin_id` VARCHAR(255) NOT NULL,
    `admin_name` VARCHAR(100) NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_target` (`target_id`),
    INDEX `idx_admin` (`admin_id`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de tickets
-- Sistema de tickets de soporte
CREATE TABLE IF NOT EXISTS `lyxpanel_tickets` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_id` VARCHAR(255) NOT NULL,
    `player_name` VARCHAR(100) NOT NULL,
    `subject` VARCHAR(255) NOT NULL,
    `message` TEXT NOT NULL,
    `category` VARCHAR(50) DEFAULT 'general',
    `status` ENUM('open', 'answered', 'awaiting_reply', 'closed') NOT NULL DEFAULT 'open',
    `priority` ENUM('low', 'medium', 'high') NOT NULL DEFAULT 'medium',
    `admin_id` VARCHAR(255) DEFAULT NULL,
    `admin_name` VARCHAR(100) DEFAULT NULL,
    `admin_response` TEXT DEFAULT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    `closed_at` DATETIME DEFAULT NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_player` (`player_id`),
    INDEX `idx_status` (`status`),
    INDEX `idx_admin` (`admin_id`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de transacciones económicas
-- Log de cambios de dinero por admins
CREATE TABLE IF NOT EXISTS `lyxpanel_transactions` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_id` VARCHAR(255) NOT NULL,
    `player_name` VARCHAR(100) NOT NULL,
    `type` ENUM('give', 'set', 'remove', 'transfer_in', 'transfer_out') NOT NULL,
    `amount` BIGINT NOT NULL COMMENT 'Puede ser negativo para removes',
    `account` VARCHAR(50) NOT NULL COMMENT 'money, bank, black_money',
    `balance_before` BIGINT DEFAULT NULL,
    `balance_after` BIGINT DEFAULT NULL,
    `admin_id` VARCHAR(255) NOT NULL,
    `admin_name` VARCHAR(100) NOT NULL,
    `reason` TEXT DEFAULT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_player` (`player_id`),
    INDEX `idx_admin` (`admin_id`),
    INDEX `idx_type` (`type`),
    INDEX `idx_created` (`created_at`),
    INDEX `idx_player_account` (`player_id`, `account`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLEANUP PROCEDURES (Opcional)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Procedimiento para limpiar detecciones antiguas (más de 90 días)
DROP PROCEDURE IF EXISTS `lyxguard_cleanup_detections`;
DELIMITER //
CREATE PROCEDURE `lyxguard_cleanup_detections`()
BEGIN
    DELETE FROM `lyxguard_detections` 
    WHERE `detection_date` < DATE_SUB(NOW(), INTERVAL 90 DAY);
END //
DELIMITER ;

-- Procedimiento para limpiar warnings expirados
DROP PROCEDURE IF EXISTS `lyxguard_cleanup_warnings`;
DELIMITER //
CREATE PROCEDURE `lyxguard_cleanup_warnings`()
BEGIN
    UPDATE `lyxguard_warnings` 
    SET `active` = 0 
    WHERE `expires_at` IS NOT NULL 
    AND `expires_at` < NOW() 
    AND `active` = 1;
END //
DELIMITER ;

-- Procedimiento para desbanear automáticamente bans temporales expirados
DROP PROCEDURE IF EXISTS `lyxguard_process_unbans`;
DELIMITER //
CREATE PROCEDURE `lyxguard_process_unbans`()
BEGIN
    UPDATE `lyxguard_bans` 
    SET `active` = 0, `unbanned_by` = 'SYSTEM_AUTO', `unban_reason` = 'Ban temporal expirado'
    WHERE `permanent` = 0 
    AND `unban_date` IS NOT NULL 
    AND `unban_date` < NOW() 
    AND `active` = 1;
END //
DELIMITER ;

-- ═══════════════════════════════════════════════════════════════════════════════
-- EVENTOS PROGRAMADOS (Opcional - Requiere EVENT_SCHEDULER activo)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Descomenta si tienes EVENT_SCHEDULER habilitado
-- 
-- CREATE EVENT IF NOT EXISTS `lyxguard_auto_unban`
-- ON SCHEDULE EVERY 5 MINUTE
-- DO CALL lyxguard_process_unbans();
-- 
-- CREATE EVENT IF NOT EXISTS `lyxguard_cleanup_old_data`
-- ON SCHEDULE EVERY 1 DAY
-- DO BEGIN
--     CALL lyxguard_cleanup_detections();
--     CALL lyxguard_cleanup_warnings();
-- END;

SET FOREIGN_KEY_CHECKS = 1;

-- ═══════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN
-- ═══════════════════════════════════════════════════════════════════════════════
-- Ejecuta esto para verificar que todas las tablas se crearon correctamente:
-- 
-- SELECT TABLE_NAME, TABLE_ROWS, CREATE_TIME 
-- FROM information_schema.TABLES 
-- WHERE TABLE_SCHEMA = DATABASE() 
-- AND TABLE_NAME LIKE 'lyx%';
-- ═══════════════════════════════════════════════════════════════════════════════
