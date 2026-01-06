-- ============================================================================
-- PHASE B2: MyISAM to Aria Migration Script (Logging Tables)
-- ============================================================================
-- Purpose: Convert logging tables from MyISAM to Aria (crash-safe alternative)
-- Target: MariaDB 10.11+ LTS or 11.2+ Stable
-- Risk Level: LOW (logging tables, no critical game data)
-- Duration: 5-15 minutes (depends on log table sizes)
--
-- Why Aria for Logs?
-- ✓ Crash-safe (better than MyISAM)
-- ✓ Lower overhead than InnoDB
-- ✓ Good insert performance
-- ✓ Table-level locks acceptable (append-only workload)
-- ✓ Smaller memory footprint
--
-- PREREQUISITES:
-- 1. Phase B1 (InnoDB migration) should be completed
-- 2. Game servers can remain online (low risk)
-- 3. Backup recommended but not critical
--
-- Usage:
--   mysql -u root -p rathena < migrate_to_aria.sql > migration_aria.log 2>&1
--   Review log for any errors
-- ============================================================================

SELECT '============================================================================' AS '';
SELECT 'PHASE B2: Aria Migration Starting (Logging Tables)' AS '';
SELECT '============================================================================' AS '';
SELECT NOW() AS 'Migration Start Time';
SELECT DATABASE() AS 'Target Database';
SELECT USER() AS 'Executing User';
SELECT VERSION() AS 'MariaDB Version';
SELECT '' AS '';

-- Check Aria engine availability
SELECT 'Checking Aria engine availability...' AS 'Status';
SELECT ENGINE, SUPPORT, COMMENT
FROM information_schema.ENGINES
WHERE ENGINE = 'Aria';

SELECT CASE
    WHEN (SELECT COUNT(*) FROM information_schema.ENGINES 
          WHERE ENGINE = 'Aria' AND SUPPORT IN ('YES', 'DEFAULT')) = 1
    THEN '✓ Aria engine available - proceeding with migration'
    ELSE '✗ WARNING: Aria engine not available - tables will remain MyISAM'
END AS 'Aria Check';

SELECT '' AS '';

-- ============================================================================
-- PHASE 1: Game Command and Action Logs
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 1: Game Command and Action Logs' AS '';
SELECT '============================================================================' AS '';

-- GM Command log
SELECT CONCAT('Converting: atcommandlog - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'atcommandlog';

ALTER TABLE `atcommandlog` ENGINE=Aria TRANSACTIONAL=1;
SELECT '✓ atcommandlog converted to Aria (crash-safe)' AS 'Status';
SELECT '' AS '';

-- Branch log (Dead Branch, Bloody Branch usage)
SELECT CONCAT('Converting: branchlog - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'branchlog';

ALTER TABLE `branchlog` ENGINE=Aria TRANSACTIONAL=1;
SELECT '✓ branchlog converted to Aria' AS 'Status';
SELECT '' AS '';

-- NPC interaction log
SELECT CONCAT('Converting: npclog - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'npclog';

ALTER TABLE `npclog` ENGINE=Aria TRANSACTIONAL=1;
SELECT '✓ npclog converted to Aria' AS 'Status';
SELECT '' AS '';

-- MVP kill log
SELECT CONCAT('Converting: mvplog - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'mvplog';

ALTER TABLE `mvplog` ENGINE=Aria TRANSACTIONAL=1;
SELECT '✓ mvplog converted to Aria' AS 'Status';
SELECT '' AS '';

SELECT 'PHASE 1 COMPLETE: Game Command and Action Logs' AS '';
SELECT NOW() AS 'Phase 1 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 2: Communication Logs
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 2: Communication Logs' AS '';
SELECT '============================================================================' AS '';

-- Chat log (often the largest log table)
SELECT CONCAT('Converting: chatlog - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chatlog';

ALTER TABLE `chatlog` ENGINE=Aria TRANSACTIONAL=1;
SELECT '✓ chatlog converted to Aria (may take longer if large)' AS 'Status';
SELECT '' AS '';

SELECT 'PHASE 2 COMPLETE: Communication Logs' AS '';
SELECT NOW() AS 'Phase 2 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 3: Economy and Item Logs
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 3: Economy and Item Logs' AS '';
SELECT '============================================================================' AS '';

-- Cash shop transaction log
SELECT CONCAT('Converting: cashlog - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cashlog';

ALTER TABLE `cashlog` ENGINE=Aria TRANSACTIONAL=1;
SELECT '✓ cashlog converted to Aria' AS 'Status';
SELECT '' AS '';

-- Item pickup/drop log
SELECT CONCAT('Converting: picklog - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'picklog';

ALTER TABLE `picklog` ENGINE=Aria TRANSACTIONAL=1;
SELECT '✓ picklog converted to Aria' AS 'Status';
SELECT '' AS '';

-- Zeny transaction log
SELECT CONCAT('Converting: zenylog - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'zenylog';

ALTER TABLE `zenylog` ENGINE=Aria TRANSACTIONAL=1;
SELECT '✓ zenylog converted to Aria' AS 'Status';
SELECT '' AS '';

SELECT 'PHASE 3 COMPLETE: Economy and Item Logs' AS '';
SELECT NOW() AS 'Phase 3 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 4: Pet/Companion Logs
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 4: Pet/Companion Logs' AS '';
SELECT '============================================================================' AS '';

-- Pet/Homunculus feeding log
SELECT CONCAT('Converting: feedinglog - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'feedinglog';

ALTER TABLE `feedinglog` ENGINE=Aria TRANSACTIONAL=1;
SELECT '✓ feedinglog converted to Aria' AS 'Status';
SELECT '' AS '';

SELECT 'PHASE 4 COMPLETE: Pet/Companion Logs' AS '';
SELECT NOW() AS 'Phase 4 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 5: Authentication and System Logs
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 5: Authentication and System Logs' AS '';
SELECT '============================================================================' AS '';

-- Login attempt log
SELECT CONCAT('Converting: loginlog - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'loginlog';

ALTER TABLE `loginlog` ENGINE=Aria TRANSACTIONAL=1;
SELECT '✓ loginlog converted to Aria' AS 'Status';
SELECT '' AS '';

-- Character server log (if exists)
SELECT CONCAT('Converting: charlog (if exists) - ', NOW()) AS 'Progress';

-- Check if table exists before converting
SET @table_exists = (SELECT COUNT(*) FROM information_schema.TABLES 
                     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'charlog');

SET @sql = IF(@table_exists > 0,
    'ALTER TABLE `charlog` ENGINE=Aria TRANSACTIONAL=1',
    'SELECT "Table charlog does not exist - skipping" AS Status');

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT IF(@table_exists > 0, '✓ charlog converted to Aria', '⊗ charlog table not found - skipped') AS 'Status';
SELECT '' AS '';

-- Inter-server log (if exists)
SELECT CONCAT('Converting: interlog (if exists) - ', NOW()) AS 'Progress';

SET @table_exists = (SELECT COUNT(*) FROM information_schema.TABLES 
                     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'interlog');

SET @sql = IF(@table_exists > 0,
    'ALTER TABLE `interlog` ENGINE=Aria TRANSACTIONAL=1',
    'SELECT "Table interlog does not exist - skipping" AS Status');

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT IF(@table_exists > 0, '✓ interlog converted to Aria', '⊗ interlog table not found - skipped') AS 'Status';
SELECT '' AS '';

SELECT 'PHASE 5 COMPLETE: Authentication and System Logs' AS '';
SELECT NOW() AS 'Phase 5 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- POST-MIGRATION VERIFICATION
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'POST-MIGRATION VERIFICATION' AS '';
SELECT '============================================================================' AS '';

SELECT 'Verifying Aria conversions...' AS 'Status';
SELECT '' AS '';

-- List all Aria tables
SELECT 
    TABLE_NAME,
    ENGINE,
    TABLE_ROWS,
    ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2) AS 'Size_MB',
    CREATE_TIME,
    UPDATE_TIME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND ENGINE = 'Aria'
ORDER BY TABLE_NAME;

SELECT '' AS '';

-- Count conversions
SELECT 
    COUNT(*) AS 'Total Log Tables Converted to Aria',
    SUM(TABLE_ROWS) AS 'Total Rows',
    ROUND(SUM(DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2) AS 'Total Size MB'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND ENGINE = 'Aria'
  AND TABLE_NAME IN (
    'atcommandlog', 'branchlog', 'cashlog', 'chatlog',
    'feedinglog', 'loginlog', 'mvplog', 'npclog',
    'picklog', 'zenylog', 'charlog', 'interlog'
  );

SELECT '' AS '';

-- Check for any that remained MyISAM
SELECT 'Checking for any log tables still on MyISAM...' AS 'Status';
SELECT TABLE_NAME, ENGINE, 
       ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2) AS 'Size_MB'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND ENGINE = 'MyISAM'
  AND TABLE_NAME LIKE '%log%'
ORDER BY TABLE_NAME;

SELECT '' AS '';

-- Summary of all storage engines
SELECT 'Current Storage Engine Distribution:' AS '';
SELECT 
    ENGINE,
    COUNT(*) AS 'Table Count',
    ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS 'Total Size (MB)'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
GROUP BY ENGINE
ORDER BY COUNT(*) DESC;

SELECT '' AS '';

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'ARIA MIGRATION COMPLETE!' AS '';
SELECT '============================================================================' AS '';
SELECT NOW() AS 'Migration End Time';
SELECT '' AS '';

SELECT 'Migration Benefits:' AS '';
SELECT '✓ Logging tables now have crash recovery' AS '';
SELECT '✓ Lower memory overhead than InnoDB' AS '';
SELECT '✓ Good insert performance maintained' AS '';
SELECT '✓ Automatic recovery after crashes' AS '';
SELECT '' AS '';

SELECT 'NEXT STEPS:' AS '';
SELECT '1. Verify log writes are working correctly' AS '';
SELECT '2. Monitor Aria performance with: SHOW ENGINE ARIA STATUS' AS '';
SELECT '3. Game servers can continue running (no restart needed)' AS '';
SELECT '4. Proceed with verify_migration.sql for full system check' AS '';
SELECT '5. Consider setting up log rotation/archival for large logs' AS '';
SELECT '' AS '';

SELECT 'Log Maintenance Recommendations:' AS '';
SELECT '- Partition large log tables by date for easier management' AS '';
SELECT '- Archive logs older than 6-12 months to separate tables' AS '';
SELECT '- Set up automated log cleanup procedures' AS '';
SELECT '- Monitor log table growth rates' AS '';
SELECT '' AS '';

SELECT 'Aria Configuration (optional tuning in my.cnf):' AS '';
SELECT '  aria_pagecache_buffer_size = 256M  # Cache for Aria tables' AS '';
SELECT '  aria_log_file_size = 1G  # Transaction log size' AS '';
SELECT '  aria_log_purge_type = immediate  # Purge logs immediately' AS '';
SELECT '' AS '';

SELECT '============================================================================' AS '';
