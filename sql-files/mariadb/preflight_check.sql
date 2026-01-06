-- ============================================================================
-- PHASE B PRE-FLIGHT CHECK - Storage Engine Migration
-- ============================================================================
-- Purpose: Verify system readiness before MyISAM → InnoDB/Aria migration
-- Target: MariaDB 10.11+ LTS or 11.2+ Stable
-- Risk Level: SAFE (read-only checks, no modifications)
-- Duration: 1-2 minutes
-- 
-- Usage:
--   mysql -u root -p rathena < preflight_check.sql > preflight_report.txt
--   Review report for GO/NO-GO recommendation
-- ============================================================================

SELECT '============================================================================' AS '';
SELECT 'PHASE B PRE-FLIGHT CHECK - Storage Engine Migration' AS '';
SELECT '============================================================================' AS '';
SELECT NOW() AS 'Check Time';
SELECT DATABASE() AS 'Target Database';
SELECT '' AS '';

-- ============================================================================
-- CHECK 1: MariaDB Version
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'CHECK 1: MariaDB Version' AS '';
SELECT '----------------------------------------------------------------------------' AS '';

SELECT VERSION() AS 'MariaDB Version';

SELECT CASE
    WHEN VERSION() LIKE '10.11.%' OR VERSION() LIKE '11.%' OR 
         VERSION() LIKE '10.1_.__' OR VERSION() LIKE '10.__.%' AND
         SUBSTRING_INDEX(VERSION(), '.', 1) >= 10 AND
         CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(VERSION(), '.', 2), '.', -1) AS UNSIGNED) >= 11
    THEN '✓ PASS - MariaDB version is compatible'
    WHEN VERSION() LIKE '10.6.%' OR VERSION() LIKE '10.7.%' OR 
         VERSION() LIKE '10.8.%' OR VERSION() LIKE '10.9.%' OR VERSION() LIKE '10.10.%'
    THEN '⚠ WARNING - MariaDB 10.6-10.10 supported but 10.11 LTS recommended'
    ELSE '✗ FAIL - MariaDB 10.11+ or 11.2+ required'
END AS 'Version Check';

SELECT 'Recommendation: MariaDB 10.11 LTS (stable until Feb 2028) or 11.2+' AS '';
SELECT '' AS '';

-- ============================================================================
-- CHECK 2: Storage Engine Availability
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'CHECK 2: Storage Engine Availability' AS '';
SELECT '----------------------------------------------------------------------------' AS '';

SELECT ENGINE, SUPPORT, COMMENT
FROM information_schema.ENGINES
WHERE ENGINE IN ('InnoDB', 'Aria', 'MyISAM')
ORDER BY ENGINE;

SELECT CASE
    WHEN (SELECT COUNT(*) FROM information_schema.ENGINES 
          WHERE ENGINE = 'InnoDB' AND SUPPORT IN ('YES', 'DEFAULT')) = 1
    THEN '✓ PASS - InnoDB engine available'
    ELSE '✗ FAIL - InnoDB engine not available'
END AS 'InnoDB Check';

SELECT CASE
    WHEN (SELECT COUNT(*) FROM information_schema.ENGINES 
          WHERE ENGINE = 'Aria' AND SUPPORT IN ('YES', 'DEFAULT')) = 1
    THEN '✓ PASS - Aria engine available'
    ELSE '⚠ WARNING - Aria engine not available (can use InnoDB for logs)'
END AS 'Aria Check';

SELECT '' AS '';

-- ============================================================================
-- CHECK 3: Current Database Size and Row Counts
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'CHECK 3: Current Database Size' AS '';
SELECT '----------------------------------------------------------------------------' AS '';

SELECT 
    COUNT(*) AS 'Total Tables',
    ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS 'Current Size (MB)',
    ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / 1024, 2) AS 'Current Size (GB)',
    ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) * 1.75 / 1024 / 1024 / 1024, 2) AS 'Estimated Size After Migration (GB)',
    SUM(TABLE_ROWS) AS 'Total Rows'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE();

SELECT 'Note: InnoDB requires ~50-75% more disk space initially' AS '';
SELECT '' AS '';

-- ============================================================================
-- CHECK 4: Storage Engine Distribution
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'CHECK 4: Current Storage Engine Distribution' AS '';
SELECT '----------------------------------------------------------------------------' AS '';

SELECT 
    ENGINE,
    COUNT(*) AS 'Table Count',
    ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS 'Total Size (MB)'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
GROUP BY ENGINE
ORDER BY COUNT(*) DESC;

SELECT 
    CONCAT(
        COUNT(CASE WHEN ENGINE = 'MyISAM' THEN 1 END), ' MyISAM tables',
        ' (', ROUND(COUNT(CASE WHEN ENGINE = 'MyISAM' THEN 1 END) * 100.0 / COUNT(*), 1), '%)'
    ) AS 'MyISAM Tables to Convert'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE();

SELECT '' AS '';

-- ============================================================================
-- CHECK 5: Disk Space Availability
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'CHECK 5: Disk Space Requirements' AS '';
SELECT '----------------------------------------------------------------------------' AS '';

-- Note: This check shows the requirement, but actual disk space check must be done at OS level
SELECT 
    ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / 1024, 2) AS 'Current DB Size (GB)',
    ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) * 1.75 / 1024 / 1024 / 1024, 2) AS 'Required Free Space (GB)',
    ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) * 2.0 / 1024 / 1024 / 1024, 2) AS 'Recommended Free Space (GB)'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE();

SELECT 'CRITICAL: Verify disk space with: df -h /var/lib/mysql' AS 'Manual Check Required';
SELECT 'Migration will fail if insufficient disk space!' AS 'WARNING';
SELECT '' AS '';

-- ============================================================================
-- CHECK 6: Table Sizes (Largest Tables)
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'CHECK 6: Largest Tables (Migration Time Estimate)' AS '';
SELECT '----------------------------------------------------------------------------' AS '';

SELECT 
    TABLE_NAME,
    ENGINE,
    TABLE_ROWS AS 'Rows',
    ROUND(DATA_LENGTH / 1024 / 1024, 2) AS 'Data (MB)',
    ROUND(INDEX_LENGTH / 1024 / 1024, 2) AS 'Index (MB)',
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS 'Total (MB)',
    CONCAT(ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / 1024, 1), ' min') AS 'Est. Migration Time'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC
LIMIT 20;

SELECT 'Note: Estimate ~1 minute per GB for engine conversion' AS '';
SELECT '' AS '';

-- ============================================================================
-- CHECK 7: InnoDB Configuration
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'CHECK 7: InnoDB Configuration' AS '';
SELECT '----------------------------------------------------------------------------' AS '';

SELECT 
    VARIABLE_NAME,
    VARIABLE_VALUE,
    CASE VARIABLE_NAME
        WHEN 'innodb_buffer_pool_size' THEN 
            CONCAT('(', ROUND(CAST(VARIABLE_VALUE AS UNSIGNED) / 1024 / 1024 / 1024, 2), ' GB)')
        WHEN 'innodb_log_file_size' THEN
            CONCAT('(', ROUND(CAST(VARIABLE_VALUE AS UNSIGNED) / 1024 / 1024, 2), ' MB)')
        ELSE ''
    END AS 'Human Readable'
FROM information_schema.GLOBAL_VARIABLES
WHERE VARIABLE_NAME IN (
    'innodb_buffer_pool_size',
    'innodb_buffer_pool_instances',
    'innodb_log_file_size',
    'innodb_log_files_in_group',
    'innodb_flush_log_at_trx_commit',
    'innodb_file_per_table',
    'innodb_io_capacity'
)
ORDER BY VARIABLE_NAME;

-- Buffer pool adequacy check
SELECT CASE
    WHEN CAST((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_VARIABLES 
               WHERE VARIABLE_NAME = 'innodb_buffer_pool_size') AS UNSIGNED) >= 1073741824
    THEN '✓ PASS - InnoDB buffer pool >= 1GB'
    ELSE '⚠ WARNING - InnoDB buffer pool < 1GB (should be 50-80% of RAM)'
END AS 'Buffer Pool Check';

SELECT 'Recommendation: Set innodb_buffer_pool_size to 50-80% of available RAM' AS '';
SELECT '' AS '';

-- ============================================================================
-- CHECK 8: Active Connections
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'CHECK 8: Active Connections' AS '';
SELECT '----------------------------------------------------------------------------' AS '';

SELECT 
    COUNT(*) AS 'Current Connections',
    (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_VARIABLES 
     WHERE VARIABLE_NAME = 'max_connections') AS 'Max Connections'
FROM information_schema.PROCESSLIST;

SELECT CASE
    WHEN (SELECT COUNT(*) FROM information_schema.PROCESSLIST) > 10
    THEN '⚠ WARNING - High connection count. Migration should be done during maintenance window'
    ELSE '✓ PASS - Low connection count'
END AS 'Connection Check';

SELECT 'Recommendation: Run migration during low traffic / maintenance window' AS '';
SELECT 'CRITICAL: Stop all game servers (login, char, map) before migration!' AS '';
SELECT '' AS '';

-- ============================================================================
-- CHECK 9: Binary Logging Status
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'CHECK 9: Binary Logging Configuration' AS '';
SELECT '----------------------------------------------------------------------------' AS '';

SELECT 
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM information_schema.GLOBAL_VARIABLES
WHERE VARIABLE_NAME IN ('log_bin', 'binlog_format', 'expire_logs_days', 'max_binlog_size')
ORDER BY VARIABLE_NAME;

SELECT CASE
    WHEN (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_VARIABLES 
          WHERE VARIABLE_NAME = 'log_bin') = 'ON'
    THEN '✓ PASS - Binary logging enabled (good for recovery)'
    ELSE '⚠ WARNING - Binary logging disabled (no point-in-time recovery)'
END AS 'Binlog Check';

SELECT '' AS '';

-- ============================================================================
-- CHECK 10: Character Set Compatibility
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'CHECK 10: Character Set Compatibility' AS '';
SELECT '----------------------------------------------------------------------------' AS '';

SELECT 
    TABLE_NAME,
    TABLE_COLLATION,
    CASE 
        WHEN TABLE_COLLATION LIKE 'utf8mb4%' THEN '✓ utf8mb4'
        WHEN TABLE_COLLATION LIKE 'utf8%' THEN '⚠ utf8 (should upgrade to utf8mb4)'
        ELSE '✗ Other (may have issues)'
    END AS 'Collation Status'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_COLLATION NOT LIKE 'utf8mb4%'
ORDER BY TABLE_NAME;

SELECT COUNT(*) AS 'Tables Needing Collation Update'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_COLLATION NOT LIKE 'utf8mb4%';

SELECT '' AS '';

-- ============================================================================
-- CHECK 11: Tables Without Primary Keys
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'CHECK 11: Tables Without Primary Keys' AS '';
SELECT '----------------------------------------------------------------------------' AS '';

SELECT DISTINCT t.TABLE_NAME
FROM information_schema.TABLES t
LEFT JOIN information_schema.TABLE_CONSTRAINTS tc
    ON t.TABLE_SCHEMA = tc.TABLE_SCHEMA
    AND t.TABLE_NAME = tc.TABLE_NAME
    AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
WHERE t.TABLE_SCHEMA = DATABASE()
  AND t.TABLE_TYPE = 'BASE TABLE'
  AND tc.CONSTRAINT_NAME IS NULL
ORDER BY t.TABLE_NAME;

SELECT 'Note: InnoDB strongly recommends PRIMARY KEY on all tables' AS '';
SELECT '' AS '';

-- ============================================================================
-- CHECK 12: Estimated Migration Time
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'CHECK 12: Migration Time Estimation' AS '';
SELECT '----------------------------------------------------------------------------' AS '';

SELECT 
    COUNT(*) AS 'Tables to Migrate',
    ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / 1024, 2) AS 'Total Data (GB)',
    CONCAT(
        ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / 1024 * 1.5, 0),
        ' - ',
        ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / 1024 * 2.5, 0),
        ' minutes'
    ) AS 'Estimated Migration Time',
    CONCAT(
        ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / 1024 * 1.5 / 60, 1),
        ' - ',
        ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / 1024 * 2.5 / 60, 1),
        ' hours'
    ) AS 'Time in Hours'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND ENGINE = 'MyISAM';

SELECT 'Calculation: ~1-2 minutes per GB of data' AS '';
SELECT 'Add 30-50% overhead for verification and optimization' AS '';
SELECT '' AS '';

-- ============================================================================
-- CHECK 13: Backup Status Verification
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'CHECK 13: Pre-Migration Backup Verification' AS '';
SELECT '----------------------------------------------------------------------------' AS '';

SELECT 'CRITICAL: Before proceeding with migration, you MUST:' AS '';
SELECT '1. Create full database backup: mysqldump --single-transaction' AS '';
SELECT '2. Test backup restore on separate instance' AS '';
SELECT '3. Verify backup file size matches database size' AS '';
SELECT '4. Store backup in safe location (not on same disk!)' AS '';
SELECT '5. Document backup location and timestamp' AS '';
SELECT '' AS '';

-- ============================================================================
-- FINAL RECOMMENDATION
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'FINAL GO/NO-GO RECOMMENDATION' AS '';
SELECT '============================================================================' AS '';

-- Comprehensive readiness check
SELECT CASE
    -- Check version
    WHEN NOT (VERSION() LIKE '10.11.%' OR VERSION() LIKE '11.%' OR 
              (VERSION() LIKE '10.__.%' AND 
               SUBSTRING_INDEX(VERSION(), '.', 1) >= 10 AND
               CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(VERSION(), '.', 2), '.', -1) AS UNSIGNED) >= 6))
    THEN '✗ NO-GO: MariaDB version too old (need 10.11+ or 11.2+)'
    
    -- Check InnoDB availability
    WHEN (SELECT COUNT(*) FROM information_schema.ENGINES 
          WHERE ENGINE = 'InnoDB' AND SUPPORT IN ('YES', 'DEFAULT')) = 0
    THEN '✗ NO-GO: InnoDB engine not available'
    
    -- Check buffer pool
    WHEN CAST((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_VARIABLES 
               WHERE VARIABLE_NAME = 'innodb_buffer_pool_size') AS UNSIGNED) < 536870912
    THEN '⚠ CAUTION: Buffer pool < 512MB (will impact performance)'
    
    -- Check connection count
    WHEN (SELECT COUNT(*) FROM information_schema.PROCESSLIST) > 20
    THEN '⚠ CAUTION: High connection count - schedule during maintenance window'
    
    -- All clear
    ELSE '✓ GO: System ready for migration'
END AS 'Final Recommendation';

SELECT '' AS '';
SELECT 'Pre-Migration Checklist:' AS '';
SELECT '[ ] MariaDB 10.11+ or 11.2+ verified' AS '';
SELECT '[ ] Full database backup completed and tested' AS '';
SELECT '[ ] Disk space verified (need 1.75-2x current DB size free)' AS '';
SELECT '[ ] InnoDB buffer pool configured (50-80% of RAM)' AS '';
SELECT '[ ] Binary logging enabled (recommended)' AS '';
SELECT '[ ] Maintenance window scheduled (2-4 hours)' AS '';
SELECT '[ ] All game servers will be stopped (login, char, map)' AS '';
SELECT '[ ] Emergency contacts notified' AS '';
SELECT '[ ] Rollback plan reviewed' AS '';
SELECT '[ ] Migration scripts reviewed and tested' AS '';
SELECT '' AS '';

SELECT 'Next Steps:' AS '';
SELECT '1. Review this preflight report carefully' AS '';
SELECT '2. Address any FAIL or CRITICAL warnings' AS '';
SELECT '3. Create full backup: mysqldump -u root -p --single-transaction rathena > backup.sql' AS '';
SELECT '4. Stop game servers: ./athena-start stop' AS '';
SELECT '5. Run migration: bash migrate_phased.sh' AS '';
SELECT '6. Monitor progress and review logs' AS '';
SELECT '7. Run verification: mysql rathena < verify_migration.sql' AS '';
SELECT '8. Restart game servers and test' AS '';
SELECT '' AS '';

SELECT '============================================================================' AS '';
SELECT 'END OF PRE-FLIGHT CHECK' AS '';
SELECT '============================================================================' AS '';
SELECT NOW() AS 'Report Generated At';
SELECT 'Save this report for documentation purposes' AS '';
SELECT '============================================================================' AS '';
