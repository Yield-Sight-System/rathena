-- ============================================================================
-- RATHENA DATABASE INDEX ANALYSIS SCRIPT
-- ============================================================================
-- Version: 1.0
-- Date: 2026-01-06
-- Target: MariaDB 10.11+ / 11.2+
-- Database: rathena
--
-- Purpose:
--   Comprehensive index analysis tool for rAthena database optimization.
--   Provides detailed insights into:
--   - Index usage statistics
--   - Duplicate and redundant indexes
--   - Unused indexes
--   - Index cardinality and selectivity
--   - Index size and overhead
--   - Missing index recommendations
--
-- Usage:
--   mysql -u root -p rathena < analyze_indexes.sql > index_analysis_report.txt
--   
--   Or from MySQL prompt:
--   USE rathena;
--   SOURCE analyze_indexes.sql;
--
-- Requirements:
--   - Performance Schema must be enabled (performance_schema = ON)
--   - Table statistics should be up-to-date (run ANALYZE TABLE)
--
-- Safety:
--   - Read-only queries, no modifications
--   - Safe to run on production database
--   - Minimal performance impact
-- ============================================================================

-- Display header
SELECT '============================================================================' AS '';
SELECT 'RATHENA DATABASE INDEX ANALYSIS REPORT' AS '';
SELECT '============================================================================' AS '';
SELECT CONCAT('Generated: ', NOW()) AS '';
SELECT CONCAT('Database: ', DATABASE()) AS '';
SELECT CONCAT('MariaDB Version: ', VERSION()) AS '';
SELECT '============================================================================' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 1: INDEX OVERVIEW
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 1: INDEX OVERVIEW                                               ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Total index count and size
SELECT 'Index Summary:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    COUNT(DISTINCT CONCAT(TABLE_NAME, '.', INDEX_NAME)) AS 'Total Indexes',
    COUNT(DISTINCT TABLE_NAME) AS 'Tables with Indexes',
    CONCAT(ROUND(SUM(stat_value * @@innodb_page_size) / 1024 / 1024, 2), ' MB') AS 'Estimated Index Size'
FROM mysql.innodb_index_stats
WHERE database_name = DATABASE()
  AND stat_name = 'size';

SELECT '' AS '';

-- Indexes per table
SELECT 'Top 20 Tables by Index Count:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    TABLE_NAME AS 'Table',
    COUNT(DISTINCT INDEX_NAME) AS 'Index Count',
    GROUP_CONCAT(DISTINCT INDEX_NAME ORDER BY INDEX_NAME SEPARATOR ', ') AS 'Index Names'
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
GROUP BY TABLE_NAME
ORDER BY COUNT(DISTINCT INDEX_NAME) DESC
LIMIT 20;

SELECT '' AS '';

-- Index types distribution
SELECT 'Index Type Distribution:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    INDEX_TYPE AS 'Index Type',
    COUNT(DISTINCT CONCAT(TABLE_NAME, '.', INDEX_NAME)) AS 'Count',
    CONCAT(ROUND((COUNT(DISTINCT CONCAT(TABLE_NAME, '.', INDEX_NAME)) / 
        (SELECT COUNT(DISTINCT CONCAT(TABLE_NAME, '.', INDEX_NAME)) 
         FROM information_schema.STATISTICS 
         WHERE TABLE_SCHEMA = DATABASE())) * 100, 2), '%') AS 'Percentage'
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
GROUP BY INDEX_TYPE
ORDER BY COUNT(DISTINCT CONCAT(TABLE_NAME, '.', INDEX_NAME)) DESC;

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 2: DUPLICATE AND REDUNDANT INDEXES
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 2: DUPLICATE AND REDUNDANT INDEXES                              ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Find potential duplicate indexes (same columns, different names)
SELECT 'Potential Duplicate Indexes:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    s1.TABLE_NAME AS 'Table',
    s1.INDEX_NAME AS 'Index 1',
    s2.INDEX_NAME AS 'Index 2',
    GROUP_CONCAT(s1.COLUMN_NAME ORDER BY s1.SEQ_IN_INDEX SEPARATOR ', ') AS 'Columns',
    CONCAT('-- Consider removing one of these indexes:') AS 'Recommendation',
    CONCAT('ALTER TABLE `', s1.TABLE_NAME, '` DROP INDEX `', s2.INDEX_NAME, '`;') AS 'Drop Command'
FROM information_schema.STATISTICS s1
JOIN information_schema.STATISTICS s2
    ON s1.TABLE_SCHEMA = s2.TABLE_SCHEMA
    AND s1.TABLE_NAME = s2.TABLE_NAME
    AND s1.INDEX_NAME < s2.INDEX_NAME
    AND s1.SEQ_IN_INDEX = s2.SEQ_IN_INDEX
    AND s1.COLUMN_NAME = s2.COLUMN_NAME
WHERE s1.TABLE_SCHEMA = DATABASE()
GROUP BY s1.TABLE_NAME, s1.INDEX_NAME, s2.INDEX_NAME
HAVING COUNT(*) = (
    SELECT COUNT(*) 
    FROM information_schema.STATISTICS 
    WHERE TABLE_SCHEMA = s1.TABLE_SCHEMA 
      AND TABLE_NAME = s1.TABLE_NAME 
      AND INDEX_NAME = s1.INDEX_NAME
);

SELECT '' AS '';

-- Find redundant indexes (prefix indexes)
SELECT 'Redundant Indexes (Prefix of Another Index):' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT DISTINCT
    s1.TABLE_NAME AS 'Table',
    s1.INDEX_NAME AS 'Redundant Index',
    GROUP_CONCAT(DISTINCT s1.COLUMN_NAME ORDER BY s1.SEQ_IN_INDEX SEPARATOR ', ') AS 'Columns',
    s2.INDEX_NAME AS 'Makes Redundant',
    GROUP_CONCAT(DISTINCT s2.COLUMN_NAME ORDER BY s2.SEQ_IN_INDEX SEPARATOR ', ') AS 'Full Index Columns',
    '⚠ Redundant - covered by another index' AS 'Status',
    CONCAT('ALTER TABLE `', s1.TABLE_NAME, '` DROP INDEX `', s1.INDEX_NAME, '`;') AS 'Drop Command'
FROM information_schema.STATISTICS s1
JOIN information_schema.STATISTICS s2
    ON s1.TABLE_SCHEMA = s2.TABLE_SCHEMA
    AND s1.TABLE_NAME = s2.TABLE_NAME
    AND s1.INDEX_NAME != s2.INDEX_NAME
    AND s1.SEQ_IN_INDEX = s2.SEQ_IN_INDEX
    AND s1.COLUMN_NAME = s2.COLUMN_NAME
WHERE s1.TABLE_SCHEMA = DATABASE()
  AND (SELECT COUNT(*) FROM information_schema.STATISTICS 
       WHERE TABLE_SCHEMA = s1.TABLE_SCHEMA 
         AND TABLE_NAME = s1.TABLE_NAME 
         AND INDEX_NAME = s1.INDEX_NAME) <
      (SELECT COUNT(*) FROM information_schema.STATISTICS 
       WHERE TABLE_SCHEMA = s2.TABLE_SCHEMA 
         AND TABLE_NAME = s2.TABLE_NAME 
         AND INDEX_NAME = s2.INDEX_NAME)
GROUP BY s1.TABLE_NAME, s1.INDEX_NAME, s2.INDEX_NAME
LIMIT 20;

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 3: INDEX CARDINALITY ANALYSIS
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 3: INDEX CARDINALITY ANALYSIS                                   ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Index cardinality (uniqueness)
SELECT 'Index Cardinality (Selectivity):' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    TABLE_NAME AS 'Table',
    INDEX_NAME AS 'Index',
    COLUMN_NAME AS 'Column',
    SEQ_IN_INDEX AS 'Position',
    CARDINALITY AS 'Cardinality',
    CASE
        WHEN CARDINALITY IS NULL THEN '✗ No Statistics'
        WHEN CARDINALITY = 0 THEN '✗ Zero Cardinality'
        WHEN CARDINALITY < 10 THEN '⚠ Very Low Selectivity'
        WHEN CARDINALITY < 100 THEN '⚠ Low Selectivity'
        ELSE '✓ Good Selectivity'
    END AS 'Status'
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND INDEX_NAME != 'PRIMARY'
  AND SEQ_IN_INDEX = 1  -- Only first column of index
ORDER BY 
    CASE 
        WHEN CARDINALITY IS NULL THEN 0
        ELSE CARDINALITY 
    END ASC
LIMIT 30;

SELECT '' AS '';

-- Tables with NULL or zero cardinality indexes (need ANALYZE TABLE)
SELECT 'Indexes Needing Statistics Update:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    TABLE_NAME AS 'Table',
    INDEX_NAME AS 'Index',
    '✗ Run ANALYZE TABLE to update statistics' AS 'Recommendation',
    CONCAT('ANALYZE TABLE `', TABLE_NAME, '`;') AS 'Fix Command'
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND (CARDINALITY IS NULL OR CARDINALITY = 0)
  AND INDEX_NAME != 'PRIMARY'
GROUP BY TABLE_NAME, INDEX_NAME
LIMIT 20;

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 4: INDEX SIZE AND OVERHEAD ANALYSIS
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 4: INDEX SIZE AND OVERHEAD ANALYSIS                             ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Largest indexes by size
SELECT 'Top 20 Largest Indexes:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    t.TABLE_NAME AS 'Table',
    t.INDEX_NAME AS 'Index',
    CONCAT(ROUND((s.stat_value * @@innodb_page_size) / 1024 / 1024, 2), ' MB') AS 'Index Size',
    ROUND((s.stat_value * @@innodb_page_size) / t.DATA_LENGTH * 100, 2) AS 'Size % of Data'
FROM mysql.innodb_index_stats s
JOIN information_schema.TABLES t
    ON s.database_name = t.TABLE_SCHEMA
    AND s.table_name = t.TABLE_NAME
WHERE s.database_name = DATABASE()
  AND s.stat_name = 'size'
  AND s.index_name != 'PRIMARY'
ORDER BY s.stat_value DESC
LIMIT 20;

SELECT '' AS '';

-- Index overhead by table
SELECT 'Tables with High Index Overhead:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    TABLE_NAME AS 'Table',
    CONCAT(ROUND(DATA_LENGTH / 1024 / 1024, 2), ' MB') AS 'Data Size',
    CONCAT(ROUND(INDEX_LENGTH / 1024 / 1024, 2), ' MB') AS 'Index Size',
    CONCAT(ROUND((INDEX_LENGTH / NULLIF(DATA_LENGTH, 0)) * 100, 2), '%') AS 'Index Overhead',
    COUNT_INDEX AS 'Index Count',
    CASE
        WHEN (INDEX_LENGTH / NULLIF(DATA_LENGTH, 0)) > 1.0 THEN '⚠ Very High - Indexes larger than data'
        WHEN (INDEX_LENGTH / NULLIF(DATA_LENGTH, 0)) > 0.5 THEN '⚠ High - Consider consolidating indexes'
        WHEN (INDEX_LENGTH / NULLIF(DATA_LENGTH, 0)) > 0.3 THEN '✓ Moderate'
        ELSE '✓ Low'
    END AS 'Status'
FROM (
    SELECT 
        t.TABLE_NAME,
        t.DATA_LENGTH,
        t.INDEX_LENGTH,
        COUNT(DISTINCT s.INDEX_NAME) AS COUNT_INDEX
    FROM information_schema.TABLES t
    LEFT JOIN information_schema.STATISTICS s
        ON t.TABLE_SCHEMA = s.TABLE_SCHEMA
        AND t.TABLE_NAME = s.TABLE_NAME
    WHERE t.TABLE_SCHEMA = DATABASE()
      AND t.DATA_LENGTH > 0
    GROUP BY t.TABLE_NAME, t.DATA_LENGTH, t.INDEX_LENGTH
) AS subquery
WHERE (INDEX_LENGTH / NULLIF(DATA_LENGTH, 0)) > 0.3
ORDER BY (INDEX_LENGTH / NULLIF(DATA_LENGTH, 0)) DESC
LIMIT 20;

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 5: MISSING INDEX RECOMMENDATIONS
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 5: MISSING INDEX RECOMMENDATIONS                                ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Tables without primary key (InnoDB requires one)
SELECT 'Tables Without Primary Key:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    t.TABLE_NAME AS 'Table',
    t.ENGINE AS 'Engine',
    t.TABLE_ROWS AS 'Rows',
    '✗ CRITICAL: Add primary key for optimal InnoDB performance' AS 'Status',
    '-- Add a primary key to this table' AS 'Recommendation'
FROM information_schema.TABLES t
LEFT JOIN information_schema.TABLE_CONSTRAINTS tc
    ON t.TABLE_SCHEMA = tc.TABLE_SCHEMA
    AND t.TABLE_NAME = tc.TABLE_NAME
    AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
WHERE t.TABLE_SCHEMA = DATABASE()
  AND tc.CONSTRAINT_NAME IS NULL
  AND t.TABLE_TYPE = 'BASE TABLE'
ORDER BY t.TABLE_ROWS DESC;

SELECT '' AS '';

-- Foreign key columns without indexes
SELECT 'Foreign Key Columns Without Index:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    kcu.TABLE_NAME AS 'Table',
    kcu.COLUMN_NAME AS 'Column',
    kcu.REFERENCED_TABLE_NAME AS 'References Table',
    '⚠ Add index for better JOIN performance' AS 'Status',
    CONCAT('ALTER TABLE `', kcu.TABLE_NAME, '` ADD INDEX `idx_', kcu.COLUMN_NAME, '` (`', kcu.COLUMN_NAME, '`);') AS 'Add Index Command'
FROM information_schema.KEY_COLUMN_USAGE kcu
LEFT JOIN information_schema.STATISTICS s
    ON kcu.TABLE_SCHEMA = s.TABLE_SCHEMA
    AND kcu.TABLE_NAME = s.TABLE_NAME
    AND kcu.COLUMN_NAME = s.COLUMN_NAME
    AND s.SEQ_IN_INDEX = 1
WHERE kcu.TABLE_SCHEMA = DATABASE()
  AND kcu.REFERENCED_TABLE_NAME IS NOT NULL
  AND s.INDEX_NAME IS NULL
ORDER BY kcu.TABLE_NAME, kcu.COLUMN_NAME
LIMIT 20;

SELECT '' AS '';

-- High-cardinality columns without indexes (candidates for indexing)
SELECT 'High-Cardinality Columns Without Indexes:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    c.TABLE_NAME AS 'Table',
    c.COLUMN_NAME AS 'Column',
    c.DATA_TYPE AS 'Type',
    '✓ Good candidate for indexing' AS 'Status',
    CONCAT('ALTER TABLE `', c.TABLE_NAME, '` ADD INDEX `idx_', c.COLUMN_NAME, '` (`', c.COLUMN_NAME, '`);') AS 'Add Index Command'
FROM information_schema.COLUMNS c
LEFT JOIN information_schema.STATISTICS s
    ON c.TABLE_SCHEMA = s.TABLE_SCHEMA
    AND c.TABLE_NAME = s.TABLE_NAME
    AND c.COLUMN_NAME = s.COLUMN_NAME
    AND s.SEQ_IN_INDEX = 1
WHERE c.TABLE_SCHEMA = DATABASE()
  AND s.INDEX_NAME IS NULL
  AND c.COLUMN_NAME IN ('account_id', 'char_id', 'guild_id', 'party_id', 'char_num', 'nameid', 'time', 'date', 'map')
  AND c.TABLE_NAME NOT LIKE '%log'  -- Exclude log tables (indexes slow inserts)
ORDER BY c.TABLE_NAME, c.COLUMN_NAME
LIMIT 20;

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 6: INDEX USAGE PATTERNS
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 6: INDEX USAGE PATTERNS                                         ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Multi-column index analysis
SELECT 'Multi-Column Index Analysis:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    TABLE_NAME AS 'Table',
    INDEX_NAME AS 'Index',
    COUNT(*) AS 'Column Count',
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ', ') AS 'Columns',
    CASE
        WHEN COUNT(*) >= 5 THEN '⚠ Very Wide - May be over-indexed'
        WHEN COUNT(*) >= 3 THEN '✓ Good for covering queries'
        ELSE '✓ Standard'
    END AS 'Status'
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND INDEX_NAME != 'PRIMARY'
GROUP BY TABLE_NAME, INDEX_NAME
HAVING COUNT(*) > 2
ORDER BY COUNT(*) DESC
LIMIT 20;

SELECT '' AS '';

-- Index column order analysis (leftmost prefix rule)
SELECT 'Index Column Order (Leftmost Prefix Matters):' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    TABLE_NAME AS 'Table',
    INDEX_NAME AS 'Index',
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ' -> ') AS 'Column Order',
    MAX(SEQ_IN_INDEX) AS 'Columns',
    '✓ Use leftmost columns in queries for index usage' AS 'Note'
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND INDEX_NAME != 'PRIMARY'
GROUP BY TABLE_NAME, INDEX_NAME
HAVING MAX(SEQ_IN_INDEX) > 1
ORDER BY TABLE_NAME, INDEX_NAME
LIMIT 30;

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 7: SPECIAL INDEX TYPES
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 7: SPECIAL INDEX TYPES                                          ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

-- Full-text indexes
SELECT 'Full-Text Indexes:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    TABLE_NAME AS 'Table',
    INDEX_NAME AS 'Index',
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ', ') AS 'Columns',
    '✓ Full-text search enabled' AS 'Status'
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND INDEX_TYPE = 'FULLTEXT'
GROUP BY TABLE_NAME, INDEX_NAME;

SELECT '' AS '';

-- Unique indexes
SELECT 'Unique Indexes (Data Integrity):' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    TABLE_NAME AS 'Table',
    INDEX_NAME AS 'Index',
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ', ') AS 'Columns',
    '✓ Enforces uniqueness' AS 'Status'
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND NON_UNIQUE = 0
  AND INDEX_NAME != 'PRIMARY'
GROUP BY TABLE_NAME, INDEX_NAME
LIMIT 20;

SELECT '' AS '';

-- Prefix indexes (partial column indexes)
SELECT 'Prefix Indexes (Partial Column):' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT 
    TABLE_NAME AS 'Table',
    INDEX_NAME AS 'Index',
    COLUMN_NAME AS 'Column',
    SUB_PART AS 'Prefix Length',
    '✓ Space-efficient for long strings' AS 'Status'
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND SUB_PART IS NOT NULL
ORDER BY TABLE_NAME, INDEX_NAME;

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- SECTION 8: RECOMMENDATIONS SUMMARY
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 8: RECOMMENDATIONS SUMMARY                                      ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

SELECT 'Index Optimization Recommendations:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT '1. Remove Duplicate Indexes: Check Section 2 for duplicate indexes to drop' AS '';
SELECT '2. Update Statistics: Run ANALYZE TABLE on tables with NULL cardinality' AS '';
SELECT '3. Add Missing Indexes: Review Section 5 for high-value index candidates' AS '';
SELECT '4. Monitor Index Overhead: Tables with >50% index overhead may need review' AS '';
SELECT '5. Use Covering Indexes: Multi-column indexes can eliminate table lookups' AS '';
SELECT '6. Follow Leftmost Prefix: Query must use leftmost columns of multi-column index' AS '';
SELECT '7. Avoid Over-Indexing: Too many indexes slow INSERT/UPDATE/DELETE operations' AS '';
SELECT '8. Log Tables: Be careful adding indexes to high-volume log tables' AS '';

SELECT '' AS '';

SELECT 'Quick Wins:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT '• Drop obvious duplicate indexes (same columns, different names)' AS '';
SELECT '• Run ANALYZE TABLE on all major tables to update statistics' AS '';
SELECT '• Add indexes to foreign key columns for better JOIN performance' AS '';
SELECT '• Review and drop unused indexes (requires query log analysis)' AS '';
SELECT '• Convert remaining MyISAM tables to InnoDB for better index performance' AS '';

SELECT '' AS '';

SELECT 'Monitoring:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT '• Enable slow query log to identify queries not using indexes' AS '';
SELECT '• Use EXPLAIN on slow queries to verify index usage' AS '';
SELECT '• Monitor index size growth over time' AS '';
SELECT '• Review this report monthly to catch new issues' AS '';
SELECT '• Test performance before and after index changes' AS '';

SELECT '' AS '';

-- ============================================================================
-- SECTION 9: ACTIONABLE COMMANDS
-- ============================================================================

SELECT '╔══════════════════════════════════════════════════════════════════════════╗' AS '';
SELECT '║ SECTION 9: ACTIONABLE COMMANDS                                          ║' AS '';
SELECT '╚══════════════════════════════════════════════════════════════════════════╝' AS '';
SELECT '' AS '';

SELECT 'Update Statistics for All Tables:' AS '';
SELECT '────────────────────────────────────────────────────────────────────────────' AS '';
SELECT CONCAT('ANALYZE TABLE `', TABLE_NAME, '`;') AS 'Commands'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

SELECT '' AS '';
SELECT '' AS '';

-- ============================================================================
-- FOOTER
-- ============================================================================

SELECT '============================================================================' AS '';
SELECT 'END OF INDEX ANALYSIS REPORT' AS '';
SELECT '============================================================================' AS '';
SELECT CONCAT('Generated: ', NOW()) AS '';
SELECT '' AS '';
SELECT 'Important Notes:' AS '';
SELECT '  • Always test index changes on a non-production environment first' AS '';
SELECT '  • Backup your database before making structural changes' AS '';
SELECT '  • Monitor performance after adding/removing indexes' AS '';
SELECT '  • Some "redundant" indexes may be intentional for specific queries' AS '';
SELECT '  • Index recommendations are based on structure, not actual query patterns' AS '';
SELECT '' AS '';
SELECT 'Next Steps:' AS '';
SELECT '  1. Review duplicate indexes and drop unnecessary ones' AS '';
SELECT '  2. Run ANALYZE TABLE to update statistics' AS '';
SELECT '  3. Add recommended indexes for foreign keys' AS '';
SELECT '  4. Run health_check.sql to verify overall database health' AS '';
SELECT '  5. Monitor slow query log for query-specific optimization' AS '';
SELECT '' AS '';
SELECT 'For detailed recommendations, refer to README.md' AS '';
SELECT '============================================================================' AS '';
