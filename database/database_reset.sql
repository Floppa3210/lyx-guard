-- ============================================================================
-- LYXGUARD + LYXPANEL DATABASE RESET (DEV/TEST ONLY)
-- ============================================================================
-- WARNING:
--   This script DROPS tables and will DELETE ALL DATA.
--   Do NOT run this in production.
--
-- Usage:
--   1) Run this file only if you intentionally want a clean reset.
--   2) Then run `database.sql` to recreate tables safely.
-- ============================================================================

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS `lyxguard_bans`;
DROP TABLE IF EXISTS `lyxguard_detections`;
DROP TABLE IF EXISTS `lyxguard_warnings`;
DROP TABLE IF EXISTS `lyxguard_whitelist`;

DROP TABLE IF EXISTS `lyxpanel_reports`;
DROP TABLE IF EXISTS `lyxpanel_logs`;
DROP TABLE IF EXISTS `lyxpanel_notes`;
DROP TABLE IF EXISTS `lyxpanel_tickets`;
DROP TABLE IF EXISTS `lyxpanel_transactions`;

SET FOREIGN_KEY_CHECKS = 1;

