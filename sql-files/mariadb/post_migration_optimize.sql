-- ============================================================================
-- PHASE B POST-MIGRATION OPTIMIZATION
-- ============================================================================
-- Purpose: Optimize InnoDB configuration and tables after migration
-- Target: MariaDB 10.11+ LTS or 11.2+ Stable
-- Risk Level: LOW (optimization only, no data changes)
-- Duration: 15-60 minutes (depends on database size)
--
-- This script performs:
-- ✓ Table statistics update (ANALYZE TABLE)
-- ✓ Table defragmentation (OPTIMIZE TABLE)
-- ✓ Index rebuild and optimization
-- ✓ InnoDB tablespace optimization
-- ✓ Configuration recommendations
-- ✓ Performance monitoring setup
--
-- PREREQUISITES:
-- 1. verify_migration.sql completed successfully
-- 2. All tables migrated to InnoDB/Aria
-- 3. Game servers can remain running (but low traffic recommended)
-- 4. At least 20% free disk space
--
-- Usage:
--   mysql -u root -p rathena < post_migration_optimize.sql > optimization.log 2>&1
--   Review log for recommendations
-- ============================================================================

SELECT '============================================================================' AS '';
SELECT 'PHASE B POST-MIGRATION OPTIMIZATION' AS '';
SELECT '============================================================================' AS '';
SELECT NOW() AS 'Optimization Start Time';
SELECT DATABASE() AS 'Database';
SELECT USER() AS 'User';
SELECT VERSION() AS 'MariaDB Version';
SELECT '' AS '';

SELECT 'This optimization process will:' AS '';
SELECT '- Update table statistics for query optimizer' AS '';
SELECT '- Rebuild indexes for better performance' AS '';
SELECT '- Defragment tables to reclaim space' AS '';
SELECT '- Provide configuration recommendations' AS '';
SELECT '' AS '';

SELECT 'Estimated time: 15-60 minutes depending on database size' AS '';
SELECT 'Progress will be shown for each table' AS '';
SELECT '' AS '';

-- ============================================================================
-- PHASE 1: ANALYZE TABLE (Update Statistics)
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 1: ANALYZE TABLE - Update Query Optimizer Statistics' AS '';
SELECT 'This helps MariaDB choose optimal query execution plans' AS '';
SELECT '============================================================================' AS '';

-- Critical tables first
SELECT CONCAT('Analyzing: char - ', NOW()) AS 'Progress';
ANALYZE TABLE `char`;
SELECT '' AS '';

SELECT CONCAT('Analyzing: login - ', NOW()) AS 'Progress';
ANALYZE TABLE `login`;
SELECT '' AS '';

SELECT CONCAT('Analyzing: inventory - ', NOW()) AS 'Progress';
ANALYZE TABLE `inventory`;
SELECT '' AS '';

SELECT CONCAT('Analyzing: storage - ', NOW()) AS 'Progress';
ANALYZE TABLE `storage`;
SELECT '' AS '';

SELECT CONCAT('Analyzing: guild - ', NOW()) AS 'Progress';
ANALYZE TABLE `guild`;
SELECT '' AS '';

SELECT CONCAT('Analyzing: guild_storage - ', NOW()) AS 'Progress';
ANALYZE TABLE `guild_storage`;
SELECT '' AS '';

SELECT CONCAT('Analyzing: guild_member - ', NOW()) AS 'Progress';
ANALYZE TABLE `guild_member`;
SELECT '' AS '';

SELECT CONCAT('Analyzing: party - ', NOW()) AS 'Progress';
ANALYZE TABLE `party`;
SELECT '' AS '';

SELECT CONCAT('Analyzing: mail - ', NOW()) AS 'Progress';
ANALYZE TABLE `mail`;
SELECT '' AS '';

-- Secondary tables
SELECT 'Analyzing secondary tables...' AS 'Progress';
ANALYZE TABLE `cart_inventory`;
ANALYZE TABLE `char_reg_num`;
ANALYZE TABLE `char_reg_str`;
ANALYZE TABLE `acc_reg_num`;
ANALYZE TABLE `acc_reg_str`;
ANALYZE TABLE `global_acc_reg_num`;
ANALYZE TABLE `global_acc_reg_str`;
ANALYZE TABLE `guild_position`;
ANALYZE TABLE `guild_alliance`;
ANALYZE TABLE `guild_castle`;
ANALYZE TABLE `guild_skill`;
ANALYZE TABLE `guild_expulsion`;
ANALYZE TABLE `guild_storage_log`;
ANALYZE TABLE `party_bookings`;
ANALYZE TABLE `friends`;
ANALYZE TABLE `mail_attachments`;

-- Trading systems
SELECT 'Analyzing trading system tables...' AS 'Progress';
ANALYZE TABLE `auction`;
ANALYZE TABLE `vendings`;
ANALYZE TABLE `vending_items`;
ANALYZE TABLE `buyingstores`;
ANALYZE TABLE `buyingstore_items`;
ANALYZE TABLE `barter`;
ANALYZE TABLE `market`;
ANALYZE TABLE `sales`;

-- Game systems
SELECT 'Analyzing game system tables...' AS 'Progress';
ANALYZE TABLE `skill`;
ANALYZE TABLE `skillcooldown`;
ANALYZE TABLE `quest`;
ANALYZE TABLE `achievement`;
ANALYZE TABLE `hotkey`;
ANALYZE TABLE `sc_data`;
ANALYZE TABLE `memo`;

-- Companion systems
SELECT 'Analyzing companion system tables...' AS 'Progress';
ANALYZE TABLE `pet`;
ANALYZE TABLE `homunculus`;
ANALYZE TABLE `skill_homunculus`;
ANALYZE TABLE `skillcooldown_homunculus`;
ANALYZE TABLE `mercenary`;
ANALYZE TABLE `mercenary_owner`;
ANALYZE TABLE `skillcooldown_mercenary`;
ANALYZE TABLE `elemental`;

-- Other systems
SELECT 'Analyzing other system tables...' AS 'Progress';
ANALYZE TABLE `clan`;
ANALYZE TABLE `clan_alliance`;
ANALYZE TABLE `mapreg`;
ANALYZE TABLE `ipbanlist`;
ANALYZE TABLE `db_roulette`;

-- Logging tables
SELECT 'Analyzing logging tables...' AS 'Progress';
ANALYZE TABLE `atcommandlog`;
ANALYZE TABLE `branchlog`;
ANALYZE TABLE `cashlog`;
ANALYZE TABLE `chatlog`;
ANALYZE TABLE `feedinglog`;
ANALYZE TABLE `loginlog`;
ANALYZE TABLE `mvplog`;
ANALYZE TABLE `npclog`;
ANALYZE TABLE `picklog`;
ANALYZE TABLE `zenylog`;

SELECT 'PHASE 1 COMPLETE: All table statistics updated' AS '';
SELECT NOW() AS 'Phase 1 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 2: OPTIMIZE TABLE (Critical Tables Only)
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 2: OPTIMIZE TABLE - Rebuild and Defragment Critical Tables' AS '';
SELECT 'This reclaims space and improves performance' AS '';
SELECT 'WARNING: This locks tables briefly - do during low traffic!' AS '';
SELECT '============================================================================' AS '';

SELECT 'NOTE: OPTIMIZE TABLE on InnoDB performs:' AS '';
SELECT '- Rebuilds table to reclaim wasted space' AS '';
SELECT '- Rebuilds all indexes' AS '';
SELECT '- Updates statistics' AS '';
SELECT '- Can take significant time for large tables' AS '';
SELECT '' AS '';

-- Check fragmentation first
SELECT 'Tables with significant fragmentation:' AS '';
SELECT 
    TABLE_NAME,
    ENGINE,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS 'Size_MB',
    ROUND(DATA_FREE / 1024 / 1024, 2) AS 'Free_MB',
    ROUND((DATA_FREE / NULLIF(DATA_LENGTH + INDEX_LENGTH, 0)) * 100, 2) AS 'Frag_%'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND ENGINE IN ('InnoDB', 'Aria')
  AND DATA_FREE > 10485760  -- More than 10MB free
ORDER BY DATA_FREE DESC
LIMIT 10;

SELECT '' AS '';
SELECT 'Optimizing critical tables (this may take a while)...' AS 'Progress';
SELECT '' AS '';

-- Optimize critical tables one by one
SELECT CONCAT('Optimizing: char - ', NOW()) AS 'Progress';
SELECT 'Estimated time: 1-5 minutes' AS '';
OPTIMIZE TABLE `char`;
SELECT '' AS '';

SELECT CONCAT('Optimizing: inventory - ', NOW()) AS 'Progress';
SELECT 'Estimated time: 2-10 minutes' AS '';
OPTIMIZE TABLE `inventory`;
SELECT '' AS '';

SELECT CONCAT('Optimizing: storage - ', NOW()) AS 'Progress';
SELECT 'Estimated time: 1-5 minutes' AS '';
OPTIMIZE TABLE `storage`;
SELECT '' AS '';

SELECT CONCAT('Optimizing: guild_storage - ', NOW()) AS 'Progress';
SELECT 'Estimated time: 1-5 minutes' AS '';
OPTIMIZE TABLE `guild_storage`;
SELECT '' AS '';

SELECT CONCAT('Optimizing: login - ', NOW()) AS 'Progress';
SELECT 'Estimated time: <1 minute' AS '';
OPTIMIZE TABLE `login`;
SELECT '' AS '';

SELECT CONCAT('Optimizing: guild - ', NOW()) AS 'Progress';
SELECT 'Estimated time: <1 minute' AS '';
OPTIMIZE TABLE `guild`;
SELECT '' AS '';

SELECT CONCAT('Optimizing: guild_member - ', NOW()) AS 'Progress';
SELECT 'Estimated time: <1 minute' AS '';
OPTIMIZE TABLE `guild_member`;
SELECT '' AS '';

SELECT 'PHASE 2 COMPLETE: Critical tables optimized' AS '';
SELECT NOW() AS 'Phase 2 Completion Time';
SELECT '' AS '';

SELECT 'NOTE: Other tables can be optimized later during maintenance windows' AS '';
SELECT 'To optimize all tables: Run maintenance.sql from Phase A' AS '';
SELECT '' AS '';

-- ============================================================================
-- PHASE 3: InnoDB Tablespace Information
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 3: InnoDB Tablespace Health Check' AS '';
SELECT '============================================================================' AS '';

SELECT 'InnoDB File Per Table Status:' AS '';
SELECT VARIABLE_NAME, VARIABLE_VALUE
FROM information_schema.GLOBAL_VARIABLES
WHERE VARIABLE_NAME = 'innodb_file_per_table';

SELECT '' AS '';

SELECT 'InnoDB Tablespace Files:' AS '';
SELECT 
    TABLE_NAME,
    ENGINE,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS 'Size_MB'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND ENGINE = 'InnoDB'
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC
LIMIT 15;

SELECT '' AS '';

-- ============================================================================
-- PHASE 4: Buffer Pool Optimization Status
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 4: InnoDB Buffer Pool Status' AS '';
SELECT '============================================================================' AS '';

SELECT 'Current Buffer Pool Configuration:' AS '';
SELECT 
    VARIABLE_NAME,
    VARIABLE_VALUE,
    CASE VARIABLE_NAME
        WHEN 'innodb_buffer_pool_size' THEN 
            CONCAT(' (', ROUND(CAST(VARIABLE_VALUE AS UNSIGNED)/1024/1024/1024, 2), ' GB)')
        ELSE ''
    END AS 'Human Readable'
FROM information_schema.GLOBAL_VARIABLES
WHERE VARIABLE_NAME IN (
    'innodb_buffer_pool_size',
    'innodb_buffer_pool_instances',
    'innodb_buffer_pool_chunk_size'
)
ORDER BY VARIABLE_NAME;

SELECT '' AS '';

SELECT 'Buffer Pool Performance Metrics:' AS '';
SHOW STATUS LIKE 'Innodb_buffer_pool%';

SELECT '' AS '';

-- Calculate and display hit ratio
SELECT 
    'Buffer Pool Hit Ratio' AS 'Metric',
    CONCAT(
        ROUND(
            100 * (1 - (
                CAST((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') AS DECIMAL(20,2)) /
                NULLIF(CAST((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests') AS DECIMAL(20,2)), 0)
            )),
            2
        ),
        '%'
    ) AS 'Current Value',
    CASE 
        WHEN (1 - (CAST((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') AS DECIMAL(20,2)) /
                   NULLIF(CAST((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests') AS DECIMAL(20,2)), 0))) > 0.99
        THEN '✓ Excellent (Target: >99%)'
        WHEN (1 - (CAST((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') AS DECIMAL(20,2)) /
                   NULLIF(CAST((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests') AS DECIMAL(20,2)), 0))) > 0.95
        THEN '⚠ Good but can improve (Target: >99%)'
        ELSE '✗ Poor - Increase buffer pool size!'
    END AS 'Status';

SELECT '' AS '';

-- ============================================================================
-- PHASE 5: Configuration Recommendations
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 5: Configuration Recommendations' AS '';
SELECT '============================================================================' AS '';

SELECT 'Current InnoDB Configuration:' AS '';
SELECT 
    VARIABLE_NAME,
    VARIABLE_VALUE,
    CASE VARIABLE_NAME
        WHEN 'innodb_buffer_pool_size' THEN CONCAT('Recommend: ', ROUND(CAST(VARIABLE_VALUE AS UNSIGNED)/1024/1024/1024, 2), ' GB (50-80% of RAM)')
        WHEN 'innodb_log_file_size' THEN CONCAT('Recommend: 512M-1G for game servers')
        WHEN 'innodb_flush_log_at_trx_commit' THEN 
            CASE VARIABLE_VALUE
                WHEN '1' THEN 'GOOD: Full ACID compliance (safest)'
                WHEN '2' THEN 'WARNING: Risk losing 1 sec of data on OS crash'
                ELSE 'DANGER: Can lose transactions on crash!'
            END
        WHEN 'innodb_file_per_table' THEN
            CASE VARIABLE_VALUE
                WHEN 'ON' THEN 'GOOD: Enabled (recommended)'
                ELSE 'WARNING: Should be ON for better management'
            END
        WHEN 'innodb_io_capacity' THEN 
            CASE 
                WHEN CAST(VARIABLE_VALUE AS UNSIGNED) >= 2000 THEN 'GOOD: Optimized for SSD'
                WHEN CAST(VARIABLE_VALUE AS UNSIGNED) >= 200 THEN 'OK: Suitable for HDD'
                ELSE 'LOW: Consider increasing for better performance'
            END
        ELSE ''
    END AS 'Recommendation'
FROM information_schema.GLOBAL_VARIABLES
WHERE VARIABLE_NAME IN (
    'innodb_buffer_pool_size',
    'innodb_log_file_size',
    'innodb_flush_log_at_trx_commit',
    'innodb_file_per_table',
    'innodb_io_capacity',
    'innodb_flush_neighbors',
    'innodb_read_io_threads',
    'innodb_write_io_threads'
)
ORDER BY VARIABLE_NAME;

SELECT '' AS '';

-- ============================================================================
-- PHASE 6: Monitoring Setup Recommendations
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 6: Performance Monitoring Setup' AS '';
SELECT '============================================================================' AS '';

SELECT 'Slow Query Log Status:' AS '';
SELECT VARIABLE_NAME, VARIABLE_VALUE
FROM information_schema.GLOBAL_VARIABLES
WHERE VARIABLE_NAME IN ('slow_query_log', 'long_query_time', 'log_queries_not_using_indexes')
ORDER BY VARIABLE_NAME;

SELECT '' AS '';

SELECT 'Enable slow query log with these commands:' AS '';
SELECT 'SET GLOBAL slow_query_log = ON;' AS 'SQL Command';
SELECT 'SET GLOBAL long_query_time = 2;' AS 'SQL Command';
SELECT 'SET GLOBAL log_queries_not_using_indexes = ON;' AS 'SQL Command';

SELECT '' AS '';

SELECT 'Performance Schema Status:' AS '';
SELECT VARIABLE_NAME, VARIABLE_VALUE
FROM information_schema.GLOBAL_VARIABLES
WHERE VARIABLE_NAME = 'performance_schema';

SELECT '' AS '';

-- ============================================================================
-- PHASE 7: Space Reclamation Summary
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 7: Space Reclamation Summary' AS '';
SELECT '============================================================================' AS '';

SELECT 'Database Size After Optimization:' AS '';
SELECT 
    COUNT(*) AS 'Total Tables',
    ROUND(SUM(DATA_LENGTH) / 1024 / 1024 / 1024, 2) AS 'Data (GB)',
    ROUND(SUM(INDEX_LENGTH) / 1024 / 1024 / 1024, 2) AS 'Indexes (GB)',
    ROUND(SUM(DATA_FREE) / 1024 / 1024 / 1024, 2) AS 'Free Space (GB)',
    ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / 1024, 2) AS 'Total Used (GB)'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND ENGINE IN ('InnoDB', 'Aria');

SELECT '' AS '';

SELECT 'Remaining Fragmentation (if any):' AS '';
SELECT 
    TABLE_NAME,
    ENGINE,
    ROUND(DATA_FREE / 1024 / 1024, 2) AS 'Free_MB',
    ROUND((DATA_FREE / NULLIF(DATA_LENGTH + INDEX_LENGTH, 0)) * 100, 2) AS 'Frag_%'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND ENGINE IN ('InnoDB', 'Aria')
  AND DATA_FREE > 10485760
ORDER BY DATA_FREE DESC
LIMIT 10;

SELECT '' AS '';

-- ============================================================================
-- OPTIMIZATION COMPLETE
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'POST-MIGRATION OPTIMIZATION COMPLETE!' AS '';
SELECT '============================================================================' AS '';
SELECT NOW() AS 'Optimization End Time';
SELECT '' AS '';

SELECT '✓ Table statistics updated (ANALYZE TABLE)' AS 'Status';
SELECT '✓ Critical tables optimized (OPTIMIZE TABLE)' AS 'Status';
SELECT '✓ InnoDB tablespace verified' AS 'Status';
SELECT '✓ Buffer pool performance checked' AS 'Status';
SELECT '✓ Configuration recommendations provided' AS 'Status';
SELECT '' AS '';

SELECT '╔════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║  CRITICAL NEXT STEPS                                                   ║' AS '';
SELECT '╚════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

SELECT '1. PERFORMANCE TUNING (my.cnf / my.ini):' AS '';
SELECT '   Review configuration recommendations above' AS '';
SELECT '   Adjust innodb_buffer_pool_size to 50-80% of RAM' AS '';
SELECT '   Ensure innodb_flush_log_at_trx_commit = 1 (production)' AS '';
SELECT '   Set innodb_io_capacity appropriate for storage (SSD: 2000+, HDD: 200)' AS '';
SELECT '   Restart MariaDB after configuration changes' AS '';
SELECT '' AS '';

SELECT '2. ENABLE MONITORING:' AS '';
SELECT '   SET GLOBAL slow_query_log = ON;' AS '';
SELECT '   SET GLOBAL long_query_time = 2;' AS '';
SELECT '   Monitor /var/log/mysql/slow-query.log daily' AS '';
SELECT '' AS '';

SELECT '3. TEST GAME SERVERS:' AS '';
SELECT '   Start game servers in test mode' AS '';
SELECT '   Test critical operations:' AS '';
SELECT '     - Login/Logout' AS '';
SELECT '     - Character select' AS '';
SELECT '     - Inventory operations' AS '';
SELECT '     - Trading' AS '';
SELECT '     - Guild operations' AS '';
SELECT '     - Mail system' AS '';
SELECT '   Monitor error logs for any issues' AS '';
SELECT '' AS '';

SELECT '4. PERFORMANCE BASELINE:' AS '';
SELECT '   Run health_check.sql and save as baseline' AS '';
SELECT '   Monitor buffer pool hit ratio (should be >99%)' AS '';
SELECT '   Check slow query log after 24 hours' AS '';
SELECT '   Compare performance with pre-migration metrics' AS '';
SELECT '' AS '';

SELECT '5. PRODUCTION ROLLOUT:' AS '';
SELECT '   If tests pass: Open server to public' AS '';
SELECT '   Monitor closely for first 48 hours' AS '';
SELECT '   Keep rollback_to_myisam.sql ready (just in case)' AS '';
SELECT '   Document any performance issues' AS '';
SELECT '' AS '';

SELECT '6. ONGOING MAINTENANCE:' AS '';
SELECT '   Run ANALYZE TABLE weekly on active tables' AS '';
SELECT '   Run OPTIMIZE TABLE monthly on fragmented tables' AS '';
SELECT '   Monitor table sizes and growth rates' AS '';
SELECT '   Review slow query log weekly' AS '';
SELECT '   Plan for buffer pool size increases as data grows' AS '';
SELECT '' AS '';

SELECT 'CONFIGURATION TEMPLATE for my.cnf:' AS '';
SELECT '----------------------------------------' AS '';
SELECT '[mysqld]' AS '';
SELECT '# InnoDB Optimizations for rAthena' AS '';
SELECT 'innodb_buffer_pool_size = 4G  # Adjust to 50-80% of RAM' AS '';
SELECT 'innodb_buffer_pool_instances = 4  # 1 per GB' AS '';
SELECT 'innodb_log_file_size = 512M' AS '';
SELECT 'innodb_log_files_in_group = 2' AS '';
SELECT 'innodb_flush_log_at_trx_commit = 1  # Full ACID' AS '';
SELECT 'innodb_file_per_table = 1' AS '';
SELECT 'innodb_io_capacity = 2000  # SSD: 2000+, HDD: 200' AS '';
SELECT 'innodb_flush_neighbors = 0  # SSD: 0, HDD: 1' AS '';
SELECT 'innodb_read_io_threads = 8' AS '';
SELECT 'innodb_write_io_threads = 8' AS '';
SELECT 'innodb_flush_method = O_DIRECT' AS '';
SELECT '' AS '';
SELECT '# Monitoring' AS '';
SELECT 'slow_query_log = 1' AS '';
SELECT 'long_query_time = 2' AS '';
SELECT 'log_queries_not_using_indexes = 1' AS '';
SELECT '' AS '';
SELECT '# Thread Pool (optional but recommended)' AS '';
SELECT 'thread_handling = pool-of-threads' AS '';
SELECT 'thread_pool_size = 4  # Number of CPU cores' AS '';
SELECT '----------------------------------------' AS '';
SELECT '' AS '';

SELECT 'Performance Monitoring Commands:' AS '';
SELECT '  mysql -e "SHOW ENGINE INNODB STATUS\G" | less' AS '';
SELECT '  mysql -e "SHOW STATUS LIKE ''Innodb%''\G" | grep -i buffer' AS '';
SELECT '  mysqladmin extended-status | grep -i innodb' AS '';
SELECT '  tail -f /var/log/mysql/slow-query.log' AS '';
SELECT '' AS '';

SELECT 'Need Help?' AS '';
SELECT '- MariaDB Knowledge Base: https://mariadb.com/kb/' AS '';
SELECT '- rAthena Forums: https://rathena.org/board/' AS '';
SELECT '- Review MARIADB_OPTIMIZATION_PLAN.md for detailed guidance' AS '';
SELECT '' AS '';

SELECT '============================================================================' AS '';
SELECT 'Congratulations! Your database is now optimized with InnoDB/Aria' AS '';
SELECT '============================================================================' AS '';
