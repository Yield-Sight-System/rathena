-- ============================================================================
-- RATHENA DATABASE HEALTH CHECK SCRIPT
-- ============================================================================
-- Version: 1.0
-- Date: 2026-01-06
-- Target: MariaDB 10.11+ / 11.2+
-- Database: rathena
--
-- Purpose:
--   Comprehensive database health check and diagnostic tool for rAthena
--   game server database. Provides insights into:
--   - Database size and table statistics
--   - Index effectiveness and coverage
--   - Storage engine usage
--   - Character encoding verification
--   - Buffer pool performance
--   - Query performance indicators
--   - Table fragmentation analysis
--   - Potential issues and recommendations
--
-- Usage:
--   mysql -u root -p rathena < health_check.sql > health_report.txt
--   
--   Or from MySQL prompt:
--   USE rathena;
--   SOURCE health_check.sql;
--
-- Output:
--   Formatted report with sections for easy reading
--   Save output to file for comparison over time
--
-- Safety:
--   - Read-only queries, no modifications
--   - Safe to run on production database
--   - Minimal performance impact
-- ============================================================================

-- Display header
SELECT '============================================================================' AS '';
SELECT 'RATHENA DATABASE HEALTH CHECK REPORT' AS '';
SELECT '============================================================================' AS '';
SELECT CONCAT('Generated: ', NOW()) AS '';
SELECT CONCAT('Database: ', DATABASE()) AS '';
SELECT CONCAT('MariaDB Version: ', VERSION()) AS '';
SELECT '============================================================================' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 1: DATABASE SIZE AND TABLE STATISTICS
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 1: DATABASE SIZE AND TABLE STATISTICS                           ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Overall database size summary
SELECT 'Database Size Summary:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    CONCAT(ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / 1024, 2), ' GB') AS 'Total Size',
    CONCAT(ROUND(SUM(DATA_LENGTH) / 1024 / 1024 / 1024, 2), ' GB') AS 'Data Size',
    CONCAT(ROUND(SUM(INDEX_LENGTH) / 1024 / 1024 / 1024, 2), ' GB') AS 'Index Size',
    CONCAT(ROUND((SUM(INDEX_LENGTH) / SUM(DATA_LENGTH)) * 100, 2), '%') AS 'Index/Data Ratio',
    COUNT(*) AS 'Total Tables'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE();

SELECT '' AS '';

-- Top 20 largest tables by size
SELECT 'Top 20 Largest Tables:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    TABLE_NAME AS 'Table',
    ENGINE AS 'Engine',
    TABLE_ROWS AS 'Rows',
    CONCAT(ROUND(DATA_LENGTH / 1024 / 1024, 2), ' MB') AS 'Data Size',
    CONCAT(ROUND(INDEX_LENGTH / 1024 / 1024, 2), ' MB') AS 'Index Size',
    CONCAT(ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2), ' MB') AS 'Total Size',
    CONCAT(ROUND((INDEX_LENGTH / NULLIF(DATA_LENGTH, 0)) * 100, 2), '%') AS 'Index Ratio'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC
LIMIT 20;

SELECT '' AS '';

-- Row count summary by table type
SELECT 'Table Row Count Summary:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    CASE
        WHEN TABLE_NAME LIKE '%log' THEN 'Logging Tables'
        WHEN TABLE_NAME IN ('char', 'inventory', 'storage', 'cart_inventory') THEN 'Character Data'
        WHEN TABLE_NAME IN ('guild', 'guild_member', 'guild_storage') THEN 'Guild Data'
        WHEN TABLE_NAME IN ('login', 'acc_reg_num', 'acc_reg_str') THEN 'Account Data'
        ELSE 'Other Tables'
    END AS 'Category',
    COUNT(*) AS 'Tables',
    FORMAT(SUM(TABLE_ROWS), 0) AS 'Total Rows',
    CONCAT(ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2), ' MB') AS 'Total Size'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
GROUP BY 
    CASE
        WHEN TABLE_NAME LIKE '%log' THEN 'Logging Tables'
        WHEN TABLE_NAME IN ('char', 'inventory', 'storage', 'cart_inventory') THEN 'Character Data'
        WHEN TABLE_NAME IN ('guild', 'guild_member', 'guild_storage') THEN 'Guild Data'
        WHEN TABLE_NAME IN ('login', 'acc_reg_num', 'acc_reg_str') THEN 'Account Data'
        ELSE 'Other Tables'
    END
ORDER BY SUM(TABLE_ROWS) DESC;

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 2: STORAGE ENGINE ANALYSIS
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 2: STORAGE ENGINE ANALYSIS                                      ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Storage engine distribution
SELECT 'Storage Engine Distribution:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    ENGINE AS 'Engine',
    COUNT(*) AS 'Tables',
    FORMAT(SUM(TABLE_ROWS), 0) AS 'Total Rows',
    CONCAT(ROUND(SUM(DATA_LENGTH) / 1024 / 1024, 2), ' MB') AS 'Data Size',
    CONCAT(ROUND(SUM(INDEX_LENGTH) / 1024 / 1024, 2), ' MB') AS 'Index Size',
    CONCAT(ROUND((COUNT(*) / (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE())) * 100, 2), '%') AS 'Percentage'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
GROUP BY ENGINE
ORDER BY COUNT(*) DESC;

SELECT '' AS '';

-- MyISAM tables (should be minimal after optimization)
SELECT 'MyISAM Tables (Should be converted to InnoDB/Aria):' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    TABLE_NAME AS 'Table',
    TABLE_ROWS AS 'Rows',
    CONCAT(ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2), ' MB') AS 'Size',
    CASE
        WHEN TABLE_NAME LIKE '%log' THEN 'Convert to Aria TRANSACTIONAL=1'
        WHEN TABLE_NAME IN ('char', 'inventory', 'storage', 'guild', 'guild_member', 'guild_storage', 'login') THEN 'CRITICAL: Convert to InnoDB'
        ELSE 'Consider InnoDB or Aria'
    END AS 'Recommendation'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND ENGINE = 'MyISAM'
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC;

SELECT '' AS '';

-- Check if critical tables are using InnoDB
SELECT 'Critical Tables Engine Check:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    TABLE_NAME AS 'Table',
    ENGINE AS 'Engine',
    CASE
        WHEN ENGINE = 'InnoDB' THEN '✓ OK'
        WHEN ENGINE = 'MyISAM' THEN '✗ NEEDS CONVERSION TO INNODB'
        ELSE '! CHECK ENGINE'
    END AS 'Status'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('char', 'inventory', 'storage', 'cart_inventory', 'guild', 'guild_member', 'guild_storage', 'login', 'mail')
ORDER BY TABLE_NAME;

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 3: CHARACTER ENCODING VERIFICATION
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 3: CHARACTER ENCODING VERIFICATION                              ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Database default character set
SELECT 'Database Character Set:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    DEFAULT_CHARACTER_SET_NAME AS 'Character Set',
    DEFAULT_COLLATION_NAME AS 'Collation',
    CASE 
        WHEN DEFAULT_CHARACTER_SET_NAME = 'utf8mb4' THEN '✓ OK (Full Unicode support)'
        WHEN DEFAULT_CHARACTER_SET_NAME = 'utf8' THEN '⚠ WARNING (Limited Unicode, use utf8mb4)'
        ELSE '✗ NOT RECOMMENDED (Use utf8mb4)'
    END AS 'Status'
FROM information_schema.SCHEMATA
WHERE SCHEMA_NAME = DATABASE();

SELECT '' AS '';

-- Tables with non-utf8mb4 character sets
SELECT 'Tables Not Using utf8mb4:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    TABLE_NAME AS 'Table',
    TABLE_COLLATION AS 'Collation',
    'ALTER TABLE ' || TABLE_NAME || ' CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;' AS 'Fix Command'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_COLLATION NOT LIKE 'utf8mb4%'
LIMIT 20;

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 4: INDEX ANALYSIS
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 4: INDEX ANALYSIS                                               ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Index count per table
SELECT 'Index Count Per Table:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    TABLE_NAME AS 'Table',
    COUNT(DISTINCT INDEX_NAME) AS 'Index Count',
    GROUP_CONCAT(DISTINCT INDEX_NAME ORDER BY INDEX_NAME SEPARATOR ', ') AS 'Indexes'
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
GROUP BY TABLE_NAME
ORDER BY COUNT(DISTINCT INDEX_NAME) DESC
LIMIT 20;

SELECT '' AS '';

-- Tables without indexes (excluding very small tables)
SELECT 'Tables Without Indexes (Potential Performance Issue):' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    t.TABLE_NAME AS 'Table',
    t.TABLE_ROWS AS 'Rows',
    CONCAT(ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1024 / 1024, 2), ' MB') AS 'Size',
    '⚠ Consider adding indexes' AS 'Recommendation'
FROM information_schema.TABLES t
LEFT JOIN information_schema.STATISTICS s 
    ON t.TABLE_SCHEMA = s.TABLE_SCHEMA 
    AND t.TABLE_NAME = s.TABLE_NAME
WHERE t.TABLE_SCHEMA = DATABASE()
  AND t.TABLE_ROWS > 100
  AND s.INDEX_NAME IS NULL
ORDER BY t.TABLE_ROWS DESC;

SELECT '' AS '';

-- Primary key verification
SELECT 'Tables Without Primary Key:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    t.TABLE_NAME AS 'Table',
    t.ENGINE AS 'Engine',
    t.TABLE_ROWS AS 'Rows',
    '✗ CRITICAL: Add primary key for InnoDB performance' AS 'Status'
FROM information_schema.TABLES t
LEFT JOIN information_schema.TABLE_CONSTRAINTS tc
    ON t.TABLE_SCHEMA = tc.TABLE_SCHEMA
    AND t.TABLE_NAME = tc.TABLE_NAME
    AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
WHERE t.TABLE_SCHEMA = DATABASE()
  AND tc.CONSTRAINT_NAME IS NULL
  AND t.ENGINE = 'InnoDB'
ORDER BY t.TABLE_ROWS DESC;

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 5: INNODB BUFFER POOL PERFORMANCE
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 5: INNODB BUFFER POOL PERFORMANCE                               ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Buffer pool size and configuration
SELECT 'Buffer Pool Configuration:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    CONCAT(ROUND(@@innodb_buffer_pool_size / 1024 / 1024 / 1024, 2), ' GB') AS 'Buffer Pool Size',
    @@innodb_buffer_pool_instances AS 'Buffer Pool Instances',
    CONCAT(ROUND(@@innodb_buffer_pool_chunk_size / 1024 / 1024, 2), ' MB') AS 'Chunk Size',
    CASE
        WHEN @@innodb_buffer_pool_size >= 4294967296 THEN '✓ Good (>= 4GB)'
        WHEN @@innodb_buffer_pool_size >= 2147483648 THEN '⚠ Acceptable (>= 2GB)'
        ELSE '✗ Too Small (< 2GB)'
    END AS 'Status';

SELECT '' AS '';

-- Buffer pool hit rate (should be > 99%)
SELECT 'Buffer Pool Hit Rate (Should be > 99%):' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    CONCAT(ROUND(
        100 * (1 - (
            (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') /
            NULLIF((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'), 0)
        )), 2
    ), '%') AS 'Hit Rate',
    CASE
        WHEN ROUND(100 * (1 - (
            (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') /
            NULLIF((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'), 0)
        )), 2) >= 99 THEN '✓ Excellent'
        WHEN ROUND(100 * (1 - (
            (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') /
            NULLIF((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'), 0)
        )), 2) >= 95 THEN '⚠ Good but can improve'
        ELSE '✗ Poor - Increase buffer pool size'
    END AS 'Status';

SELECT '' AS '';

-- Buffer pool usage
SELECT 'Buffer Pool Usage:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_data') AS 'Data Pages',
    (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_free') AS 'Free Pages',
    (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_total') AS 'Total Pages',
    CONCAT(ROUND(
        ((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_data') /
         NULLIF((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_total'), 0)) * 100, 2
    ), '%') AS 'Usage Percentage';

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 6: CONNECTION AND THREAD STATISTICS
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 6: CONNECTION AND THREAD STATISTICS                             ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Connection statistics
SELECT 'Connection Statistics:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Threads_connected') AS 'Current Connections',
    @@max_connections AS 'Max Connections',
    CONCAT(ROUND(
        ((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Threads_connected') /
         @@max_connections) * 100, 2
    ), '%') AS 'Usage Percentage',
    (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Max_used_connections') AS 'Peak Connections',
    CASE
        WHEN ((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Threads_connected') / @@max_connections) < 0.8 THEN '✓ Healthy'
        WHEN ((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Threads_connected') / @@max_connections) < 0.9 THEN '⚠ High usage'
        ELSE '✗ Critical - Consider increasing max_connections'
    END AS 'Status';

SELECT '' AS '';

-- Thread statistics
SELECT 'Thread Pool Status:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    @@thread_handling AS 'Thread Handling',
    CASE
        WHEN @@thread_handling = 'pool-of-threads' THEN '✓ Using thread pool (optimal)'
        ELSE '⚠ Not using thread pool (consider enabling)'
    END AS 'Status',
    @@thread_pool_size AS 'Pool Size',
    @@thread_cache_size AS 'Thread Cache Size';

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 7: TABLE FRAGMENTATION ANALYSIS
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 7: TABLE FRAGMENTATION ANALYSIS                                 ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Fragmented tables (need OPTIMIZE)
SELECT 'Fragmented Tables (Consider OPTIMIZE TABLE):' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    TABLE_NAME AS 'Table',
    ENGINE AS 'Engine',
    CONCAT(ROUND(DATA_FREE / 1024 / 1024, 2), ' MB') AS 'Wasted Space',
    CONCAT(ROUND((DATA_FREE / NULLIF(DATA_LENGTH, 0)) * 100, 2), '%') AS 'Fragmentation %',
    CASE
        WHEN (DATA_FREE / NULLIF(DATA_LENGTH, 0)) > 0.2 THEN '✗ High fragmentation'
        WHEN (DATA_FREE / NULLIF(DATA_LENGTH, 0)) > 0.1 THEN '⚠ Moderate fragmentation'
        ELSE '✓ Low fragmentation'
    END AS 'Status',
    CONCAT('OPTIMIZE TABLE `', TABLE_NAME, '`;') AS 'Fix Command'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND DATA_FREE > 0
  AND (DATA_FREE / NULLIF(DATA_LENGTH, 0)) > 0.1
ORDER BY DATA_FREE DESC
LIMIT 20;

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 8: QUERY PERFORMANCE INDICATORS
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 8: QUERY PERFORMANCE INDICATORS                                 ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Slow query statistics
SELECT 'Slow Query Statistics:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Slow_queries') AS 'Slow Queries',
    @@long_query_time AS 'Slow Query Threshold (seconds)',
    @@slow_query_log AS 'Slow Query Log Enabled',
    CASE
        WHEN @@slow_query_log = 'ON' THEN '✓ Enabled (good for monitoring)'
        ELSE '⚠ Disabled (enable for troubleshooting)'
    END AS 'Status';

SELECT '' AS '';

-- Table scan statistics
SELECT 'Table Scan Statistics (Full Table Scans):' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Select_scan') AS 'Full Table Scans',
    (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Select_full_join') AS 'Full Joins (No Index)',
    CASE
        WHEN (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Select_full_join') > 1000 THEN '⚠ High - Check for missing indexes'
        ELSE '✓ Acceptable'
    END AS 'Status';

SELECT '' AS '';

-- Sort and temporary table statistics
SELECT 'Sort and Temporary Table Statistics:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Sort_merge_passes') AS 'Sort Merge Passes',
    (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Created_tmp_disk_tables') AS 'Temp Tables on Disk',
    (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Created_tmp_tables') AS 'Total Temp Tables',
    CONCAT(ROUND(
        ((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Created_tmp_disk_tables') /
         NULLIF((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Created_tmp_tables'), 0)) * 100, 2
    ), '%') AS 'Disk Temp Table %',
    CASE
        WHEN ((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Created_tmp_disk_tables') /
              NULLIF((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Created_tmp_tables'), 0)) > 0.25 THEN '⚠ High - Increase tmp_table_size'
        ELSE '✓ Acceptable'
    END AS 'Status';

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 9: BINARY LOG AND REPLICATION
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 9: BINARY LOG AND REPLICATION                                   ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Binary log status
SELECT 'Binary Log Status:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    @@log_bin AS 'Binary Logging',
    @@binlog_format AS 'Binlog Format',
    @@max_binlog_size / 1024 / 1024 AS 'Max Binlog Size (MB)',
    @@expire_logs_days AS 'Retention Days',
    CASE
        WHEN @@log_bin = 1 THEN '✓ Enabled (good for recovery/replication)'
        ELSE '⚠ Disabled (enable for production)'
    END AS 'Status';

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 10: RECOMMENDATIONS SUMMARY
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 10: RECOMMENDATIONS SUMMARY                                     ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

SELECT 'Critical Recommendations:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';

-- Dynamic recommendations based on current state
SELECT 
    CONCAT('1. ', 
        CASE 
            WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND ENGINE = 'MyISAM' AND TABLE_NAME IN ('char', 'inventory', 'storage', 'guild', 'login')) > 0
            THEN '✗ CRITICAL: Convert critical tables from MyISAM to InnoDB'
            ELSE '✓ Critical tables using InnoDB'
        END
    ) AS '';

SELECT 
    CONCAT('2. ', 
        CASE 
            WHEN @@innodb_buffer_pool_size < 2147483648
            THEN '✗ CRITICAL: Increase innodb_buffer_pool_size (currently too small)'
            WHEN @@innodb_buffer_pool_size < 4294967296
            THEN '⚠ WARNING: Consider increasing innodb_buffer_pool_size to 4GB+'
            ELSE '✓ Buffer pool size is adequate'
        END
    ) AS '';

SELECT 
    CONCAT('3. ', 
        CASE 
            WHEN (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_COLLATION NOT LIKE 'utf8mb4%') > 0
            THEN '⚠ WARNING: Some tables not using utf8mb4 character set'
            ELSE '✓ All tables using utf8mb4'
        END
    ) AS '';

SELECT 
    CONCAT('4. ', 
        CASE 
            WHEN @@slow_query_log = 'OFF'
            THEN '⚠ INFO: Enable slow query log for performance monitoring'
            ELSE '✓ Slow query log enabled'
        END
    ) AS '';

SELECT 
    CONCAT('5. ', 
        CASE 
            WHEN @@log_bin = 0
            THEN '⚠ WARNING: Enable binary logging for point-in-time recovery'
            ELSE '✓ Binary logging enabled'
        END
    ) AS '';

SELECT '' AS '';

SELECT 'Performance Optimization Recommendations:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT '• Run add_performance_indexes.sql to add strategic indexes' AS '';
SELECT '• Run maintenance.sql regularly (weekly) for table optimization' AS '';
SELECT '• Monitor buffer pool hit rate (should stay > 99%)' AS '';
SELECT '• Review slow query log for optimization opportunities' AS '';
SELECT '• Consider implementing read replicas for reporting queries' AS '';

SELECT '' AS '';

-- ============================================================================
-- FOOTER
-- ============================================================================

SELECT '============================================================================' AS '';
SELECT 'END OF HEALTH CHECK REPORT' AS '';
SELECT '============================================================================' AS '';
SELECT CONCAT('Generated: ', NOW()) AS '';
SELECT '' AS '';
SELECT 'Next Steps:' AS '';
SELECT '  1. Review all sections marked with ✗ (critical issues)' AS '';
SELECT '  2. Address all warnings marked with ⚠' AS '';
SELECT '  3. Run analyze_indexes.sql for detailed index analysis' AS '';
SELECT '  4. Run maintenance.sql for table optimization' AS '';
SELECT '  5. Save this report and compare with future runs' AS '';
SELECT '' AS '';
SELECT 'For detailed recommendations, refer to README.md' AS '';
SELECT '============================================================================' AS '';
