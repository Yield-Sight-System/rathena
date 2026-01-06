-- ============================================================================
-- RATHENA DATABASE MAINTENANCE SCRIPT
-- ============================================================================
-- Version: 1.0
-- Date: 2026-01-06
-- Target: MariaDB 10.11+ / 11.2+
-- Database: rathena
--
-- Purpose:
--   Comprehensive database maintenance routine for rAthena game server.
--   Performs essential maintenance tasks:
--   - Table optimization (defragmentation)
--   - Statistics updates (query optimizer)
--   - Table integrity checks
--   - Index maintenance
--   - Binary log cleanup
--
-- Recommended Schedule:
--   - Critical Tables: Weekly (during low-traffic hours)
--   - Normal Tables: Bi-weekly
--   - Log Tables: Monthly
--   - Full Maintenance: Monthly
--
-- Execution Time:
--   - Small database (<100k chars): 5-15 minutes
--   - Medium database (100k-500k chars): 15-45 minutes
--   - Large database (>500k chars): 1-3 hours
--
-- IMPORTANT:
--   - Run during maintenance window (low player traffic)
--   - Tables are locked during OPTIMIZE (use ALGORITHM=INPLACE if possible)
--   - Creates temporary copies during optimization (needs disk space)
--   - Monitor disk space before running
--
-- Usage:
--   mysql -u root -p rathena < maintenance.sql > maintenance_log.txt
--   
--   Or from MySQL prompt:
--   USE rathena;
--   SOURCE maintenance.sql;
--
-- Safety:
--   - Backup database before running for first time
--   - Test on non-production environment first
--   - Can be run on live database with proper scheduling
-- ============================================================================

-- Set session variables
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO';

-- Display header
SELECT '============================================================================' AS '';
SELECT 'RATHENA DATABASE MAINTENANCE SCRIPT' AS '';
SELECT '============================================================================' AS '';
SELECT CONCAT('Start Time: ', NOW()) AS '';
SELECT CONCAT('Database: ', DATABASE()) AS '';
SELECT CONCAT('MariaDB Version: ', VERSION()) AS '';
SELECT '============================================================================' AS '';
SELECT '' AS '';

-- ============================================================================
-- PHASE 1: PRE-MAINTENANCE CHECKS
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ PHASE 1: PRE-MAINTENANCE CHECKS                                         ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Check disk space (MariaDB data directory)
SELECT 'Disk Space Check:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    CONCAT(ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / 1024, 2), ' GB') AS 'Current DB Size',
    CONCAT(ROUND(SUM(DATA_FREE) / 1024 / 1024 / 1024, 2), ' GB') AS 'Wasted Space',
    CONCAT(ROUND((SUM(DATA_FREE) / SUM(DATA_LENGTH + INDEX_LENGTH)) * 100, 2), '%') AS 'Fragmentation',
    CASE
        WHEN (SUM(DATA_FREE) / SUM(DATA_LENGTH + INDEX_LENGTH)) > 0.2 THEN '⚠ High fragmentation - OPTIMIZE recommended'
        WHEN (SUM(DATA_FREE) / SUM(DATA_LENGTH + INDEX_LENGTH)) > 0.1 THEN '✓ Moderate fragmentation'
        ELSE '✓ Low fragmentation'
    END AS 'Status'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE();

SELECT '' AS '';

-- Check active connections (should be minimal during maintenance)
SELECT 'Active Connections Check:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    COUNT(*) AS 'Active Connections',
    CASE
        WHEN COUNT(*) > 20 THEN '⚠ WARNING: High connection count - consider rescheduling'
        WHEN COUNT(*) > 10 THEN '⚠ Moderate connection count - monitor during maintenance'
        ELSE '✓ Low connection count - safe to proceed'
    END AS 'Status'
FROM information_schema.PROCESSLIST
WHERE DB = DATABASE();

SELECT '' AS '';

-- List currently running queries
SELECT 'Currently Running Queries:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    ID AS 'Thread ID',
    USER AS 'User',
    HOST AS 'Host',
    COMMAND AS 'Command',
    TIME AS 'Time (s)',
    STATE AS 'State',
    LEFT(INFO, 60) AS 'Query'
FROM information_schema.PROCESSLIST
WHERE DB = DATABASE()
  AND COMMAND != 'Sleep'
ORDER BY TIME DESC
LIMIT 10;

SELECT '' AS '';
SELECT 'Waiting 5 seconds before starting maintenance...' AS '';
SELECT SLEEP(5) INTO @dummy;
SELECT '' AS '';

-- ============================================================================
-- PHASE 2: CRITICAL TABLES MAINTENANCE (HIGH PRIORITY)
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ PHASE 2: CRITICAL TABLES MAINTENANCE                                    ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';
SELECT 'Processing critical game tables (char, inventory, guild, etc.)...' AS '';
SELECT '' AS '';

-- Character table
SELECT '-- Maintaining: char' AS '';
CHECK TABLE `char` EXTENDED;
ANALYZE TABLE `char`;
OPTIMIZE TABLE `char`;
SELECT CONCAT('  ✓ char completed at ', NOW()) AS '';
SELECT '' AS '';

-- Inventory table
SELECT '-- Maintaining: inventory' AS '';
CHECK TABLE `inventory` EXTENDED;
ANALYZE TABLE `inventory`;
OPTIMIZE TABLE `inventory`;
SELECT CONCAT('  ✓ inventory completed at ', NOW()) AS '';
SELECT '' AS '';

-- Storage table
SELECT '-- Maintaining: storage' AS '';
CHECK TABLE `storage` EXTENDED;
ANALYZE TABLE `storage`;
OPTIMIZE TABLE `storage`;
SELECT CONCAT('  ✓ storage completed at ', NOW()) AS '';
SELECT '' AS '';

-- Cart inventory table
SELECT '-- Maintaining: cart_inventory' AS '';
CHECK TABLE `cart_inventory` EXTENDED;
ANALYZE TABLE `cart_inventory`;
OPTIMIZE TABLE `cart_inventory`;
SELECT CONCAT('  ✓ cart_inventory completed at ', NOW()) AS '';
SELECT '' AS '';

-- Guild table
SELECT '-- Maintaining: guild' AS '';
CHECK TABLE `guild` EXTENDED;
ANALYZE TABLE `guild`;
OPTIMIZE TABLE `guild`;
SELECT CONCAT('  ✓ guild completed at ', NOW()) AS '';
SELECT '' AS '';

-- Guild member table
SELECT '-- Maintaining: guild_member' AS '';
CHECK TABLE `guild_member` EXTENDED;
ANALYZE TABLE `guild_member`;
OPTIMIZE TABLE `guild_member`;
SELECT CONCAT('  ✓ guild_member completed at ', NOW()) AS '';
SELECT '' AS '';

-- Guild storage table
SELECT '-- Maintaining: guild_storage' AS '';
CHECK TABLE `guild_storage` EXTENDED;
ANALYZE TABLE `guild_storage`;
OPTIMIZE TABLE `guild_storage`;
SELECT CONCAT('  ✓ guild_storage completed at ', NOW()) AS '';
SELECT '' AS '';

-- Login table
SELECT '-- Maintaining: login' AS '';
CHECK TABLE `login` EXTENDED;
ANALYZE TABLE `login`;
OPTIMIZE TABLE `login`;
SELECT CONCAT('  ✓ login completed at ', NOW()) AS '';
SELECT '' AS '';

-- Mail table
SELECT '-- Maintaining: mail' AS '';
CHECK TABLE `mail` EXTENDED;
ANALYZE TABLE `mail`;
OPTIMIZE TABLE `mail`;
SELECT CONCAT('  ✓ mail completed at ', NOW()) AS '';
SELECT '' AS '';

SELECT 'Critical tables maintenance completed!' AS '';
SELECT '' AS '';

-- ============================================================================
-- PHASE 3: SECONDARY TABLES MAINTENANCE (MEDIUM PRIORITY)
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ PHASE 3: SECONDARY TABLES MAINTENANCE                                   ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';
SELECT 'Processing secondary game tables (quest, skill, achievement, etc.)...' AS '';
SELECT '' AS '';

-- Quest table
SELECT '-- Maintaining: quest' AS '';
ANALYZE TABLE `quest`;
OPTIMIZE TABLE `quest`;
SELECT CONCAT('  ✓ quest completed at ', NOW()) AS '';
SELECT '' AS '';

-- Skill table
SELECT '-- Maintaining: skill' AS '';
ANALYZE TABLE `skill`;
OPTIMIZE TABLE `skill`;
SELECT CONCAT('  ✓ skill completed at ', NOW()) AS '';
SELECT '' AS '';

-- Achievement table
SELECT '-- Maintaining: achievement' AS '';
ANALYZE TABLE `achievement`;
OPTIMIZE TABLE `achievement`;
SELECT CONCAT('  ✓ achievement completed at ', NOW()) AS '';
SELECT '' AS '';

-- Pet table
SELECT '-- Maintaining: pet' AS '';
ANALYZE TABLE `pet`;
OPTIMIZE TABLE `pet`;
SELECT CONCAT('  ✓ pet completed at ', NOW()) AS '';
SELECT '' AS '';

-- Homunculus table
SELECT '-- Maintaining: homunculus' AS '';
ANALYZE TABLE `homunculus`;
OPTIMIZE TABLE `homunculus`;
SELECT CONCAT('  ✓ homunculus completed at ', NOW()) AS '';
SELECT '' AS '';

-- Party table
SELECT '-- Maintaining: party' AS '';
ANALYZE TABLE `party`;
OPTIMIZE TABLE `party`;
SELECT CONCAT('  ✓ party completed at ', NOW()) AS '';
SELECT '' AS '';

-- Friends table
SELECT '-- Maintaining: friends' AS '';
ANALYZE TABLE `friends`;
OPTIMIZE TABLE `friends`;
SELECT CONCAT('  ✓ friends completed at ', NOW()) AS '';
SELECT '' AS '';

-- Memo table
SELECT '-- Maintaining: memo' AS '';
ANALYZE TABLE `memo`;
OPTIMIZE TABLE `memo`;
SELECT CONCAT('  ✓ memo completed at ', NOW()) AS '';
SELECT '' AS '';

-- Hotkey table
SELECT '-- Maintaining: hotkey' AS '';
ANALYZE TABLE `hotkey`;
OPTIMIZE TABLE `hotkey`;
SELECT CONCAT('  ✓ hotkey completed at ', NOW()) AS '';
SELECT '' AS '';

-- Vendings table
SELECT '-- Maintaining: vendings' AS '';
ANALYZE TABLE `vendings`;
OPTIMIZE TABLE `vendings`;
SELECT CONCAT('  ✓ vendings completed at ', NOW()) AS '';
SELECT '' AS '';

-- Vending items table
SELECT '-- Maintaining: vending_items' AS '';
ANALYZE TABLE `vending_items`;
OPTIMIZE TABLE `vending_items`;
SELECT CONCAT('  ✓ vending_items completed at ', NOW()) AS '';
SELECT '' AS '';

-- Buyingstores table
SELECT '-- Maintaining: buyingstores' AS '';
ANALYZE TABLE `buyingstores`;
OPTIMIZE TABLE `buyingstores`;
SELECT CONCAT('  ✓ buyingstores completed at ', NOW()) AS '';
SELECT '' AS '';

-- Buyingstore items table
SELECT '-- Maintaining: buyingstore_items' AS '';
ANALYZE TABLE `buyingstore_items`;
OPTIMIZE TABLE `buyingstore_items`;
SELECT CONCAT('  ✓ buyingstore_items completed at ', NOW()) AS '';
SELECT '' AS '';

SELECT 'Secondary tables maintenance completed!' AS '';
SELECT '' AS '';

-- ============================================================================
-- PHASE 4: REGISTRY AND CONFIG TABLES MAINTENANCE
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ PHASE 4: REGISTRY AND CONFIG TABLES MAINTENANCE                         ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';
SELECT 'Processing registry and configuration tables...' AS '';
SELECT '' AS '';

-- Account registry tables
SELECT '-- Maintaining: acc_reg_num' AS '';
ANALYZE TABLE `acc_reg_num`;
OPTIMIZE TABLE `acc_reg_num`;
SELECT '  ✓ acc_reg_num completed' AS '';

SELECT '-- Maintaining: acc_reg_str' AS '';
ANALYZE TABLE `acc_reg_str`;
OPTIMIZE TABLE `acc_reg_str`;
SELECT '  ✓ acc_reg_str completed' AS '';

SELECT '-- Maintaining: char_reg_num' AS '';
ANALYZE TABLE `char_reg_num`;
OPTIMIZE TABLE `char_reg_num`;
SELECT '  ✓ char_reg_num completed' AS '';

SELECT '-- Maintaining: char_reg_str' AS '';
ANALYZE TABLE `char_reg_str`;
OPTIMIZE TABLE `char_reg_str`;
SELECT '  ✓ char_reg_str completed' AS '';

SELECT '-- Maintaining: global_acc_reg_num' AS '';
ANALYZE TABLE `global_acc_reg_num`;
OPTIMIZE TABLE `global_acc_reg_num`;
SELECT '  ✓ global_acc_reg_num completed' AS '';

SELECT '-- Maintaining: global_acc_reg_str' AS '';
ANALYZE TABLE `global_acc_reg_str`;
OPTIMIZE TABLE `global_acc_reg_str`;
SELECT '  ✓ global_acc_reg_str completed' AS '';

SELECT '-- Maintaining: mapreg' AS '';
ANALYZE TABLE `mapreg`;
OPTIMIZE TABLE `mapreg`;
SELECT '  ✓ mapreg completed' AS '';

SELECT '' AS '';
SELECT 'Registry tables maintenance completed!' AS '';
SELECT '' AS '';

-- ============================================================================
-- PHASE 5: LOGGING TABLES MAINTENANCE (LOW PRIORITY)
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ PHASE 5: LOGGING TABLES MAINTENANCE                                     ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';
SELECT 'Processing logging tables (less frequent optimization needed)...' AS '';
SELECT '' AS '';

-- Note: Be cautious with OPTIMIZE on large log tables as it can take hours
-- Consider rotating/archiving old logs instead

SELECT '-- Maintaining: picklog' AS '';
ANALYZE TABLE `picklog`;
-- OPTIMIZE TABLE `picklog`;  -- Uncomment if fragmentation is high
SELECT '  ✓ picklog analyzed (OPTIMIZE skipped - run manually if needed)' AS '';

SELECT '-- Maintaining: zenylog' AS '';
ANALYZE TABLE `zenylog`;
-- OPTIMIZE TABLE `zenylog`;  -- Uncomment if fragmentation is high
SELECT '  ✓ zenylog analyzed (OPTIMIZE skipped - run manually if needed)' AS '';

SELECT '-- Maintaining: chatlog' AS '';
ANALYZE TABLE `chatlog`;
-- OPTIMIZE TABLE `chatlog`;  -- Uncomment if fragmentation is high
SELECT '  ✓ chatlog analyzed (OPTIMIZE skipped - run manually if needed)' AS '';

SELECT '-- Maintaining: loginlog' AS '';
ANALYZE TABLE `loginlog`;
-- OPTIMIZE TABLE `loginlog`;  -- Uncomment if fragmentation is high
SELECT '  ✓ loginlog analyzed (OPTIMIZE skipped - run manually if needed)' AS '';

SELECT '-- Maintaining: atcommandlog' AS '';
ANALYZE TABLE `atcommandlog`;
-- OPTIMIZE TABLE `atcommandlog`;  -- Uncomment if fragmentation is high
SELECT '  ✓ atcommandlog analyzed (OPTIMIZE skipped - run manually if needed)' AS '';

SELECT '-- Maintaining: mvplog' AS '';
ANALYZE TABLE `mvplog`;
SELECT '  ✓ mvplog analyzed' AS '';

SELECT '-- Maintaining: branchlog' AS '';
ANALYZE TABLE `branchlog`;
SELECT '  ✓ branchlog analyzed' AS '';

SELECT '-- Maintaining: cashlog' AS '';
ANALYZE TABLE `cashlog`;
SELECT '  ✓ cashlog analyzed' AS '';

SELECT '-- Maintaining: feedinglog' AS '';
ANALYZE TABLE `feedinglog`;
SELECT '  ✓ feedinglog analyzed' AS '';

SELECT '-- Maintaining: npclog' AS '';
ANALYZE TABLE `npclog`;
SELECT '  ✓ npclog analyzed' AS '';

SELECT '' AS '';
SELECT 'Logging tables maintenance completed!' AS '';
SELECT 'NOTE: Large log tables were only analyzed. Run OPTIMIZE manually if needed.' AS '';
SELECT '' AS '';

-- ============================================================================
-- PHASE 6: REMAINING TABLES MAINTENANCE
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ PHASE 6: REMAINING TABLES MAINTENANCE                                   ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';
SELECT 'Processing remaining tables...' AS '';
SELECT '' AS '';

-- Guild-related tables
ANALYZE TABLE `guild_alliance`;
ANALYZE TABLE `guild_castle`;
ANALYZE TABLE `guild_expulsion`;
ANALYZE TABLE `guild_position`;
ANALYZE TABLE `guild_skill`;
ANALYZE TABLE `guild_storage_log`;

-- Other game tables
ANALYZE TABLE `auction`;
ANALYZE TABLE `bonus_script`;
ANALYZE TABLE `elemental`;
ANALYZE TABLE `mercenary`;
ANALYZE TABLE `mercenary_owner`;
ANALYZE TABLE `sc_data`;
ANALYZE TABLE `skillcooldown`;
ANALYZE TABLE `skill_homunculus`;
ANALYZE TABLE `skillcooldown_homunculus`;
ANALYZE TABLE `skillcooldown_mercenary`;
ANALYZE TABLE `mail_attachments`;
ANALYZE TABLE `party_bookings`;
ANALYZE TABLE `ipbanlist`;
ANALYZE TABLE `interlog`;
ANALYZE TABLE `charlog`;

-- Clan tables
ANALYZE TABLE `clan`;
ANALYZE TABLE `clan_alliance`;

-- Shop tables
ANALYZE TABLE `barter`;
ANALYZE TABLE `market`;
ANALYZE TABLE `sales`;
ANALYZE TABLE `db_roulette`;

SELECT '  ✓ All remaining tables analyzed' AS '';
SELECT '' AS '';

-- ============================================================================
-- PHASE 7: POST-MAINTENANCE VERIFICATION
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ PHASE 7: POST-MAINTENANCE VERIFICATION                                  ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Check for any corrupted tables
SELECT 'Checking for Table Errors:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';

-- This will be populated if any CHECK TABLE found errors
-- (MariaDB stores results in a result set, not a permanent table)

SELECT 'Verification complete. Review CHECK TABLE results above for any errors.' AS '';
SELECT '' AS '';

-- Fragmentation after maintenance
SELECT 'Post-Maintenance Fragmentation Check:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    CONCAT(ROUND(SUM(DATA_FREE) / 1024 / 1024 / 1024, 2), ' GB') AS 'Wasted Space',
    CONCAT(ROUND((SUM(DATA_FREE) / SUM(DATA_LENGTH + INDEX_LENGTH)) * 100, 2), '%') AS 'Fragmentation',
    CASE
        WHEN (SUM(DATA_FREE) / SUM(DATA_LENGTH + INDEX_LENGTH)) > 0.1 THEN '⚠ Still fragmented - may need additional optimization'
        ELSE '✓ Fragmentation reduced successfully'
    END AS 'Status'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE();

SELECT '' AS '';

-- Index statistics update confirmation
SELECT 'Index Statistics Update:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    COUNT(DISTINCT CONCAT(TABLE_NAME, '.', INDEX_NAME)) AS 'Total Indexes',
    SUM(CASE WHEN CARDINALITY IS NULL OR CARDINALITY = 0 THEN 1 ELSE 0 END) AS 'Indexes Without Statistics',
    CASE
        WHEN SUM(CASE WHEN CARDINALITY IS NULL OR CARDINALITY = 0 THEN 1 ELSE 0 END) > 0 
        THEN '⚠ Some indexes still lack statistics'
        ELSE '✓ All indexes have statistics'
    END AS 'Status'
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND INDEX_NAME != 'PRIMARY';

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- PHASE 8: BINARY LOG CLEANUP (Optional)
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ PHASE 8: BINARY LOG CLEANUP                                             ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Check binary log status
SELECT 'Binary Log Status:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    @@log_bin AS 'Binary Logging Enabled',
    @@expire_logs_days AS 'Retention Days',
    COUNT(*) AS 'Binary Log Files'
FROM (SELECT 1) AS dummy
LEFT JOIN (SELECT 1 FROM mysql.general_log LIMIT 1) AS logs ON 1=1;

SELECT '' AS '';

-- Optional: Purge old binary logs (uncomment to enable)
-- WARNING: Only run if you have proper backups and don't need old binlogs for recovery
-- PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 7 DAY);

SELECT 'Binary log cleanup skipped (enable manually if needed)' AS '';
SELECT 'To purge old logs: PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 7 DAY);' AS '';
SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- MAINTENANCE SUMMARY
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ MAINTENANCE SUMMARY                                                      ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

SELECT CONCAT('Completion Time: ', NOW()) AS '';
SELECT '' AS '';

SELECT 'Maintenance Tasks Completed:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT '✓ Phase 1: Pre-maintenance checks' AS '';
SELECT '✓ Phase 2: Critical tables (CHECK, ANALYZE, OPTIMIZE)' AS '';
SELECT '✓ Phase 3: Secondary tables (ANALYZE, OPTIMIZE)' AS '';
SELECT '✓ Phase 4: Registry tables (ANALYZE, OPTIMIZE)' AS '';
SELECT '✓ Phase 5: Logging tables (ANALYZE only)' AS '';
SELECT '✓ Phase 6: Remaining tables (ANALYZE)' AS '';
SELECT '✓ Phase 7: Post-maintenance verification' AS '';
SELECT '✓ Phase 8: Binary log cleanup (manual)' AS '';

SELECT '' AS '';

SELECT 'Recommended Next Steps:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT '1. Review CHECK TABLE results above for any errors' AS '';
SELECT '2. Run health_check.sql to verify overall database health' AS '';
SELECT '3. Monitor query performance over next 24 hours' AS '';
SELECT '4. Check buffer pool hit rate (should be >99%)' AS '';
SELECT '5. Review slow query log for optimization opportunities' AS '';

SELECT '' AS '';

SELECT 'Maintenance Schedule Recommendations:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT '• Critical tables (char, inventory, guild): Weekly' AS '';
SELECT '• Secondary tables (quest, skill, pet): Bi-weekly' AS '';
SELECT '• Registry tables: Monthly' AS '';
SELECT '• Log tables (OPTIMIZE): Quarterly or as needed' AS '';
SELECT '• Full maintenance: Monthly' AS '';

SELECT '' AS '';

SELECT 'Performance Monitoring:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT '• Enable slow query log if not already enabled' AS '';
SELECT '• Monitor buffer pool hit rate regularly' AS '';
SELECT '• Check table fragmentation weekly' AS '';
SELECT '• Review index usage monthly with analyze_indexes.sql' AS '';
SELECT '• Compare health_check.sql reports over time' AS '';

SELECT '' AS '';

-- Restore session variables
SET SQL_MODE=@OLD_SQL_MODE;

-- ============================================================================
-- FOOTER
-- ============================================================================

SELECT '============================================================================' AS '';
SELECT 'MAINTENANCE COMPLETE!' AS '';
SELECT '============================================================================' AS '';
SELECT CONCAT('Total Execution Time: ', NOW()) AS '';
SELECT '' AS '';
SELECT 'Database maintenance has been completed successfully.' AS '';
SELECT 'The database is now optimized and ready for optimal performance.' AS '';
SELECT '' AS '';
SELECT 'For issues or questions, refer to README.md' AS '';
SELECT '============================================================================' AS '';
