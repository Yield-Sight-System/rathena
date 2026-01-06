-- ============================================================================
-- EMERGENCY ROLLBACK: InnoDB/Aria to MyISAM
-- ============================================================================
-- Purpose: Rollback storage engine migration if critical issues occur
-- Target: MariaDB 10.11+ LTS or 11.2+ Stable
-- Risk Level: HIGH (emergency procedure only)
-- Duration: 15-60 minutes (depends on database size)
--
-- ⚠️ CRITICAL WARNING ⚠️
-- This rollback procedure should ONLY be used if:
-- - Critical data corruption detected after migration
-- - Severe performance degradation that cannot be resolved
-- - Game servers completely unable to function with InnoDB/Aria
-- - Instructed by database administrator as emergency measure
--
-- CONSEQUENCES OF ROLLBACK:
-- ✗ Loss of ACID transaction guarantees
-- ✗ Loss of crash recovery capabilities
-- ✗ Return to table-level locking (performance impact)
-- ✗ Loss of foreign key constraints
-- ✗ Return to high-risk MyISAM configuration
--
-- PREREQUISITES BEFORE ROLLBACK:
-- 1. Stop ALL game servers (login, char, map)
-- 2. Ensure no active database connections
-- 3. Create emergency backup of current state
-- 4. Document the reason for rollback
-- 5. Notify all administrators
-- 6. Plan to re-attempt migration after root cause fix
--
-- Usage:
--   mysqldump --single-transaction rathena > pre_rollback_backup.sql
--   mysql -u root -p rathena < rollback_to_myisam.sql > rollback.log 2>&1
--   Review log carefully for errors
-- ============================================================================

SELECT '============================================================================' AS '';
SELECT '⚠️  EMERGENCY ROLLBACK TO MyISAM ⚠️' AS '';
SELECT '============================================================================' AS '';
SELECT NOW() AS 'Rollback Start Time';
SELECT DATABASE() AS 'Target Database';
SELECT USER() AS 'Executing User';
SELECT VERSION() AS 'MariaDB Version';
SELECT '' AS '';

-- Critical warning
SELECT '╔════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║  CRITICAL WARNING: This is an EMERGENCY ROLLBACK procedure            ║' AS '';
SELECT '║  You are about to lose ACID guarantees and crash recovery             ║' AS '';
SELECT '║  capabilities by reverting to MyISAM storage engine.                  ║' AS '';
SELECT '║                                                                        ║' AS '';
SELECT '║  This should ONLY be done as a last resort!                           ║' AS '';
SELECT '║                                                                        ║' AS '';
SELECT '║  Prerequisites:                                                       ║' AS '';
SELECT '║  [ ] All game servers stopped                                         ║' AS '';
SELECT '║  [ ] Emergency backup created                                         ║' AS '';
SELECT '║  [ ] Rollback reason documented                                       ║' AS '';
SELECT '║  [ ] All admins notified                                              ║' AS '';
SELECT '║                                                                        ║' AS '';
SELECT '║  Waiting 10 seconds... Press Ctrl+C to abort if unsure!              ║' AS '';
SELECT '╚════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Show current engine distribution before rollback
SELECT 'Current Storage Engine Distribution (BEFORE ROLLBACK):' AS '';
SELECT 
    ENGINE,
    COUNT(*) AS 'Table Count',
    ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS 'Total Size (MB)'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
GROUP BY ENGINE
ORDER BY COUNT(*) DESC;

SELECT '' AS '';

-- Disable foreign key checks for rollback
SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS = 0;

SELECT 'Foreign key checks and unique checks temporarily disabled for rollback' AS 'Info';
SELECT '' AS '';

-- ============================================================================
-- PHASE 1: ROLLBACK CRITICAL CHARACTER AND ACCOUNT DATA
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 1: ROLLBACK Character and Account Data to MyISAM' AS '';
SELECT '============================================================================' AS '';

-- Character table
SELECT CONCAT('Rolling back: char - ', NOW()) AS 'Progress';
ALTER TABLE `char` ENGINE=MyISAM;
SELECT '✓ char reverted to MyISAM' AS 'Status';

-- Login table
SELECT CONCAT('Rolling back: login - ', NOW()) AS 'Progress';
ALTER TABLE `login` ENGINE=MyISAM;
SELECT '✓ login reverted to MyISAM' AS 'Status';

-- Character registry
SELECT CONCAT('Rolling back: char_reg_num - ', NOW()) AS 'Progress';
ALTER TABLE `char_reg_num` ENGINE=MyISAM;
SELECT '✓ char_reg_num reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: char_reg_str - ', NOW()) AS 'Progress';
ALTER TABLE `char_reg_str` ENGINE=MyISAM;
SELECT '✓ char_reg_str reverted to MyISAM' AS 'Status';

-- Account registry
SELECT CONCAT('Rolling back: acc_reg_num - ', NOW()) AS 'Progress';
ALTER TABLE `acc_reg_num` ENGINE=MyISAM;
SELECT '✓ acc_reg_num reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: acc_reg_str - ', NOW()) AS 'Progress';
ALTER TABLE `acc_reg_str` ENGINE=MyISAM;
SELECT '✓ acc_reg_str reverted to MyISAM' AS 'Status';

-- Global account registry
SELECT CONCAT('Rolling back: global_acc_reg_num - ', NOW()) AS 'Progress';
ALTER TABLE `global_acc_reg_num` ENGINE=MyISAM;
SELECT '✓ global_acc_reg_num reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: global_acc_reg_str - ', NOW()) AS 'Progress';
ALTER TABLE `global_acc_reg_str` ENGINE=MyISAM;
SELECT '✓ global_acc_reg_str reverted to MyISAM' AS 'Status';

SELECT 'PHASE 1 COMPLETE' AS '';
SELECT NOW() AS 'Phase 1 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 2: ROLLBACK INVENTORY AND STORAGE SYSTEMS
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 2: ROLLBACK Inventory and Storage Systems to MyISAM' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Rolling back: inventory - ', NOW()) AS 'Progress';
ALTER TABLE `inventory` ENGINE=MyISAM;
SELECT '✓ inventory reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: storage - ', NOW()) AS 'Progress';
ALTER TABLE `storage` ENGINE=MyISAM;
SELECT '✓ storage reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: cart_inventory - ', NOW()) AS 'Progress';
ALTER TABLE `cart_inventory` ENGINE=MyISAM;
SELECT '✓ cart_inventory reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: guild_storage - ', NOW()) AS 'Progress';
ALTER TABLE `guild_storage` ENGINE=MyISAM;
SELECT '✓ guild_storage reverted to MyISAM' AS 'Status';

SELECT 'PHASE 2 COMPLETE' AS '';
SELECT NOW() AS 'Phase 2 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 3: ROLLBACK GUILD SYSTEM
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 3: ROLLBACK Guild System to MyISAM' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Rolling back: guild - ', NOW()) AS 'Progress';
ALTER TABLE `guild` ENGINE=MyISAM;
SELECT '✓ guild reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: guild_member - ', NOW()) AS 'Progress';
ALTER TABLE `guild_member` ENGINE=MyISAM;
SELECT '✓ guild_member reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: guild_position - ', NOW()) AS 'Progress';
ALTER TABLE `guild_position` ENGINE=MyISAM;
SELECT '✓ guild_position reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: guild_alliance - ', NOW()) AS 'Progress';
ALTER TABLE `guild_alliance` ENGINE=MyISAM;
SELECT '✓ guild_alliance reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: guild_castle - ', NOW()) AS 'Progress';
ALTER TABLE `guild_castle` ENGINE=MyISAM;
SELECT '✓ guild_castle reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: guild_skill - ', NOW()) AS 'Progress';
ALTER TABLE `guild_skill` ENGINE=MyISAM;
SELECT '✓ guild_skill reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: guild_expulsion - ', NOW()) AS 'Progress';
ALTER TABLE `guild_expulsion` ENGINE=MyISAM;
SELECT '✓ guild_expulsion reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: guild_storage_log - ', NOW()) AS 'Progress';
ALTER TABLE `guild_storage_log` ENGINE=MyISAM;
SELECT '✓ guild_storage_log reverted to MyISAM' AS 'Status';

SELECT 'PHASE 3 COMPLETE' AS '';
SELECT NOW() AS 'Phase 3 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 4: ROLLBACK PARTY AND SOCIAL SYSTEMS
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 4: ROLLBACK Party and Social Systems to MyISAM' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Rolling back: party - ', NOW()) AS 'Progress';
ALTER TABLE `party` ENGINE=MyISAM;
SELECT '✓ party reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: party_bookings - ', NOW()) AS 'Progress';
ALTER TABLE `party_bookings` ENGINE=MyISAM;
SELECT '✓ party_bookings reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: friends - ', NOW()) AS 'Progress';
ALTER TABLE `friends` ENGINE=MyISAM;
SELECT '✓ friends reverted to MyISAM' AS 'Status';

SELECT 'PHASE 4 COMPLETE' AS '';
SELECT NOW() AS 'Phase 4 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 5: ROLLBACK COMMUNICATION SYSTEMS
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 5: ROLLBACK Communication Systems to MyISAM' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Rolling back: mail - ', NOW()) AS 'Progress';
ALTER TABLE `mail` ENGINE=MyISAM;
SELECT '✓ mail reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: mail_attachments - ', NOW()) AS 'Progress';
ALTER TABLE `mail_attachments` ENGINE=MyISAM;
SELECT '✓ mail_attachments reverted to MyISAM' AS 'Status';

SELECT 'PHASE 5 COMPLETE' AS '';
SELECT NOW() AS 'Phase 5 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 6: ROLLBACK ECONOMY AND TRADING SYSTEMS
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 6: ROLLBACK Economy and Trading Systems to MyISAM' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Rolling back: auction - ', NOW()) AS 'Progress';
ALTER TABLE `auction` ENGINE=MyISAM;
SELECT '✓ auction reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: vendings - ', NOW()) AS 'Progress';
ALTER TABLE `vendings` ENGINE=MyISAM;
SELECT '✓ vendings reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: vending_items - ', NOW()) AS 'Progress';
ALTER TABLE `vending_items` ENGINE=MyISAM;
SELECT '✓ vending_items reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: buyingstores - ', NOW()) AS 'Progress';
ALTER TABLE `buyingstores` ENGINE=MyISAM;
SELECT '✓ buyingstores reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: buyingstore_items - ', NOW()) AS 'Progress';
ALTER TABLE `buyingstore_items` ENGINE=MyISAM;
SELECT '✓ buyingstore_items reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: barter - ', NOW()) AS 'Progress';
ALTER TABLE `barter` ENGINE=MyISAM;
SELECT '✓ barter reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: market - ', NOW()) AS 'Progress';
ALTER TABLE `market` ENGINE=MyISAM;
SELECT '✓ market reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: sales - ', NOW()) AS 'Progress';
ALTER TABLE `sales` ENGINE=MyISAM;
SELECT '✓ sales reverted to MyISAM' AS 'Status';

SELECT 'PHASE 6 COMPLETE' AS '';
SELECT NOW() AS 'Phase 6 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 7: ROLLBACK GAME SYSTEMS
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 7: ROLLBACK Game Systems to MyISAM' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Rolling back: skill - ', NOW()) AS 'Progress';
ALTER TABLE `skill` ENGINE=MyISAM;
SELECT '✓ skill reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: skillcooldown - ', NOW()) AS 'Progress';
ALTER TABLE `skillcooldown` ENGINE=MyISAM;
SELECT '✓ skillcooldown reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: quest - ', NOW()) AS 'Progress';
ALTER TABLE `quest` ENGINE=MyISAM;
SELECT '✓ quest reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: achievement - ', NOW()) AS 'Progress';
ALTER TABLE `achievement` ENGINE=MyISAM;
SELECT '✓ achievement reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: hotkey - ', NOW()) AS 'Progress';
ALTER TABLE `hotkey` ENGINE=MyISAM;
SELECT '✓ hotkey reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: sc_data - ', NOW()) AS 'Progress';
ALTER TABLE `sc_data` ENGINE=MyISAM;
SELECT '✓ sc_data reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: memo - ', NOW()) AS 'Progress';
ALTER TABLE `memo` ENGINE=MyISAM;
SELECT '✓ memo reverted to MyISAM' AS 'Status';

SELECT 'PHASE 7 COMPLETE' AS '';
SELECT NOW() AS 'Phase 7 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 8: ROLLBACK COMPANION SYSTEMS
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 8: ROLLBACK Companion Systems to MyISAM' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Rolling back: pet - ', NOW()) AS 'Progress';
ALTER TABLE `pet` ENGINE=MyISAM;
SELECT '✓ pet reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: homunculus - ', NOW()) AS 'Progress';
ALTER TABLE `homunculus` ENGINE=MyISAM;
SELECT '✓ homunculus reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: skill_homunculus - ', NOW()) AS 'Progress';
ALTER TABLE `skill_homunculus` ENGINE=MyISAM;
SELECT '✓ skill_homunculus reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: skillcooldown_homunculus - ', NOW()) AS 'Progress';
ALTER TABLE `skillcooldown_homunculus` ENGINE=MyISAM;
SELECT '✓ skillcooldown_homunculus reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: mercenary - ', NOW()) AS 'Progress';
ALTER TABLE `mercenary` ENGINE=MyISAM;
SELECT '✓ mercenary reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: mercenary_owner - ', NOW()) AS 'Progress';
ALTER TABLE `mercenary_owner` ENGINE=MyISAM;
SELECT '✓ mercenary_owner reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: skillcooldown_mercenary - ', NOW()) AS 'Progress';
ALTER TABLE `skillcooldown_mercenary` ENGINE=MyISAM;
SELECT '✓ skillcooldown_mercenary reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: elemental - ', NOW()) AS 'Progress';
ALTER TABLE `elemental` ENGINE=MyISAM;
SELECT '✓ elemental reverted to MyISAM' AS 'Status';

SELECT 'PHASE 8 COMPLETE' AS '';
SELECT NOW() AS 'Phase 8 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 9: ROLLBACK CLAN SYSTEM
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 9: ROLLBACK Clan System to MyISAM' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Rolling back: clan - ', NOW()) AS 'Progress';
ALTER TABLE `clan` ENGINE=MyISAM;
SELECT '✓ clan reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: clan_alliance - ', NOW()) AS 'Progress';
ALTER TABLE `clan_alliance` ENGINE=MyISAM;
SELECT '✓ clan_alliance reverted to MyISAM' AS 'Status';

SELECT 'PHASE 9 COMPLETE' AS '';
SELECT NOW() AS 'Phase 9 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 10: ROLLBACK OTHER SYSTEMS
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 10: ROLLBACK Other Systems to MyISAM' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Rolling back: mapreg - ', NOW()) AS 'Progress';
ALTER TABLE `mapreg` ENGINE=MyISAM;
SELECT '✓ mapreg reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: ipbanlist - ', NOW()) AS 'Progress';
ALTER TABLE `ipbanlist` ENGINE=MyISAM;
SELECT '✓ ipbanlist reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: db_roulette - ', NOW()) AS 'Progress';
ALTER TABLE `db_roulette` ENGINE=MyISAM;
SELECT '✓ db_roulette reverted to MyISAM' AS 'Status';

SELECT 'PHASE 10 COMPLETE' AS '';
SELECT NOW() AS 'Phase 10 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 11: ROLLBACK LOGGING TABLES (Aria to MyISAM)
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 11: ROLLBACK Logging Tables (Aria to MyISAM)' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Rolling back: atcommandlog - ', NOW()) AS 'Progress';
ALTER TABLE `atcommandlog` ENGINE=MyISAM;
SELECT '✓ atcommandlog reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: branchlog - ', NOW()) AS 'Progress';
ALTER TABLE `branchlog` ENGINE=MyISAM;
SELECT '✓ branchlog reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: cashlog - ', NOW()) AS 'Progress';
ALTER TABLE `cashlog` ENGINE=MyISAM;
SELECT '✓ cashlog reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: chatlog - ', NOW()) AS 'Progress';
ALTER TABLE `chatlog` ENGINE=MyISAM;
SELECT '✓ chatlog reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: feedinglog - ', NOW()) AS 'Progress';
ALTER TABLE `feedinglog` ENGINE=MyISAM;
SELECT '✓ feedinglog reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: loginlog - ', NOW()) AS 'Progress';
ALTER TABLE `loginlog` ENGINE=MyISAM;
SELECT '✓ loginlog reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: mvplog - ', NOW()) AS 'Progress';
ALTER TABLE `mvplog` ENGINE=MyISAM;
SELECT '✓ mvplog reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: npclog - ', NOW()) AS 'Progress';
ALTER TABLE `npclog` ENGINE=MyISAM;
SELECT '✓ npclog reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: picklog - ', NOW()) AS 'Progress';
ALTER TABLE `picklog` ENGINE=MyISAM;
SELECT '✓ picklog reverted to MyISAM' AS 'Status';

SELECT CONCAT('Rolling back: zenylog - ', NOW()) AS 'Progress';
ALTER TABLE `zenylog` ENGINE=MyISAM;
SELECT '✓ zenylog reverted to MyISAM' AS 'Status';

-- Optional tables (may not exist)
SET @table_exists = (SELECT COUNT(*) FROM information_schema.TABLES 
                     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'charlog');
SET @sql = IF(@table_exists > 0, 'ALTER TABLE `charlog` ENGINE=MyISAM', 'SELECT "charlog not found" AS Status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @table_exists = (SELECT COUNT(*) FROM information_schema.TABLES 
                     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'interlog');
SET @sql = IF(@table_exists > 0, 'ALTER TABLE `interlog` ENGINE=MyISAM', 'SELECT "interlog not found" AS Status');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT 'PHASE 11 COMPLETE' AS '';
SELECT NOW() AS 'Phase 11 Completion Time';
SELECT '' AS '';

-- Re-enable checks
SET FOREIGN_KEY_CHECKS = 1;
SET UNIQUE_CHECKS = 1;

SELECT 'Foreign key checks and unique checks re-enabled' AS 'Info';
SELECT '' AS '';

-- ============================================================================
-- POST-ROLLBACK VERIFICATION
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'POST-ROLLBACK VERIFICATION' AS '';
SELECT '============================================================================' AS '';

SELECT 'Verifying all tables reverted to MyISAM...' AS 'Status';
SELECT '' AS '';

-- Storage engine distribution AFTER rollback
SELECT 'Storage Engine Distribution (AFTER ROLLBACK):' AS '';
SELECT 
    ENGINE,
    COUNT(*) AS 'Table Count',
    ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS 'Total Size (MB)'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
GROUP BY ENGINE
ORDER BY COUNT(*) DESC;

SELECT '' AS '';

-- Check if any tables still not MyISAM
SELECT 'Tables still NOT on MyISAM (if any):' AS 'Status';
SELECT TABLE_NAME, ENGINE
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND ENGINE NOT IN ('MyISAM')
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

SELECT '' AS '';

-- Verify critical tables
SELECT 'Critical Tables Verification:' AS '';
SELECT TABLE_NAME, ENGINE, TABLE_ROWS
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('char', 'login', 'inventory', 'storage', 'guild')
ORDER BY TABLE_NAME;

SELECT '' AS '';

-- ============================================================================
-- ROLLBACK COMPLETE
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT '⚠️  ROLLBACK TO MyISAM COMPLETE ⚠️' AS '';
SELECT '============================================================================' AS '';
SELECT NOW() AS 'Rollback End Time';
SELECT '' AS '';

SELECT '╔════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║  IMPORTANT: Your database has been rolled back to MyISAM              ║' AS '';
SELECT '║                                                                        ║' AS '';
SELECT '║  You have LOST the following capabilities:                            ║' AS '';
SELECT '║  ✗ ACID transaction guarantees                                        ║' AS '';
SELECT '║  ✗ Automatic crash recovery                                           ║' AS '';
SELECT '║  ✗ Row-level locking (back to table-level)                            ║' AS '';
SELECT '║  ✗ Foreign key constraints                                            ║' AS '';
SELECT '║  ✗ Better concurrency                                                 ║' AS '';
SELECT '║                                                                        ║' AS '';
SELECT '║  Your database is now in HIGH-RISK configuration!                     ║' AS '';
SELECT '╚════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

SELECT 'CRITICAL NEXT STEPS:' AS '';
SELECT '1. Run table repair on all tables: mysqlcheck -r rathena' AS '';
SELECT '2. Restart game servers and verify functionality' AS '';
SELECT '3. Monitor error logs: tail -f /var/log/mysql/error.log' AS '';
SELECT '4. Document rollback reason for root cause analysis' AS '';
SELECT '5. Plan to re-attempt migration after fixing root cause' AS '';
SELECT '6. Implement frequent backups (MyISAM has no crash recovery!)' AS '';
SELECT '7. Monitor table corruption: CHECK TABLE on critical tables daily' AS '';
SELECT '' AS '';

SELECT 'Rollback Reason Documentation Template:' AS '';
SELECT '- Date/Time of rollback: [FILL IN]' AS '';
SELECT '- Issue that triggered rollback: [FILL IN]' AS '';
SELECT '- Error messages observed: [FILL IN]' AS '';
SELECT '- Impact on game servers: [FILL IN]' AS '';
SELECT '- Root cause identified: [FILL IN]' AS '';
SELECT '- Plan to fix and re-migrate: [FILL IN]' AS '';
SELECT '' AS '';

SELECT 'MyISAM Safety Recommendations:' AS '';
SELECT '- Enable binary logging for recovery' AS '';
SELECT '- Schedule hourly backups (no crash recovery!)' AS '';
SELECT '- Run CHECK TABLE weekly on critical tables' AS '';
SELECT '- Monitor for table corruption' AS '';
SELECT '- Plan maintenance windows for repairs' AS '';
SELECT '- Avoid server crashes at all costs' AS '';
SELECT '- Consider UPS/redundant power' AS '';
SELECT '' AS '';

SELECT '============================================================================' AS '';
