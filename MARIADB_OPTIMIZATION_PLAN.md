# MariaDB Optimization Plan for rAthena Database System

**Document Version:** 1.0  
**Date:** 2026-01-06  
**Target System:** rAthena Game Server Database  
**Current State:** 77/81 tables using MyISAM, 1 InnoDB, 3 unspecified

---

## Executive Summary

### Critical Assessment

The rathena database system is currently running in a **HIGH-RISK configuration** with 95% of tables (77/81) using the MyISAM storage engine. This presents severe risks for a production game server:

- **Data Corruption Risk:** MyISAM has no crash recovery - server crashes can corrupt tables
- **Concurrency Bottleneck:** Table-level locking limits concurrent player operations
- **Transaction Safety:** No ACID compliance for critical operations (inventory, zeny, character data)
- **Integrity Issues:** No foreign key constraints to maintain data consistency

### Recommended MariaDB Version

**Primary Recommendation: MariaDB 10.11 LTS**
- **Support:** Until February 2028
- **Stability:** Production-hardened, extensive testing
- **Features:** All necessary optimizations for game servers
- **Best For:** Production game servers requiring stability

**Alternative: MariaDB 11.2 Stable** (for bleeding-edge features)
- **Support:** Short-term releases (6 months between versions)
- **Features:** Latest performance improvements, instant DDL
- **Best For:** Testing environments or servers wanting cutting-edge features

### Top 5 Optimization Priorities

1. **Convert Critical Transactional Tables to InnoDB** (Priority: CRITICAL)
   - Tables: `char`, `inventory`, `storage`, `login`, `guild`, `party`
   - Impact: Prevents data loss, enables concurrent operations
   - Risk: Low (with proper testing)

2. **Optimize InnoDB Configuration for Game Workloads** (Priority: HIGH)
   - Buffer pool sizing, thread concurrency, I/O optimization
   - Impact: 2-5x performance improvement
   - Risk: Low (configuration only)

3. **Convert Logging Tables to Aria** (Priority: HIGH)
   - Tables: `atcommandlog`, `chatlog`, `picklog`, `zenylog`, `mvplog`
   - Impact: Better crash safety without InnoDB overhead
   - Risk: Low (logs are append-only)

4. **Add Strategic Indexes** (Priority: MEDIUM)
   - Multi-column indexes for common query patterns
   - Impact: 10-50x faster queries
   - Risk: Low (online index creation)

5. **Implement Temporal Tables for Audit** (Priority: MEDIUM)
   - System-versioned tables for character/inventory history
   - Impact: Built-in audit trail, rollback capability
   - Risk: Medium (new feature, needs testing)

### Expected Overall Performance Improvement

- **Concurrency:** 3-10x improvement (table locks → row locks)
- **Write Performance:** 2-4x improvement (InnoDB optimizations)
- **Read Performance:** 1.5-3x improvement (better caching, indexing)
- **Crash Recovery:** From hours/days → minutes (automatic recovery)
- **Data Safety:** From "hope for the best" → ACID guarantees

### Key Risks to Be Aware Of

1. **Migration Downtime:** 15-60 minutes for engine conversion (depends on table size)
2. **Storage Space:** InnoDB uses ~1.5-2x space compared to MyISAM initially
3. **Memory Requirements:** InnoDB requires proper buffer pool sizing (minimum 512MB-2GB)
4. **Application Testing:** All game operations must be tested post-migration
5. **Rollback Complexity:** Engine conversion is one-way (backup critical before starting)

---

## A. MariaDB Version Analysis

### MariaDB 10.11 LTS (Recommended)

**Version:** 10.11.9 (latest patch as of 2026-01)  
**Support:** Until February 2028  
**Stability:** Production-Ready

#### Key Features for rAthena

1. **InnoDB Improvements**
   - Adaptive hash index enhancements
   - Better thread concurrency (up to 1000 threads)
   - Improved buffer pool prefetching
   - Optimized redo log handling

2. **Performance Features**
   - Thread pool for connection handling (Enterprise)
   - Improved subquery optimization
   - Better query caching strategies
   - Histogram statistics for query optimization

3. **Operational Features**
   - Online DDL (ALTER TABLE without blocking)
   - Instant ADD COLUMN for InnoDB
   - Improved backup consistency
   - Better monitoring and diagnostics

4. **Security**
   - Authentication plugin improvements
   - Better password validation
   - Role-based access control

#### Why 10.11 LTS for rAthena?

- **Stability:** 2+ years of production hardening
- **Support:** Long-term security updates and bug fixes
- **Community:** Large user base, well-documented issues
- **Compatibility:** Proven compatibility with existing tools
- **Predictability:** No surprises from bleeding-edge features

### MariaDB 11.2 Stable (Alternative)

**Version:** 11.2.x series  
**Support:** Short-term (6-month release cycle)  
**Stability:** Stable, but newer

#### Additional Features vs 10.11

1. **Enhanced InnoDB**
   - Better parallel index builds
   - Improved compression algorithms
   - Enhanced MVCC (Multi-Version Concurrency Control)
   - Better large transaction handling

2. **Advanced SQL Features**
   - Improved JSON functions
   - Enhanced window functions
   - Better Common Table Expression (CTE) optimization
   - Recursive query improvements

3. **Performance**
   - Faster metadata operations
   - Improved statistics collection
   - Better connection handling
   - Enhanced query parallelization

#### When to Consider 11.2?

- Running a test/development server
- Want latest performance improvements
- Have resources to upgrade every 6 months
- Need specific new features not in 10.11

### Key Differences Affecting rAthena

| Feature | 10.11 LTS | 11.2 Stable | Impact on rAthena |
|---------|-----------|-------------|-------------------|
| InnoDB Buffer Pool | Excellent | Excellent+ | High - Both handle game workloads well |
| Thread Concurrency | 1000+ | 1000+ | High - Both support many concurrent players |
| Online DDL | Full | Full+ | Medium - Schema changes without downtime |
| Instant ALTER | Most ops | More ops | Medium - Faster schema evolution |
| JSON Functions | Good | Better | Low - Limited use in game data |
| Support Duration | 5 years | 6 months | High - Production servers need LTS |
| Battle-Tested | Yes | Newer | High - Stability critical for games |

### Version Recommendation Matrix

| Server Type | Recommended | Reason |
|-------------|-------------|--------|
| **Production (Live Players)** | MariaDB 10.11 LTS | Stability, long-term support, proven track record |
| **Production (New Setup)** | MariaDB 10.11 LTS | Lower risk, well-documented |
| **Staging/Testing** | MariaDB 11.2 Stable | Test new features, prepare for future |
| **Development** | MariaDB 11.2 Stable | Latest features, faster iteration |
| **Legacy Migration** | MariaDB 10.11 LTS | Easier migration path, less change |

---

## B. Storage Engine Optimization

### Current State Analysis

From [`rathena/sql-files/main.sql`](sql-files/main.sql:1) and [`rathena/sql-files/logs.sql`](sql-files/logs.sql:1):

- **Total Tables:** 81 (68 core + 10 logging + 3 web)
- **MyISAM:** 77 tables (95%)
- **InnoDB:** 1 table (`bonus_script`)
- **Unspecified:** 3 tables

### Storage Engine Comparison for Game Servers

| Feature | InnoDB | MyISAM | Aria | ColumnStore |
|---------|--------|--------|------|-------------|
| **ACID Transactions** | ✅ Yes | ❌ No | ⚠️ Optional | ❌ No |
| **Crash Recovery** | ✅ Automatic | ❌ Manual | ✅ Automatic | ✅ Automatic |
| **Locking** | 🟢 Row-level | 🔴 Table-level | 🔴 Table-level | 🟡 Block-level |
| **Concurrency** | 🟢 Excellent | 🔴 Poor | 🟡 Fair | 🟢 Good (reads) |
| **Foreign Keys** | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Full-Text Search** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| **Compression** | ✅ Yes | ⚠️ Static | ⚠️ Static | ✅ Yes |
| **Memory Usage** | 🔴 Higher | 🟢 Lower | 🟡 Medium | 🔴 Higher |
| **Write Performance** | 🟢 Good | 🟡 Fair | 🟡 Fair | 🔴 Poor |
| **Read Performance** | 🟢 Good | 🟢 Good | 🟢 Good | 🟢 Excellent |
| **Best For** | Transactional | Read-heavy | Mixed | Analytics |

### InnoDB Improvements in Latest MariaDB

#### 1. Buffer Pool Enhancements

```ini
# Modern InnoDB buffer pool configuration
[mysqld]
# Core buffer pool settings
innodb_buffer_pool_size = 2G                    # 50-80% of RAM
innodb_buffer_pool_instances = 8                # 1 per GB, max 64
innodb_buffer_pool_chunk_size = 128M            # Resize granularity

# Buffer pool optimization
innodb_adaptive_hash_index = 1                  # Auto-optimize hot data
innodb_adaptive_flushing = 1                    # Dynamic checkpoint
innodb_change_buffering = all                   # Buffer secondary index changes
```

**Impact on rAthena:**
- Caches character data, inventory, guild information in memory
- Reduces disk I/O for frequently accessed players
- Faster login, logout, item operations

#### 2. Redo Log Improvements

```ini
# Redo log configuration for game servers
innodb_log_file_size = 512M                     # Larger = less checkpoints
innodb_log_files_in_group = 2                   # Standard is fine
innodb_log_buffer_size = 16M                    # Buffer before flush
innodb_flush_log_at_trx_commit = 1              # Full ACID (1), Fast (2)
```

**Options for `innodb_flush_log_at_trx_commit`:**
- **1** (ACID): Flush every commit - safest, slower
- **2** (Fast): Flush every second - faster, risk losing 1 sec of data
- **0** (Fastest): No guarantee - fastest, can lose data on crash

**Recommendation for rAthena:** Use **1** for production, **2** for testing

#### 3. Compression Features

```sql
-- Create compressed table (50-60% space savings)
CREATE TABLE inventory (
    id INT AUTO_INCREMENT PRIMARY KEY,
    char_id INT,
    nameid INT,
    amount INT,
    -- ... other columns ...
    KEY (char_id)
) ENGINE=InnoDB 
ROW_FORMAT=COMPRESSED 
KEY_BLOCK_SIZE=8;  -- 1, 2, 4, 8, or 16 KB

-- Alter existing table to use compression
ALTER TABLE inventory ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;
```

**Trade-offs:**
- ✅ 50-70% storage reduction
- ✅ Less I/O (smaller data on disk)
- ❌ 5-15% CPU overhead for compression/decompression
- ❌ Reduced buffer pool efficiency

**Recommendation:** Use for large tables: `inventory`, `storage`, `cart_inventory`, `guild_storage`

#### 4. Full-Text Search Capabilities

```sql
-- Add full-text index for chat search
ALTER TABLE chatlog ADD FULLTEXT INDEX ft_message (message);

-- Search chat history
SELECT * FROM chatlog 
WHERE MATCH(message) AGAINST('looking for party' IN NATURAL LANGUAGE MODE);

-- Boolean search
SELECT * FROM chatlog 
WHERE MATCH(message) AGAINST('+WTB +card -fake' IN BOOLEAN MODE);
```

**Use Cases in rAthena:**
- Search chat logs for GM investigations
- Find trade messages
- Search NPC logs
- Full-text search in web interface

### MyISAM to InnoDB Migration Strategy

#### Tables That MUST Convert (Critical Priority)

These tables handle transactional operations where data loss is unacceptable:

1. **`char`** - Character data (levels, stats, position)
   - **Why:** Character deletion/rollback without proper transactions = data loss
   - **Risk:** Losing player progress due to crash during save
   - **Concurrency:** Multiple characters from same account accessing simultaneously

2. **`inventory`** - Player inventory items
   - **Why:** Item duplication bugs, loss of rare items
   - **Risk:** HIGH - table locks during trades can cause timeouts
   - **Concurrency:** Continuous updates during gameplay

3. **`storage`** - Player storage items
   - **Why:** Same as inventory - valuable items can be lost
   - **Risk:** HIGH - corrupted storage = player complaints
   - **Concurrency:** Medium

4. **`cart_inventory`** - Merchant cart items
   - **Why:** Same as inventory
   - **Risk:** MEDIUM - less critical but still transactional
   - **Concurrency:** Medium

5. **`login`** - Account credentials
   - **Why:** Security - account data corruption can lock out players
   - **Risk:** HIGH - authentication failures affect all players
   - **Concurrency:** HIGH - every login touches this table

6. **`guild`** - Guild information
   - **Why:** Guild operations are transactional (level up, member changes)
   - **Risk:** MEDIUM - guild data loss affects many players
   - **Concurrency:** HIGH - guild operations from multiple members

7. **`guild_member`** - Guild membership
   - **Why:** Consistency with guild table, transactions
   - **Risk:** MEDIUM - orphaned members, wrong guild associations
   - **Concurrency:** HIGH

8. **`guild_storage`** - Guild warehouse
   - **Why:** Same as player storage but affects entire guild
   - **Risk:** HIGH - shared resource, many concurrent operations
   - **Concurrency:** VERY HIGH

9. **`party`** - Party information
   - **Why:** Party operations are transactional
   - **Risk:** LOW-MEDIUM - less critical than guild
   - **Concurrency:** MEDIUM

10. **`mail`** - Player mail system
    - **Why:** Transactional (send/receive/attachments)
    - **Risk:** MEDIUM - lost mail = lost items/zeny
    - **Concurrency:** MEDIUM

#### Tables That SHOULD Convert (High Priority)

These benefit significantly from InnoDB's features:

11. **`auction`** - Auction house
12. **`skill`** - Character skills
13. **`quest`** - Quest progress
14. **`achievement`** - Achievement tracking
15. **`friends`** - Friend lists
16. **`memo`** - Warp memo points
17. **`hotkey`** - Player hotkeys
18. **`pet`**, **`homunculus`**, **`mercenary`**, **`elemental`** - Companion data
19. **`vendings`**, **`vending_items`** - Player shops
20. **`buyingstores`**, **`buyingstore_items`** - Buying stores

#### Tables That MAY Stay MyISAM or Use Aria (Medium Priority)

These are less critical or don't benefit as much from InnoDB:

- **`*_reg_num`**, **`*_reg_str`** - Variable storage (consider Aria)
- **`barter`**, **`market`**, **`sales`** - Shop persistence (consider Aria)
- **`db_roulette`** - Roulette configuration (read-only, Aria fine)
- **`clan`**, **`clan_alliance`** - Clan data (low update frequency, Aria fine)
- **`ipbanlist`** - IP bans (consider Aria or keep MyISAM)
- **`mapreg`** - Map registry (consider Aria)

#### Logging Tables: Consider Aria or ColumnStore

**Logging Tables (10 tables):**
- `atcommandlog` - GM command log
- `branchlog` - Dead branch usage
- `cashlog` - Cash shop transactions
- `chatlog` - Chat messages
- `feedinglog` - Pet/homunculus feeding
- `loginlog` - Login attempts
- `mvplog` - MVP kills
- `npclog` - NPC interactions
- `picklog` - Item pickup/drop
- `zenylog` - Zeny transactions

**Recommendation: Aria Engine**

```sql
-- Convert logging table to Aria with crash-safe option
ALTER TABLE chatlog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE picklog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE zenylog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE atcommandlog ENGINE=Aria TRANSACTIONAL=1;
```

**Why Aria for Logs:**
- ✅ Crash-safe (better than MyISAM)
- ✅ Lower overhead than InnoDB
- ✅ Good insert performance
- ✅ Table-level locks acceptable (append-only)
- ✅ Smaller footprint

**Alternative: ColumnStore for Analytics**

For very large logging tables (millions of rows), consider ColumnStore:

```sql
-- Create ColumnStore table for historical logs
CREATE TABLE chatlog_archive (
    id BIGINT,
    time DATETIME,
    type ENUM('O','W','P','G','M','C'),
    -- ... other columns ...
) ENGINE=ColumnStore;

-- Partition by date for easier management
ALTER TABLE chatlog_archive 
PARTITION BY RANGE (YEAR(time)) (
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p2026 VALUES LESS THAN (2027)
);
```

**ColumnStore Benefits:**
- 10-50x compression
- Excellent for analytics queries
- Fast aggregations (counts, sums)
- Slower single-row lookups

### Alternative Engines to Consider

#### 1. Aria - Crash-Safe MyISAM Replacement

**Official Description:**
> "Aria is MariaDB's modern improvement on MyISAM. It is a storage engine for MariaDB that offers both transactional and non-transactional operation modes, designed to be a crash-safe alternative to MyISAM."

**Use Cases in rAthena:**
- Configuration tables (low write, high read)
- Logging tables (append-only)
- Temporary session data
- Non-critical registry tables

**Example:**

```sql
-- Convert to Aria with crash-safe option
ALTER TABLE mapreg ENGINE=Aria TRANSACTIONAL=1;

-- Non-transactional mode (MyISAM-like, but crash-safe)
ALTER TABLE db_roulette ENGINE=Aria TRANSACTIONAL=0;
```

**Aria vs MyISAM vs InnoDB:**

| Feature | Aria (Trans) | Aria (Non-Trans) | MyISAM | InnoDB |
|---------|--------------|------------------|--------|--------|
| Crash Recovery | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| Transactions | ⚠️ Limited | ❌ No | ❌ No | ✅ Full |
| Performance | 🟢 Good | 🟢 Good | 🟢 Good | 🟢 Good |
| Footprint | 🟢 Small | 🟢 Small | 🟢 Small | 🔴 Larger |

#### 2. ColumnStore - For Analytics/Logging

**Use Cases:**
- Historical log analysis
- Reporting dashboards
- Player behavior analytics
- Economy statistics

**NOT for:**
- Real-time game operations
- Frequent single-row updates
- OLTP workloads

**Example:**

```sql
-- Create analytics table
CREATE TABLE economy_analytics (
    date DATE,
    item_id INT,
    total_traded BIGINT,
    avg_price INT,
    total_volume BIGINT,
    INDEX (date, item_id)
) ENGINE=ColumnStore;

-- Query runs 10-100x faster than row-based
SELECT item_id, 
       SUM(total_traded) as total,
       AVG(avg_price) as avg_price
FROM economy_analytics
WHERE date BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY item_id;
```

#### 3. S3 Storage Engine - For Archival

**Use Cases:**
- Old player data (inactive > 1 year)
- Historical logs (older than 6 months)
- Backup/archive tables
- Read-only reference data

**Example:**

```sql
-- Archive old characters to S3
CREATE TABLE char_archive (
    -- same structure as char table
    char_id INT PRIMARY KEY,
    -- ... other columns ...
) ENGINE=S3;

-- Copy inactive characters
INSERT INTO char_archive 
SELECT * FROM char 
WHERE last_login < DATE_SUB(NOW(), INTERVAL 1 YEAR);
```

**Benefits:**
- Cheap storage (S3 pricing)
- Infinite capacity
- Automatic replication
- Offload historical data

**Limitations:**
- Read-only (no updates)
- Higher latency
- Requires S3 setup

---

## C. Performance Features

### Query Optimization

#### Window Functions for Reporting

Window functions enable advanced analytics without complex subqueries:

```sql
-- Top 10 richest players per server
SELECT char_id, name, zeny,
       ROW_NUMBER() OVER (ORDER BY zeny DESC) as wealth_rank,
       PERCENT_RANK() OVER (ORDER BY zeny) as wealth_percentile
FROM char
WHERE char_id > 0
LIMIT 10;

-- Guild member level distribution
SELECT guild_id, char_id, name, base_level,
       AVG(base_level) OVER (PARTITION BY guild_id) as guild_avg_level,
       base_level - AVG(base_level) OVER (PARTITION BY guild_id) as level_diff
FROM char
WHERE guild_id > 0;

-- Item trade trends
SELECT DATE(time) as trade_date, 
       nameid,
       COUNT(*) as trades,
       SUM(COUNT(*)) OVER (PARTITION BY nameid ORDER BY DATE(time)) as cumulative_trades
FROM picklog
WHERE type = 'T'
GROUP BY DATE(time), nameid;
```

**Benefits for rAthena:**
- Complex leaderboards without joins
- Player analytics (percentiles, rankings)
- Economy analysis (moving averages)
- Guild statistics

#### Common Table Expressions (CTEs)

CTEs improve query readability and enable recursive queries:

```sql
-- Readable guild statistics query
WITH guild_stats AS (
    SELECT g.guild_id, g.name, g.guild_lv,
           COUNT(gm.char_id) as member_count,
           AVG(c.base_level) as avg_level
    FROM guild g
    LEFT JOIN guild_member gm ON g.guild_id = gm.guild_id
    LEFT JOIN char c ON gm.char_id = c.char_id
    GROUP BY g.guild_id
)
SELECT * FROM guild_stats
WHERE member_count > 10 AND avg_level > 50
ORDER BY guild_lv DESC;

-- Recursive CTE: Find all clan alliances (direct and indirect)
WITH RECURSIVE clan_network AS (
    -- Base case: direct alliances
    SELECT clan_id, alliance_id, name, 1 as depth
    FROM clan_alliance
    WHERE clan_id = 1 AND opposition = 0
    
    UNION ALL
    
    -- Recursive case: alliances of alliances
    SELECT ca.clan_id, ca.alliance_id, ca.name, cn.depth + 1
    FROM clan_alliance ca
    INNER JOIN clan_network cn ON ca.clan_id = cn.alliance_id
    WHERE ca.opposition = 0 AND cn.depth < 3
)
SELECT DISTINCT alliance_id, name, MIN(depth) as distance
FROM clan_network
GROUP BY alliance_id, name
ORDER BY distance;
```

#### Derived Table Optimization

Modern MariaDB optimizes derived tables (subqueries in FROM clause):

```sql
-- Old slow way: subquery executed for each row
SELECT c.char_id, c.name, 
       (SELECT COUNT(*) FROM inventory i WHERE i.char_id = c.char_id) as item_count
FROM char c;

-- Optimized way: derived table with index
SELECT c.char_id, c.name, IFNULL(inv.item_count, 0) as item_count
FROM char c
LEFT JOIN (
    SELECT char_id, COUNT(*) as item_count
    FROM inventory
    GROUP BY char_id
) inv ON c.char_id = inv.char_id;
```

#### Subquery Optimization Improvements

**Subquery Caching:**

```sql
-- MariaDB 10.11+ automatically caches subquery results
SELECT char_id, name, base_level
FROM char
WHERE guild_id IN (
    -- This subquery is executed once and cached
    SELECT guild_id FROM guild WHERE guild_lv > 5
);
```

**Semi-Join Optimization:**

```sql
-- Automatically optimized to semi-join
SELECT c.char_id, c.name
FROM char c
WHERE EXISTS (
    SELECT 1 FROM inventory i 
    WHERE i.char_id = c.char_id AND i.nameid = 501  -- Red Potion
);

-- Can be rewritten as (but optimizer does this automatically):
SELECT DISTINCT c.char_id, c.name
FROM char c
INNER JOIN inventory i ON c.char_id = i.char_id
WHERE i.nameid = 501;
```

### Indexing Improvements

#### Invisible Indexes

Test index effectiveness without dropping:

```sql
-- Add index as invisible (exists but not used)
ALTER TABLE chatlog ADD INDEX idx_time_type (time, type) INVISIBLE;

-- Test queries - index is ignored
EXPLAIN SELECT * FROM chatlog WHERE time > '2026-01-01';

-- If queries are still fast, index not needed - drop it
-- If queries are slow, make index visible
ALTER TABLE chatlog ALTER INDEX idx_time_type VISIBLE;

-- Temporarily disable index for testing
ALTER TABLE chatlog ALTER INDEX idx_time_type INVISIBLE;
```

**Use Case:**
- Test if removing an index affects performance
- Gradually roll out new indexes
- Compare performance with/without index

#### Descending Indexes

Optimize ORDER BY DESC queries:

```sql
-- Traditional ascending index
CREATE INDEX idx_base_level_asc ON char (base_level ASC);

-- Query using DESC requires filesort
SELECT char_id, name, base_level
FROM char
ORDER BY base_level DESC  -- Filesort: expensive!
LIMIT 10;

-- Descending index (MariaDB 10.8+)
CREATE INDEX idx_base_level_desc ON char (base_level DESC);

-- Now DESC queries are optimized
SELECT char_id, name, base_level
FROM char
ORDER BY base_level DESC  -- Uses index: fast!
LIMIT 10;

-- Mixed sorting
CREATE INDEX idx_guild_level ON guild_member (guild_id ASC, exp DESC);

-- Efficiently retrieves top exp earners per guild
SELECT guild_id, char_id, exp
FROM guild_member
WHERE guild_id = 123
ORDER BY guild_id ASC, exp DESC
LIMIT 5;
```

#### Functional/Expression Indexes

Index computed values:

```sql
-- Create index on computed column
ALTER TABLE char ADD INDEX idx_total_stats ((str + agi + vit + int + dex + luk));

-- Query uses the functional index
SELECT char_id, name, (str + agi + vit + int + dex + luk) as total_stats
FROM char
WHERE (str + agi + vit + int + dex + luk) > 300;

-- Index on date part
ALTER TABLE picklog ADD INDEX idx_date ((DATE(time)));

-- Fast date-based queries
SELECT DATE(time) as date, COUNT(*) as picks
FROM picklog
WHERE DATE(time) = '2026-01-06'
GROUP BY DATE(time);

-- Case-insensitive search index
ALTER TABLE char ADD INDEX idx_name_lower ((LOWER(name)));

-- Fast case-insensitive lookups
SELECT * FROM char WHERE LOWER(name) = 'playername';
```

#### Multi-Column Index Strategies

**Compound Index Design:**

```sql
-- Bad: Multiple single-column indexes
CREATE INDEX idx_char_id ON inventory (char_id);
CREATE INDEX idx_nameid ON inventory (nameid);
CREATE INDEX idx_equip ON inventory (equip);

-- Good: Compound indexes for common queries
CREATE INDEX idx_char_items ON inventory (char_id, nameid);
CREATE INDEX idx_char_equipped ON inventory (char_id, equip, nameid);

-- Optimal: Left-most prefix rule
CREATE INDEX idx_char_item_equip ON inventory (char_id, nameid, equip);
-- This index supports queries on:
-- 1. char_id
-- 2. char_id + nameid
-- 3. char_id + nameid + equip
```

**Index Prefix Length:**

```sql
-- Index only first N characters (saves space)
CREATE INDEX idx_name_prefix ON char (name(10));  -- First 10 chars

-- Good for LIKE 'prefix%' queries
SELECT * FROM char WHERE name LIKE 'Admin%';
```

**Covering Indexes:**

```sql
-- Index includes all columns needed by query
CREATE INDEX idx_char_info ON char (char_id, name, base_level, job_level);

-- Query satisfied entirely from index (no table access)
EXPLAIN SELECT char_id, name, base_level, job_level
FROM char
WHERE char_id BETWEEN 150000 AND 150100;
-- Result: "Using index" (very fast!)
```

### Connection Handling

#### Thread Pool Optimization

**Problem:** Each connection = 1 thread = high memory usage + context switching

**Solution:** Thread pool limits threads, queues requests

```ini
[mysqld]
# Enable thread pool (MariaDB 10.5+)
thread_handling = pool-of-threads

# Thread pool configuration
thread_pool_size = 16                       # Number of thread groups (CPU cores)
thread_pool_max_threads = 1000              # Maximum threads
thread_pool_stall_limit = 500               # Milliseconds before new thread
thread_pool_idle_timeout = 60               # Seconds before thread exit
thread_pool_oversubscribe = 3               # Threads per group

# Connection limits
max_connections = 500                       # Maximum connections
max_connect_errors = 10000                  # Before host blocking
```

**Benefits:**
- Handles 1000+ concurrent players with 16-32 threads
- Reduces context switching overhead
- Better CPU cache efficiency
- Lower memory usage

**Monitoring:**

```sql
-- Check thread pool status
SHOW STATUS LIKE 'Threadpool%';

-- Check current connections
SHOW PROCESSLIST;
SHOW STATUS LIKE 'Threads%';
```

#### Connection Pool Best Practices

**Application-Side (C++ in rAthena):**

The rathena codebase already has connection pooling in [`rathena/src/common/sql.cpp`](src/common/sql.cpp:1). Optimization recommendations:

```cpp
// Recommended connection pool settings
#define MAX_CONNECTIONS 50      // Per map server
#define MIN_IDLE_CONNECTIONS 5  // Keep-alive
#define CONNECTION_TIMEOUT 28800 // 8 hours (MariaDB wait_timeout)

// Connection validation
if (Sql_Ping(sql_handle) != SQL_SUCCESS) {
    // Reconnect if connection lost
    Sql_Free(sql_handle);
    sql_handle = Sql_Malloc();
    Sql_Connect(sql_handle, ...);
}
```

**Server-Side Configuration:**

```ini
[mysqld]
# Connection timeout settings
wait_timeout = 28800                # 8 hours
interactive_timeout = 28800         # 8 hours
connect_timeout = 10                # 10 seconds
net_read_timeout = 30               # 30 seconds
net_write_timeout = 60              # 60 seconds

# Connection reuse
max_allowed_packet = 64M            # Large packet support
```

#### SSL/TLS Performance

**When to Use SSL:**
- Database on separate server (untrusted network)
- Compliance requirements (PCI-DSS, GDPR)
- Hosting provider requirement

**Performance Impact:**
- 5-15% CPU overhead
- Negligible latency increase (<1ms)

**Configuration:**

```ini
[mysqld]
# SSL configuration
ssl_ca = /path/to/ca-cert.pem
ssl_cert = /path/to/server-cert.pem
ssl_key = /path/to/server-key.pem

# Require SSL for specific users
# (Run this SQL command)
```

```sql
-- Require SSL for remote connections
CREATE USER 'rathena'@'10.0.0.%' 
IDENTIFIED BY 'password' 
REQUIRE SSL;

-- Allow local connections without SSL
CREATE USER 'rathena'@'localhost' 
IDENTIFIED BY 'password';
```

**Optimization:**

```ini
# Use faster ciphers
ssl_cipher = 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384'

# TLS version
tls_version = 'TLSv1.2,TLSv1.3'
```

---

## D. New SQL Features Applicable to rAthena

### JSON Support for Flexible Data

MariaDB 10.2+ has native JSON support. Use cases in rAthena:

#### 1. Character Configuration

Instead of multiple `*_reg_str` tables, store complex config in JSON:

```sql
-- Add JSON column to char table
ALTER TABLE char ADD COLUMN config JSON DEFAULT NULL;

-- Store complex configuration
UPDATE char SET config = JSON_OBJECT(
    'ui_settings', JSON_OBJECT(
        'hotkey_layout', 'classic',
        'skill_bar_position', 'bottom',
        'chat_window_size', '300x200'
    ),
    'game_options', JSON_OBJECT(
        'show_damage', true,
        'auto_loot', false,
        'auto_loot_threshold', 1000
    ),
    'custom_data', JSON_OBJECT(
        'achievement_showcase', JSON_ARRAY(1, 5, 10, 25),
        'favorite_maps', JSON_ARRAY('prontera', 'payon', 'geffen')
    )
) WHERE char_id = 150001;

-- Query JSON data
SELECT char_id, name,
       JSON_VALUE(config, '$.ui_settings.hotkey_layout') as layout,
       JSON_VALUE(config, '$.game_options.auto_loot') as auto_loot
FROM char
WHERE JSON_VALUE(config, '$.game_options.show_damage') = true;

-- Update nested value
UPDATE char
SET config = JSON_SET(config, '$.game_options.auto_loot', true)
WHERE char_id = 150001;
```

**Benefits:**
- Flexible schema (add new options without ALTER TABLE)
- Nested structures
- Easy to extend
- Web API friendly

**Trade-offs:**
- Larger storage (text-based)
- Slower than native columns (requires parsing)
- Can't index deeply nested values effectively

**Best Practice:**
- Use JSON for truly flexible/optional data
- Keep critical data in native columns
- Index JSON paths you query frequently

```sql
-- Create virtual column + index for frequently accessed JSON path
ALTER TABLE char 
ADD COLUMN auto_loot_enabled BOOLEAN 
GENERATED ALWAYS AS (JSON_VALUE(config, '$.game_options.auto_loot')) STORED,
ADD INDEX idx_auto_loot (auto_loot_enabled);
```

#### 2. Equipment Loadouts

```sql
-- Store multiple equipment sets
CREATE TABLE equipment_loadouts (
    char_id INT NOT NULL,
    loadout_id INT NOT NULL,
    name VARCHAR(50),
    equipment JSON,  -- { "head_top": 123, "armor": 456, ... }
    PRIMARY KEY (char_id, loadout_id),
    INDEX (char_id)
) ENGINE=InnoDB;

-- Insert loadout
INSERT INTO equipment_loadouts (char_id, loadout_id, name, equipment) VALUES (
    150001, 
    1, 
    'MVP Hunting',
    JSON_OBJECT(
        'head_top', 5001,
        'armor', 2301,
        'weapon', 1201,
        'shield', 2101,
        'accessory1', 2601,
        'accessory2', 2602
    )
);

-- Retrieve loadout
SELECT name, 
       JSON_VALUE(equipment, '$.weapon') as weapon,
       JSON_VALUE(equipment, '$.armor') as armor
FROM equipment_loadouts
WHERE char_id = 150001 AND loadout_id = 1;
```

#### 3. Quest Progress Tracking

```sql
-- Add JSON column for complex quest state
ALTER TABLE quest ADD COLUMN quest_data JSON DEFAULT NULL;

-- Store detailed progress
UPDATE quest SET quest_data = JSON_OBJECT(
    'objectives', JSON_ARRAY(
        JSON_OBJECT('id', 1, 'desc', 'Kill 10 Porings', 'current', 7, 'required', 10),
        JSON_OBJECT('id', 2, 'desc', 'Collect 5 Apples', 'current', 5, 'required', 5)
    ),
    'started_at', '2026-01-06 10:00:00',
    'last_updated', '2026-01-06 12:30:00',
    'rewards_claimed', false
)
WHERE char_id = 150001 AND quest_id = 1001;

-- Query incomplete objectives
SELECT char_id, quest_id,
       JSON_QUERY(quest_data, '$.objectives[*]') as objectives
FROM quest
WHERE state = '1' 
  AND JSON_EXISTS(quest_data, '$.objectives[*].current < objectives[*].required');
```

### Temporal Tables (System-Versioned)

Track **complete history** of all changes automatically:

#### 1. Character History Tracking

```sql
-- Add system versioning to char table
ALTER TABLE char ADD SYSTEM VERSIONING;

-- MariaDB automatically adds:
-- - row_start TIMESTAMP(6) (when row version created)
-- - row_end TIMESTAMP(6) (when row version ended)
-- - char_history table (stores old versions)

-- Query current data (normal queries)
SELECT char_id, name, base_level FROM char WHERE char_id = 150001;

-- Query historical data
SELECT char_id, name, base_level, row_start, row_end
FROM char FOR SYSTEM_TIME ALL
WHERE char_id = 150001
ORDER BY row_start DESC;

-- What was character state at specific time?
SELECT char_id, name, base_level, zeny
FROM char FOR SYSTEM_TIME AS OF '2026-01-01 00:00:00'
WHERE char_id = 150001;

-- Changes between two timestamps
SELECT char_id, name, base_level, row_start
FROM char FOR SYSTEM_TIME BETWEEN '2026-01-01' AND '2026-01-06'
WHERE char_id = 150001;
```

**Use Cases:**
- Rollback character after hack/bug
- Track progression over time
- Investigate player complaints ("I lost my items!")
- Compliance/audit trail
- Analytics (player growth patterns)

#### 2. Audit Logging Improvements

```sql
-- Create audit log with system versioning
CREATE TABLE admin_actions (
    action_id INT AUTO_INCREMENT PRIMARY KEY,
    admin_char_id INT NOT NULL,
    action_type VARCHAR(50),
    target_char_id INT,
    details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB WITH SYSTEM VERSIONING;

-- All changes automatically tracked
INSERT INTO admin_actions (admin_char_id, action_type, target_char_id, details)
VALUES (1, 'BAN', 150001, 'Botting');

-- Later admin modifies the record (suspicious!)
UPDATE admin_actions SET details = 'Mistake' WHERE action_id = 1;

-- Investigate: who changed what and when?
SELECT action_id, admin_char_id, action_type, details, row_start, row_end
FROM admin_actions FOR SYSTEM_TIME ALL
WHERE action_id = 1
ORDER BY row_start;
```

#### 3. Inventory History

```sql
-- Track every inventory change
ALTER TABLE inventory ADD SYSTEM VERSIONING;

-- Query: What items did this character have on Jan 1?
SELECT char_id, nameid, amount
FROM inventory FOR SYSTEM_TIME AS OF '2026-01-01 00:00:00'
WHERE char_id = 150001;

-- When did this item disappear?
SELECT char_id, nameid, amount, row_start, row_end
FROM inventory FOR SYSTEM_TIME ALL
WHERE char_id = 150001 AND nameid = 501  -- Red Potion
ORDER BY row_end DESC;
```

**Storage Considerations:**

- History table grows over time
- Needs periodic archival/cleanup
- Consider partitioning by date

```sql
-- Partition history table by year
ALTER TABLE char_history
PARTITION BY RANGE (YEAR(row_end)) (
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p2026 VALUES LESS THAN (2027),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- Drop old partitions
ALTER TABLE char_history DROP PARTITION p2024;
```

### Sequences vs AUTO_INCREMENT

**Problem with AUTO_INCREMENT:**
- Gaps in IDs after rollback
- Race conditions in multi-master replication
- Can't reserve ID ranges easily

**Sequences (MariaDB 10.3+):**

```sql
-- Create sequence
CREATE SEQUENCE char_id_seq
START WITH 150000
INCREMENT BY 1
MINVALUE 150000
MAXVALUE 9999999
CACHE 100;  -- Pre-allocate 100 IDs (performance)

-- Get next ID
SELECT NEXTVAL(char_id_seq);  -- Returns 150000
SELECT NEXTVAL(char_id_seq);  -- Returns 150001

-- Use in INSERT
INSERT INTO char (char_id, account_id, name, ...)
VALUES (NEXTVAL(char_id_seq), 2000001, 'NewChar', ...);

-- Check current value
SELECT LASTVAL(char_id_seq);

-- Set sequence value
ALTER SEQUENCE char_id_seq RESTART WITH 200000;
```

**Benefits for Distributed Systems:**

```sql
-- Map Server 1: Uses sequence 1 (IDs 1000000-1999999)
CREATE SEQUENCE map1_unique_id_seq
START WITH 1000000
INCREMENT BY 1
MAXVALUE 1999999
CACHE 1000;

-- Map Server 2: Uses sequence 2 (IDs 2000000-2999999)
CREATE SEQUENCE map2_unique_id_seq
START WITH 2000000
INCREMENT BY 1
MAXVALUE 2999999
CACHE 1000;

-- No collision between servers!
```

**Gap-less ID Generation:**

```sql
-- Sequence with NO CACHE for true gap-less IDs
CREATE SEQUENCE invoice_seq
START WITH 1
INCREMENT BY 1
NO CACHE;  -- Slower but no gaps

-- Use for invoice numbers, transaction IDs, etc.
```

**Migration from AUTO_INCREMENT:**

```sql
-- Create sequence from current AUTO_INCREMENT value
CREATE SEQUENCE char_id_seq START WITH 150000;

-- Set sequence to current max
SELECT SETVAL(char_id_seq, (SELECT MAX(char_id) FROM char));

-- Remove AUTO_INCREMENT
ALTER TABLE char MODIFY char_id INT UNSIGNED NOT NULL;

-- Update default to use sequence
ALTER TABLE char ALTER COLUMN char_id SET DEFAULT NEXTVAL(char_id_seq);
```

### Instant ALTER TABLE

**Problem:** Traditional ALTER TABLE locks table and rebuilds data (downtime!)

**Solution:** Instant ALTER (MariaDB 10.3+)

#### Operations That Are Instant

```sql
-- Add column at end (instant!)
ALTER TABLE char 
ADD COLUMN new_feature INT DEFAULT 0,
ALGORITHM=INSTANT;
-- Result: Executes in milliseconds, no table copy!

-- Add virtual column (always instant)
ALTER TABLE char
ADD COLUMN total_stats INT AS (str + agi + vit + int + dex + luk) VIRTUAL;

-- Add stored generated column (instant in 10.3+)
ALTER TABLE char
ADD COLUMN stat_score INT AS (str + agi + vit + int + dex + luk) STORED,
ALGORITHM=INSTANT;

-- Modify column default (instant)
ALTER TABLE char
ALTER COLUMN karma SET DEFAULT 0,
ALGORITHM=INSTANT;

-- Drop column (instant in some cases)
ALTER TABLE char
DROP COLUMN old_column,
ALGORITHM=INSTANT;

-- Rename column (instant)
ALTER TABLE char
RENAME COLUMN old_name TO new_name,
ALGORITHM=INSTANT;

-- Change column visibility (instant)
ALTER TABLE char
ALTER COLUMN internal_field SET INVISIBLE;
```

#### Operations Requiring Table Copy

```sql
-- Change column type: COPY required
ALTER TABLE char
MODIFY COLUMN zeny BIGINT;  -- Requires rebuild

-- Add column in middle: COPY required
ALTER TABLE char
ADD COLUMN new_col INT AFTER name;  -- Requires rebuild

-- Change ENGINE: COPY required
ALTER TABLE char ENGINE=InnoDB;  -- Requires rebuild
```

#### Online Schema Changes

```sql
-- Online DDL with concurrent DML
ALTER TABLE inventory
ADD INDEX idx_nameid_amount (nameid, amount),
ALGORITHM=INPLACE,  -- No table copy
LOCK=NONE;          -- Allow concurrent reads/writes

-- Check if operation can be instant/inplace
ALTER TABLE char
ADD COLUMN test_col INT,
ALGORITHM=INSTANT;  -- Fails if not possible

-- Fallback approach
ALTER TABLE char
ADD COLUMN test_col INT,
ALGORITHM=INSTANT,
ALGORITHM=INPLACE,  -- Try inplace if instant fails
ALGORITHM=COPY;     -- Last resort
```

#### Best Practices

1. **Always specify ALGORITHM:**

```sql
-- Good: Fails if not instant (alerts you to downtime)
ALTER TABLE char ADD COLUMN new_col INT, ALGORITHM=INSTANT;

-- Bad: Silently rebuilds table (unexpected downtime)
ALTER TABLE char ADD COLUMN new_col INT;
```

2. **Test on copy first:**

```sql
-- Create test copy
CREATE TABLE char_test LIKE char;

-- Test ALTER
ALTER TABLE char_test ADD COLUMN new_col INT, ALGORITHM=INSTANT;

-- If successful, apply to production
ALTER TABLE char ADD COLUMN new_col INT, ALGORITHM=INSTANT;
```

3. **Schedule rebuilds during maintenance:**

```sql
-- Operations requiring rebuild: schedule during low traffic
ALTER TABLE char MODIFY COLUMN zeny BIGINT;  -- Rebuild table
OPTIMIZE TABLE char;  -- Defragment
```

---

## E. Specific Optimizations for Game Servers

### High-Concurrency Scenarios

#### 1. Many Simultaneous Logins

**Problem:** Login server bottleneck during peak hours

**Solution:**

```ini
[mysqld]
# Connection handling
max_connections = 500
back_log = 500                          # Connection queue
thread_cache_size = 100                 # Reuse threads
max_connect_errors = 10000              # Higher tolerance

# Table cache
table_open_cache = 4000                 # Open tables
table_definition_cache = 2000           # Table definitions

# Query cache (if enabled)
query_cache_type = 0                    # OFF (better for high writes)
query_cache_size = 0
```

**Index Optimization:**

```sql
-- Optimize login query
CREATE INDEX idx_userid ON login (userid, user_pass);

-- Optimize character list query
CREATE INDEX idx_account_chars ON char (account_id, char_num);
```

**Connection Pooling:**

Ensure rathena servers maintain persistent connections:

```cpp
// Keep connections alive
Sql_SetEncoding(sql_handle, "utf8mb4");
Sql_Ping(sql_handle);  // Every 5 minutes
```

#### 2. Real-Time Inventory Updates

**Problem:** Inventory changes during trades, drops, looting

**Solution:**

```sql
-- Compound index for inventory lookups
CREATE INDEX idx_char_nameid ON inventory (char_id, nameid);
CREATE INDEX idx_char_equip ON inventory (char_id, equip);

-- Covering index for common queries
CREATE INDEX idx_inventory_cover ON inventory (char_id, nameid, amount, equip);
```

**Transaction Batching:**

```cpp
// Instead of: INSERT per item (slow)
for (item in items) {
    Sql_Query("INSERT INTO inventory VALUES (...)", item);
}

// Use: Batch INSERT (fast)
StringBuilder query = "INSERT INTO inventory VALUES ";
for (item in items) {
    query.append("(...),");
}
Sql_Query(query);
```

**InnoDB Configuration:**

```ini
[mysqld]
# Faster writes
innodb_flush_log_at_trx_commit = 2      # Flush every second (faster)
innodb_flush_method = O_DIRECT          # Skip OS cache

# Better concurrency
innodb_thread_concurrency = 0           # Unlimited (let InnoDB manage)
innodb_write_io_threads = 8             # More write threads
innodb_read_io_threads = 8              # More read threads
```

#### 3. Guild Operations

**Problem:** Many players in guild performing operations simultaneously

**Solution:**

```sql
-- Optimize guild lookups
CREATE INDEX idx_guild_id ON guild_member (guild_id, char_id);
CREATE INDEX idx_char_guild ON char (guild_id, char_id);

-- Guild storage access
CREATE INDEX idx_guild_items ON guild_storage (guild_id, nameid);
```

**Lock Wait Timeout:**

```ini
[mysqld]
innodb_lock_wait_timeout = 5            # Fail fast (default 50s)
```

#### 4. Chat/Log Recording

**Problem:** High-volume inserts to log tables

**Solution: Use Aria for logs**

```sql
-- Convert to Aria (better insert performance)
ALTER TABLE chatlog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE picklog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE zenylog ENGINE=Aria TRANSACTIONAL=1;
```

**Batch Logging:**

```cpp
// Buffer logs in memory, flush every 10 seconds
std::vector<LogEntry> log_buffer;

void log_chat(entry) {
    log_buffer.push_back(entry);
    
    if (log_buffer.size() >= 100) {
        flush_logs();
    }
}

void flush_logs() {
    // Batch insert
    Sql_Query("INSERT INTO chatlog VALUES ...");
    log_buffer.clear();
}
```

**Log Partitioning:**

```sql
-- Partition by month for easier maintenance
ALTER TABLE chatlog
PARTITION BY RANGE (TO_DAYS(time)) (
    PARTITION p202601 VALUES LESS THAN (TO_DAYS('2026-02-01')),
    PARTITION p202602 VALUES LESS THAN (TO_DAYS('2026-03-01')),
    PARTITION p202603 VALUES LESS THAN (TO_DAYS('2026-04-01')),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- Drop old partitions (fast)
ALTER TABLE chatlog DROP PARTITION p202601;
```

### Memory Optimization

#### Buffer Pool Sizing for Game Data

**Calculation:**

```
Ideal Buffer Pool Size = 
    (Average Concurrent Players × Data Per Player) + 
    (Hot Tables Size) + 
    (Index Size)

Example for 500 concurrent players:
    Character data: 500 × 2KB = 1MB
    Inventory: 500 × 200 items × 200B = 20MB
    Guild data: 100 guilds × 50KB = 5MB
    Indexes: ~100MB
    Hot data overhead: ~50MB
    
    Total: ~200MB minimum
    Recommended: 500MB - 2GB (buffer pool + overhead)
```

**Configuration:**

```ini
[mysqld]
# Buffer pool sizing
innodb_buffer_pool_size = 2G            # 50-80% of RAM
innodb_buffer_pool_instances = 8        # 1 per GB
innodb_buffer_pool_chunk_size = 128M    # Resize unit

# Buffer pool management
innodb_old_blocks_time = 1000           # Milliseconds
innodb_old_blocks_pct = 37              # Keep hot data hot

# Monitor buffer pool
innodb_buffer_pool_dump_at_shutdown = 1 # Save state
innodb_buffer_pool_load_at_startup = 1  # Restore state
```

**Monitoring:**

```sql
-- Buffer pool hit rate (should be >99%)
SHOW STATUS LIKE 'Innodb_buffer_pool_read%';
-- Innodb_buffer_pool_read_requests / 
-- (Innodb_buffer_pool_read_requests + Innodb_buffer_pool_reads)

-- Memory usage
SHOW STATUS LIKE 'Innodb_buffer_pool_pages%';

-- Current buffer pool size
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
```

#### Query Cache Strategies

**Important:** Query cache is **deprecated** in MariaDB 10.10+ and **removed** in 11.0+

**Recommendation: DISABLE query cache**

```ini
[mysqld]
query_cache_type = 0                    # OFF
query_cache_size = 0                    # No memory allocation
```

**Why?**
- High contention on cache mutex
- Invalidated on any table write
- Game servers: high write frequency = constant invalidation
- Better to rely on InnoDB buffer pool

**Alternative: Application-Level Caching**

```cpp
// Cache in game server memory
std::unordered_map<int, CharacterData> char_cache;

CharacterData get_character(int char_id) {
    // Check cache
    if (char_cache.contains(char_id)) {
        return char_cache[char_id];
    }
    
    // Query database
    CharacterData data = query_database(char_id);
    
    // Cache for 5 minutes
    char_cache[char_id] = data;
    set_expiry(char_id, 300);
    
    return data;
}
```

#### Connection Pooling Tuning

**rathena Architecture:**
- Login server: 1-2 connections
- Char server: 5-10 connections
- Map server: 10-20 connections per instance
- Multiple map servers: Scale accordingly

**Configuration:**

```ini
[mysqld]
max_connections = 200                   # Total for all servers
thread_cache_size = 50                  # Reuse connection threads
```

**Application Side:**

```cpp
// sql.cpp optimization
#define MAX_CONNECTIONS_PER_SERVER 20
#define MIN_IDLE_CONNECTIONS 2
#define CONNECTION_LIFETIME 3600  // Recycle after 1 hour

// Monitor connection usage
void monitor_connections() {
    if (active_connections > MAX_CONNECTIONS_PER_SERVER * 0.8) {
        ShowWarning("Connection pool 80%% full");
    }
}
```

### I/O Optimization

#### SSD-Specific Settings

**If using SSD:**

```ini
[mysqld]
# InnoDB on SSD
innodb_flush_method = O_DIRECT          # Skip OS cache
innodb_io_capacity = 2000               # IOPS (SSD: 2000-20000)
innodb_io_capacity_max = 4000           # Burst IOPS
innodb_flush_neighbors = 0              # No neighbor flushing (SSD random = fast)
innodb_read_io_threads = 8              # More threads (SSD handles concurrency)
innodb_write_io_threads = 8

# Log files on SSD
innodb_log_group_home_dir = /ssd/mysql/logs/

# Temp tables on SSD
tmpdir = /ssd/mysql/tmp/
```

**If using HDD:**

```ini
[mysqld]
# InnoDB on HDD
innodb_flush_method = O_DIRECT
innodb_io_capacity = 200                # IOPS (HDD: 100-300)
innodb_io_capacity_max = 400
innodb_flush_neighbors = 1              # Enable neighbor flushing (HDD sequential = fast)
innodb_read_io_threads = 4
innodb_write_io_threads = 4
```

#### Write-Ahead Logging

**Redo Log Optimization:**

```ini
[mysqld]
# Redo log configuration
innodb_log_file_size = 512M             # Larger = less frequent checkpoints
innodb_log_files_in_group = 2           # Total: 1GB redo log space
innodb_log_buffer_size = 16M            # Buffer before flush

# Flush strategy
innodb_flush_log_at_trx_commit = 1      # Full durability (safe)
# OR
innodb_flush_log_at_trx_commit = 2      # Fast (risk: lose 1 sec of commits)
```

**Performance vs Safety:**

| Value | Flush Behavior | Performance | Data Safety |
|-------|---------------|-------------|-------------|
| **0** | Write to log buffer, flush every second | Fastest | Can lose transactions on crash |
| **1** | Write & flush to disk on every commit | Slowest | Full ACID, no data loss |
| **2** | Write to OS cache, flush every second | Fast | Safe from DB crash, risk on OS crash |

**Recommendation:**
- **Production:** Use **1** (full ACID)
- **Testing:** Use **2** (faster, acceptable risk)
- **Never use 0** unless you accept potential data loss

#### Binlog Optimization for Backups

**Binary Log Configuration:**

```ini
[mysqld]
# Enable binary log for point-in-time recovery
log_bin = /var/lib/mysql/binlog/mysql-bin
max_binlog_size = 512M                  # Rotate at 512MB
expire_logs_days = 7                    # Keep 7 days
binlog_format = ROW                     # ROW format (safe, detailed)

# Sync behavior
sync_binlog = 1                         # Sync on every commit (safe)
# OR
sync_binlog = 100                       # Sync every 100 commits (faster)

# Compression (MariaDB 10.2+)
log_bin_compress = 1                    # Compress binlogs (save space)
log_bin_compress_min_len = 256          # Compress if > 256 bytes
```

**Monitoring:**

```sql
-- Check binlog status
SHOW BINARY LOGS;

-- Current position
SHOW MASTER STATUS;

-- Purge old logs
PURGE BINARY LOGS BEFORE '2026-01-01';
```

**Point-in-Time Recovery:**

```bash
# Restore from backup
mysql < backup.sql

# Apply binlogs from backup point to desired time
mysqlbinlog --start-datetime="2026-01-06 10:00:00" \
            --stop-datetime="2026-01-06 14:30:00" \
            /var/lib/mysql/binlog/mysql-bin.* | mysql

# Verify recovery
mysql -e "SELECT NOW(), COUNT(*) FROM char;"
```

---

## F. Concrete Optimization Recommendations

### Configuration Changes

#### Complete my.cnf for Game Server

```ini
[mysqld]
# ============================================================================
# MARIADB OPTIMIZATION FOR RATHENA GAME SERVER
# Version: 10.11 LTS
# Server Specs: 4 CPU cores, 8GB RAM, SSD storage
# Expected Load: 500 concurrent players
# ============================================================================

# -----------------------------
# Basic Settings
# -----------------------------
port = 3306
socket = /var/lib/mysql/mysql.sock
datadir = /var/lib/mysql
tmpdir = /var/lib/mysql/tmp

# Character set
character_set_server = utf8mb4
collation_server = utf8mb4_unicode_ci

# SQL mode (avoid strict mode issues)
sql_mode = NO_ENGINE_SUBSTITUTION

# -----------------------------
# Connection Settings
# -----------------------------
max_connections = 500                    # Total connections (all servers)
back_log = 500                          # Connection request queue
max_connect_errors = 10000              # Before blocking host
connect_timeout = 10                    # Connection timeout (seconds)
wait_timeout = 28800                    # 8 hours (keep connections alive)
interactive_timeout = 28800             # Same as wait_timeout

# Thread handling
thread_handling = pool-of-threads       # Use thread pool
thread_pool_size = 4                    # Number of CPU cores
thread_pool_max_threads = 500           # Max threads
thread_cache_size = 100                 # Cache threads for reuse

# -----------------------------
# InnoDB Settings (Critical!)
# -----------------------------

# Buffer pool (50-80% of RAM for dedicated DB server)
innodb_buffer_pool_size = 4G            # 50% of 8GB RAM
innodb_buffer_pool_instances = 4        # 1 per GB
innodb_buffer_pool_chunk_size = 128M    # Chunk size

# Buffer pool management
innodb_old_blocks_time = 1000           # Keep hot data hot
innodb_buffer_pool_dump_at_shutdown = 1 # Save buffer pool state
innodb_buffer_pool_load_at_startup = 1  # Restore on startup

# Redo logs
innodb_log_file_size = 512M             # Large = less checkpoints
innodb_log_files_in_group = 2           # 2 files = 1GB total
innodb_log_buffer_size = 16M            # Buffer before flush

# Flush behavior (CRITICAL CHOICE)
innodb_flush_log_at_trx_commit = 1      # Full ACID (safe)
innodb_flush_method = O_DIRECT          # Skip OS cache (SSD)

# I/O configuration (SSD)
innodb_io_capacity = 2000               # IOPS (SSD)
innodb_io_capacity_max = 4000           # Burst IOPS
innodb_flush_neighbors = 0              # No neighbor flush (SSD)
innodb_read_io_threads = 8              # Parallel reads
innodb_write_io_threads = 8             # Parallel writes

# Concurrency
innodb_thread_concurrency = 0           # Unlimited (auto-managed)
innodb_lock_wait_timeout = 5            # Fail fast on locks

# File per table (recommended)
innodb_file_per_table = 1               # One file per table

# Adaptive hash index
innodb_adaptive_hash_index = 1          # Auto-optimize hot data

# Change buffering
innodb_change_buffering = all           # Buffer all changes

# -----------------------------
# MyISAM/Aria Settings (for log tables)
# -----------------------------
key_buffer_size = 128M                  # MyISAM index cache
aria_pagecache_buffer_size = 256M       # Aria cache

# -----------------------------
# Query Cache (DISABLED)
# -----------------------------
query_cache_type = 0                    # OFF (not useful for writes)
query_cache_size = 0                    # No memory allocated

# -----------------------------
# Table Cache
# -----------------------------
table_open_cache = 4000                 # Open tables
table_definition_cache = 2000           # Table definitions

# -----------------------------
# Temporary Tables
# -----------------------------
tmp_table_size = 64M                    # In-memory temp table limit
max_heap_table_size = 64M               # Memory table limit

# -----------------------------
# Networking
# -----------------------------
max_allowed_packet = 64M                # Large packet support
net_read_timeout = 30                   # Read timeout
net_write_timeout = 60                  # Write timeout

# -----------------------------
# Binary Log (Backup/Replication)
# -----------------------------
log_bin = /var/lib/mysql/binlog/mysql-bin
max_binlog_size = 512M                  # Rotate at 512MB
expire_logs_days = 7                    # Keep 7 days
binlog_format = ROW                     # Safe, detailed
sync_binlog = 1                         # Sync on commit
log_bin_compress = 1                    # Compress binlogs

# -----------------------------
# Slow Query Log
# -----------------------------
slow_query_log = 1                      # Enable slow query log
slow_query_log_file = /var/log/mysql/slow-query.log
long_query_time = 2                     # Queries > 2 seconds
log_queries_not_using_indexes = 1       # Log queries without indexes

# -----------------------------
# Error Log
# -----------------------------
log_error = /var/log/mysql/error.log

# -----------------------------
# Performance Schema
# -----------------------------
performance_schema = 1                  # Enable monitoring

[client]
port = 3306
socket = /var/lib/mysql/mysql.sock
default-character-set = utf8mb4

[mysql]
default-character-set = utf8mb4
```

### Schema Modifications

#### Phase 1: Critical Tables to InnoDB

```sql
-- ============================================================================
-- PHASE 1: CONVERT CRITICAL TRANSACTIONAL TABLES TO INNODB
-- These tables MUST be InnoDB for data safety and concurrency
-- Execute during maintenance window (expect 15-60 minutes downtime)
-- ============================================================================

-- Step 1: Backup first!
-- mysqldump -u root -p rathena > backup_before_innodb.sql

-- Step 2: Convert critical tables
SET FOREIGN_KEY_CHECKS = 0;  -- Temporarily disable FK checks

-- Core character data
ALTER TABLE `char` ENGINE=InnoDB;
ALTER TABLE char_reg_num ENGINE=InnoDB;
ALTER TABLE char_reg_str ENGINE=InnoDB;

-- Player inventory and storage
ALTER TABLE inventory ENGINE=InnoDB;
ALTER TABLE storage ENGINE=InnoDB;
ALTER TABLE cart_inventory ENGINE=InnoDB;

-- Guild system
ALTER TABLE guild ENGINE=InnoDB;
ALTER TABLE guild_member ENGINE=InnoDB;
ALTER TABLE guild_storage ENGINE=InnoDB;
ALTER TABLE guild_position ENGINE=InnoDB;
ALTER TABLE guild_skill ENGINE=InnoDB;
ALTER TABLE guild_alliance ENGINE=InnoDB;
ALTER TABLE guild_expulsion ENGINE=InnoDB;
ALTER TABLE guild_castle ENGINE=InnoDB;
ALTER TABLE guild_storage_log ENGINE=InnoDB;

-- Party system
ALTER TABLE party ENGINE=InnoDB;

-- Account system
ALTER TABLE login ENGINE=InnoDB;
ALTER TABLE acc_reg_num ENGINE=InnoDB;
ALTER TABLE acc_reg_str ENGINE=InnoDB;
ALTER TABLE global_acc_reg_num ENGINE=InnoDB;
ALTER TABLE global_acc_reg_str ENGINE=InnoDB;

-- Mail system
ALTER TABLE mail ENGINE=InnoDB;
ALTER TABLE mail_attachments ENGINE=InnoDB;

-- Trading systems
ALTER TABLE auction ENGINE=InnoDB;
ALTER TABLE vendings ENGINE=InnoDB;
ALTER TABLE vending_items ENGINE=InnoDB;
ALTER TABLE buyingstores ENGINE=InnoDB;
ALTER TABLE buyingstore_items ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;  -- Re-enable FK checks

-- Step 3: Verify conversion
SELECT TABLE_NAME, ENGINE, TABLE_ROWS, 
       ROUND(DATA_LENGTH/1024/1024, 2) AS 'Data MB',
       ROUND(INDEX_LENGTH/1024/1024, 2) AS 'Index MB'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'rathena'
  AND TABLE_NAME IN ('char', 'inventory', 'storage', 'guild', 'login')
ORDER BY TABLE_NAME;
```

#### Phase 2: Secondary Tables to InnoDB

```sql
-- ============================================================================
-- PHASE 2: CONVERT SECONDARY TABLES TO INNODB
-- Lower priority but still benefit from ACID and concurrency
-- ============================================================================

-- Character-related
ALTER TABLE skill ENGINE=InnoDB;
ALTER TABLE quest ENGINE=InnoDB;
ALTER TABLE achievement ENGINE=InnoDB;
ALTER TABLE friends ENGINE=InnoDB;
ALTER TABLE memo ENGINE=InnoDB;
ALTER TABLE hotkey ENGINE=InnoDB;
ALTER TABLE sc_data ENGINE=InnoDB;
ALTER TABLE skillcooldown ENGINE=InnoDB;

-- Companions
ALTER TABLE pet ENGINE=InnoDB;
ALTER TABLE homunculus ENGINE=InnoDB;
ALTER TABLE skill_homunculus ENGINE=InnoDB;
ALTER TABLE skillcooldown_homunculus ENGINE=InnoDB;
ALTER TABLE mercenary ENGINE=InnoDB;
ALTER TABLE mercenary_owner ENGINE=InnoDB;
ALTER TABLE skillcooldown_mercenary ENGINE=InnoDB;
ALTER TABLE elemental ENGINE=InnoDB;

-- Other systems
ALTER TABLE party_bookings ENGINE=InnoDB;
ALTER TABLE sales ENGINE=InnoDB;
ALTER TABLE barter ENGINE=InnoDB;
ALTER TABLE market ENGINE=InnoDB;
ALTER TABLE db_roulette ENGINE=InnoDB;
```

#### Phase 3: Logging Tables to Aria

```sql
-- ============================================================================
-- PHASE 3: CONVERT LOGGING TABLES TO ARIA
-- Better crash safety than MyISAM, lower overhead than InnoDB
-- ============================================================================

-- Enable transactional mode for crash safety
ALTER TABLE atcommandlog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE branchlog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE cashlog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE chatlog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE feedinglog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE loginlog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE mvplog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE npclog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE picklog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE zenylog ENGINE=Aria TRANSACTIONAL=1;

-- Verify
SELECT TABLE_NAME, ENGINE
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'rathena'
  AND TABLE_NAME LIKE '%log'
ORDER BY TABLE_NAME;
```

### Index Additions

```sql
-- ============================================================================
-- STRATEGIC INDEX ADDITIONS
-- Optimize common query patterns
-- ============================================================================

-- Character lookups
CREATE INDEX idx_char_account ON `char` (account_id, char_num);
CREATE INDEX idx_char_guild ON `char` (guild_id) USING BTREE;
CREATE INDEX idx_char_party ON `char` (party_id) USING BTREE;
CREATE INDEX idx_char_name_lower ON `char` ((LOWER(name)));

-- Inventory queries
CREATE INDEX idx_inv_char_item ON inventory (char_id, nameid);
CREATE INDEX idx_inv_char_equip ON inventory (char_id, equip);
CREATE INDEX idx_inv_unique ON inventory (unique_id);
-- Covering index for common query
CREATE INDEX idx_inv_cover ON inventory (char_id, nameid, amount, equip);

-- Storage queries
CREATE INDEX idx_storage_char_item ON storage (account_id, nameid);
CREATE INDEX idx_cart_char_item ON cart_inventory (char_id, nameid);

-- Guild queries
CREATE INDEX idx_guild_member_char ON guild_member (char_id);
CREATE INDEX idx_guild_storage_item ON guild_storage (guild_id, nameid);
CREATE INDEX idx_guild_name ON guild (name);

-- Login queries
CREATE INDEX idx_login_userid_pass ON login (userid, user_pass);
CREATE INDEX idx_login_token ON login (web_auth_token);

-- Quest queries
CREATE INDEX idx_quest_char_state ON quest (char_id, state);

-- Achievement queries
CREATE INDEX idx_achievement_char ON achievement (char_id, completed);

-- Skill queries
CREATE INDEX idx_skill_char ON skill (char_id, id);

-- Mail queries
CREATE INDEX idx_mail_dest ON mail (dest_id, status);
CREATE INDEX idx_mail_send ON mail (send_id, time);

-- Logging indexes (careful with log tables - can slow inserts)
CREATE INDEX idx_chatlog_time_type ON chatlog (time, type);
CREATE INDEX idx_chatlog_char ON chatlog (src_charid, time);
CREATE INDEX idx_picklog_char_time ON picklog (char_id, time);
CREATE INDEX idx_picklog_type_time ON picklog (type, time);
CREATE INDEX idx_zenylog_char_time ON zenylog (char_id, time);
CREATE INDEX idx_zenylog_type_time ON zenylog (type, time);

-- Full-text search for chat logs (if needed)
ALTER TABLE chatlog ADD FULLTEXT INDEX ft_message (message);

-- Verify indexes
SELECT TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'rathena'
  AND TABLE_NAME IN ('char', 'inventory', 'guild', 'login')
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;
```

### Query Pattern Improvements

#### Before and After Examples

**Example 1: Character List Query**

```sql
-- BEFORE: No index, table scan
SELECT char_id, name, base_level, job_level
FROM `char`
WHERE account_id = 2000001;

-- Analysis
EXPLAIN SELECT char_id, name, base_level, job_level
FROM `char`
WHERE account_id = 2000001;
-- Result: type=ALL (table scan), rows=150000

-- AFTER: Add index
CREATE INDEX idx_char_account ON `char` (account_id);

-- Analysis
EXPLAIN SELECT char_id, name, base_level, job_level
FROM `char`
WHERE account_id = 2000001;
-- Result: type=ref (index lookup), rows=3
-- Performance: 50000x faster!
```

**Example 2: Inventory Lookup**

```sql
-- BEFORE: Multiple queries
SELECT * FROM inventory WHERE char_id = 150001 AND nameid = 501;
SELECT * FROM inventory WHERE char_id = 150001 AND equip > 0;
SELECT COUNT(*) FROM inventory WHERE char_id = 150001;

-- AFTER: Optimized compound index
CREATE INDEX idx_inv_char_item_equip ON inventory (char_id, nameid, equip);

-- Single covering index query
SELECT char_id, nameid, amount, equip
FROM inventory
WHERE char_id = 150001;
-- Result: "Using index" (no table access needed)
```

**Example 3: Guild Member List**

```sql
-- BEFORE: Join without proper indexes
SELECT c.char_id, c.name, c.base_level, gm.position
FROM guild_member gm
JOIN `char` c ON gm.char_id = c.char_id
WHERE gm.guild_id = 1;

-- Add indexes
CREATE INDEX idx_guild_member_guild ON guild_member (guild_id, char_id);
CREATE INDEX idx_char_id ON `char` (char_id);

-- Performance improvement: 100x+ faster
```

**Example 4: Top Players Leaderboard**

```sql
-- BEFORE: Sorting large table
SELECT char_id, name, base_level, zeny
FROM `char`
ORDER BY base_level DESC
LIMIT 100;
-- Problem: Filesort on 150000 rows

-- AFTER: Add descending index
CREATE INDEX idx_char_level_desc ON `char` (base_level DESC);

-- Query now uses index (no filesort)
EXPLAIN SELECT char_id, name, base_level, zeny
FROM `char`
ORDER BY base_level DESC
LIMIT 100;
-- Result: "Using index" (fast!)
```

### Migration Steps with Rollback Plans

#### Migration Checklist

```
☐ 1. Full backup of database
      mysqldump -u root -p --single-transaction rathena > backup_full.sql

☐ 2. Test backup restore on separate instance
      mysql -u root -p test_rathena < backup_full.sql

☐ 3. Document current table sizes and row counts
      SELECT TABLE_NAME, ENGINE, TABLE_ROWS, 
             DATA_LENGTH + INDEX_LENGTH AS total_size
      FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = 'rathena';

☐ 4. Stop game servers (login, char, map)
      ./athena-start stop

☐ 5. Verify no active connections
      SHOW PROCESSLIST;

☐ 6. Execute Phase 1 conversions (critical tables)
      SOURCE phase1_innodb_conversion.sql;

☐ 7. Verify conversions successful
      SELECT TABLE_NAME, ENGINE FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = 'rathena' AND ENGINE != 'MyISAM';

☐ 8. Optimize tables
      OPTIMIZE TABLE char, inventory, storage, guild, login;

☐ 9. Start game servers in test mode
      ./athena-start start

☐ 10. Run functionality tests
       - Login with test account
       - Load characters
       - Check inventory
       - Perform trade
       - Create guild

☐ 11. Monitor error logs
       tail -f /var/log/mysql/error.log
       tail -f rathena/log/*.log

☐ 12. Run for 1 hour with test users

☐ 13. If stable, open to public
       Otherwise, rollback (see below)

☐ 14. Monitor performance for 24 hours
       - Query performance
       - Connection count
       - Buffer pool hit rate
       - Lock wait timeouts
```

#### Rollback Plan

If issues occur during migration:

```bash
#!/bin/bash
# rollback.sh - Emergency rollback script

echo "Starting emergency rollback..."

# Stop servers
echo "Stopping game servers..."
./athena-start stop

# Wait for connections to close
sleep 5

# Drop current database
echo "Dropping current database..."
mysql -u root -p -e "DROP DATABASE rathena;"

# Recreate database
echo "Recreating database..."
mysql -u root -p -e "CREATE DATABASE rathena;"

# Restore from backup
echo "Restoring from backup..."
mysql -u root -p rathena < backup_full.sql

# Verify restore
echo "Verifying restore..."
mysql -u root -p -e "USE rathena; SHOW TABLES;"

# Start servers
echo "Starting game servers..."
./athena-start start

echo "Rollback complete. Check logs for issues."
```

### Performance Benchmarking Approach

#### Baseline Measurement (Before Optimization)

```sql
-- 1. Query performance
SET profiling = 1;

-- Run test queries
SELECT * FROM `char` WHERE account_id = 2000001;
SELECT * FROM inventory WHERE char_id = 150001;
SELECT COUNT(*) FROM guild_member WHERE guild_id = 1;

-- Show timing
SHOW PROFILES;

-- 2. Table statistics
SELECT TABLE_NAME, ENGINE, TABLE_ROWS,
       ROUND(DATA_LENGTH/1024/1024, 2) AS data_mb,
       ROUND(INDEX_LENGTH/1024/1024, 2) AS index_mb,
       ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2) AS total_mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'rathena'
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC;

-- 3. Current server status
SHOW STATUS LIKE 'Innodb_buffer_pool_read%';
SHOW STATUS LIKE 'Threads%';
SHOW STATUS LIKE 'Slow_queries';
SHOW VARIABLES LIKE 'max_connections';
```

#### Load Testing

**Simple Load Test Script:**

```bash
#!/bin/bash
# load_test.sh - Simulate concurrent player load

CONNECTIONS=100
DURATION=300  # 5 minutes

echo "Starting load test: $CONNECTIONS connections for $DURATION seconds"

for i in $(seq 1 $CONNECTIONS); do
    (
        while true; do
            mysql -u rathena -p'password' rathena <<EOF
            -- Simulate player actions
            SELECT * FROM char WHERE account_id = $RANDOM;
            SELECT * FROM inventory WHERE char_id = 150000 + $RANDOM % 1000;
            UPDATE char SET zeny = zeny + 1 WHERE char_id = 150000 + $RANDOM % 1000;
            INSERT INTO picklog (time, char_id, type, nameid, amount) 
            VALUES (NOW(), 150000 + $RANDOM % 1000, 'P', 501, 1);
EOF
            sleep 0.1
        done
    ) &
done

# Run for duration
sleep $DURATION

# Kill all background jobs
killall mysql

echo "Load test complete"
```

#### Post-Optimization Measurement

```sql
-- Compare query performance
SET profiling = 1;

-- Same test queries
SELECT * FROM `char` WHERE account_id = 2000001;
SELECT * FROM inventory WHERE char_id = 150001;
SELECT COUNT(*) FROM guild_member WHERE guild_id = 1;

SHOW PROFILES;

-- Compare with baseline results
-- Expected: 2-10x faster queries

-- Check buffer pool efficiency
SHOW STATUS LIKE 'Innodb_buffer_pool_read%';
-- Innodb_buffer_pool_read_requests should be >> Innodb_buffer_pool_reads
-- Hit rate should be >99%

-- Check lock waits (should be minimal)
SHOW STATUS LIKE 'Innodb_row_lock%';
```

#### Continuous Monitoring

```sql
-- Create monitoring queries

-- 1. Slow query summary
SELECT COUNT(*) as slow_queries
FROM mysql.slow_log
WHERE start_time > DATE_SUB(NOW(), INTERVAL 1 HOUR);

-- 2. Active connections
SELECT COUNT(*) as active_connections FROM information_schema.PROCESSLIST;

-- 3. Table sizes over time
CREATE TABLE monitoring.table_sizes (
    measured_at DATETIME,
    table_name VARCHAR(64),
    rows BIGINT,
    data_mb DECIMAL(10,2),
    index_mb DECIMAL(10,2)
);

INSERT INTO monitoring.table_sizes
SELECT NOW(), TABLE_NAME, TABLE_ROWS,
       ROUND(DATA_LENGTH/1024/1024, 2),
       ROUND(INDEX_LENGTH/1024/1024, 2)
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'rathena';

-- 4. Performance metrics
CREATE TABLE monitoring.performance_metrics (
    measured_at DATETIME,
    metric_name VARCHAR(64),
    metric_value BIGINT
);

INSERT INTO monitoring.performance_metrics
SELECT NOW(), 'buffer_pool_hit_rate',
       ROUND(100 * Innodb_buffer_pool_read_requests / 
       (Innodb_buffer_pool_read_requests + Innodb_buffer_pool_reads), 2)
FROM (
    SELECT VARIABLE_VALUE as Innodb_buffer_pool_read_requests
    FROM information_schema.GLOBAL_STATUS
    WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'
) a, (
    SELECT VARIABLE_VALUE as Innodb_buffer_pool_reads
    FROM information_schema.GLOBAL_STATUS
    WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads'
) b;
```

---

## G. Prioritization Matrix

| Priority | Optimization | Impact | Risk | Dependencies | Notes |
|----------|-------------|--------|------|--------------|-------|
| **CRITICAL** | Convert `char` to InnoDB | Prevents data corruption, enables rollback | Low | Full backup, test environment | Most critical table - character progress |
| **CRITICAL** | Convert `inventory` to InnoDB | Prevents item duplication/loss, better concurrency | Low | char conversion | High-volume writes, ACID required |
| **CRITICAL** | Convert `storage` to InnoDB | Same as inventory | Low | char conversion | Shared resource for account |
| **CRITICAL** | Convert `login` to InnoDB | Account security, crash safety | Low | Full backup | Authentication failures affect all |
| **CRITICAL** | InnoDB buffer pool sizing | 2-5x performance | Low | None | Configure before conversion |
| **HIGH** | Convert `guild` + related to InnoDB | Guild operations consistency | Low | char conversion | Multi-user shared resource |
| **HIGH** | Convert `guild_storage` to InnoDB | Prevent guild warehouse issues | Low | guild conversion | Very high concurrency |
| **HIGH** | Add compound indexes | 10-50x faster queries | Low | None | Online index creation |
| **HIGH** | Convert logs to Aria | Better crash safety, good insert perf | Low | None | Append-only workload |
| **HIGH** | InnoDB I/O settings (SSD) | 50-100% faster writes | Low | SSD storage | Optimize for hardware |
| **HIGH** | Thread pool configuration | Handle more concurrent players | Low | MariaDB 10.5+ | Better scalability |
| **MEDIUM** | Convert secondary tables (skill, quest) | Data consistency | Low | char conversion | Lower write frequency |
| **MEDIUM** | Add descending indexes | Faster leaderboards | Low | None | MariaDB 10.8+ feature |
| **MEDIUM** | JSON columns for config | Flexible schema, easier extensions | Medium | Application changes | New feature implementation |
| **MEDIUM** | Temporal tables for audit | Complete history tracking | Medium | InnoDB tables | Storage overhead |
| **MEDIUM** | Query optimization (CTEs) | Cleaner, faster queries | Low | None | Refactor existing queries |
| **MEDIUM** | Binlog configuration | Point-in-time recovery | Low | Storage space | Backup strategy |
| **LOW** | Functional indexes | Specific use case optimization | Low | MariaDB 10.6+ | Case-by-case basis |
| **LOW** | Sequences vs AUTO_INCREMENT | Better for distributed setup | Low | Schema changes | Only if multi-master |
| **LOW** | ColumnStore for analytics | 10x better for reports | Medium | Separate instance | Only if heavy analytics |
| **LOW** | S3 storage for archives | Cheap archival | Low | AWS/S3 setup | Old data offload |

### Risk Assessment Details

#### Low Risk Optimizations (Safe to Deploy)
- Configuration changes (my.cnf)
- Adding indexes (online DDL)
- Query rewrites (CTEs, window functions)
- Monitoring setup

#### Medium Risk Optimizations (Test Thoroughly)
- Engine conversions (MyISAM → InnoDB)
- Schema changes (add columns)
- Temporal tables (new feature)
- JSON columns (application changes needed)

#### High Risk Optimizations (Requires Extensive Testing)
- Multi-master replication
- Sharding strategy
- Major application refactoring

### Impact Scoring

**Performance Impact:**
- 5x - 10x: Critical optimizations (InnoDB conversion, indexes)
- 2x - 5x: High impact (configuration tuning, query optimization)
- 1.5x - 2x: Medium impact (monitoring, minor tweaks)
- <1.5x: Low impact (convenience features)

**Operational Impact:**
- **Critical:** Affects data safety, player experience
- **High:** Affects performance, scalability
- **Medium:** Affects maintenance, monitoring
- **Low:** Nice to have, future-proofing

---

## H. Implementation Roadmap

### Phase A: Quick Wins (Immediate - Low Risk, High Impact)

**Timeline:** Can be done immediately with minimal risk

**Goals:**
- Improve performance with configuration changes
- Add strategic indexes
- Set up monitoring

**Tasks:**

1. **Update MariaDB Configuration**
   ```bash
   # Backup current config
   cp /etc/my.cnf /etc/my.cnf.backup
   
   # Apply optimized config
   nano /etc/my.cnf
   # (Use configuration from section F)
   
   # Restart MariaDB
   systemctl restart mariadb
   ```

2. **Add Strategic Indexes (Online)**
   ```sql
   -- These can be added while server is running
   -- No downtime required
   
   CREATE INDEX idx_char_account ON `char` (account_id, char_num);
   CREATE INDEX idx_inv_char_item ON inventory (char_id, nameid);
   CREATE INDEX idx_storage_account ON storage (account_id);
   CREATE INDEX idx_guild_member_char ON guild_member (char_id);
   CREATE INDEX idx_login_userid ON login (userid);
   ```

3. **Enable Slow Query Log**
   ```sql
   SET GLOBAL slow_query_log = 1;
   SET GLOBAL long_query_time = 2;
   SET GLOBAL log_queries_not_using_indexes = 1;
   ```

4. **Set Up Basic Monitoring**
   ```bash
   # Install monitoring script
   cat > /usr/local/bin/mysql_monitor.sh <<'EOF'
   #!/bin/bash
   echo "=== MySQL Status at $(date) ===" >> /var/log/mysql_monitor.log
   mysql -e "SHOW STATUS LIKE 'Threads_connected';" >> /var/log/mysql_monitor.log
   mysql -e "SHOW STATUS LIKE 'Innodb_buffer_pool_read%';" >> /var/log/mysql_monitor.log
   mysql -e "SHOW PROCESSLIST;" >> /var/log/mysql_monitor.log
   EOF
   
   chmod +x /usr/local/bin/mysql_monitor.sh
   
   # Add to crontab (every 5 minutes)
   (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/mysql_monitor.sh") | crontab -
   ```

**Expected Results:**
- 20-50% query performance improvement from indexes
- Better visibility with monitoring
- Optimized configuration for game workload

**Validation:**
```sql
-- Verify indexes created
SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'rathena'
  AND INDEX_NAME LIKE 'idx_%'
ORDER BY TABLE_NAME, INDEX_NAME;

-- Check slow queries
SELECT * FROM mysql.slow_log
ORDER BY start_time DESC
LIMIT 10;
```

---

### Phase B: Core Optimizations (Scheduled Maintenance Window)

**Timeline:** Requires 2-4 hour maintenance window

**Goals:**
- Convert critical tables to InnoDB
- Achieve ACID compliance for transactional data
- Improve concurrency

**Prerequisites:**
- ✅ Phase A completed
- ✅ Full database backup
- ✅ Test environment validation
- ✅ Rollback plan prepared
- ✅ Maintenance window scheduled

**Tasks:**

1. **Pre-Conversion Checklist**
   ```bash
   # Full backup
   mysqldump -u root -p --single-transaction --routines --triggers \
             rathena > backup_before_innodb_$(date +%Y%m%d_%H%M%S).sql
   
   # Verify backup
   ls -lh backup_before_innodb_*.sql
   
   # Test restore on separate instance (CRITICAL!)
   mysql -u root -p test_rathena < backup_before_innodb_*.sql
   ```

2. **Stop Game Servers**
   ```bash
   ./athena-start stop
   
   # Verify no connections
   mysql -e "SHOW PROCESSLIST;"
   ```

3. **Execute InnoDB Conversion**
   ```sql
   -- Phase B1: Core character data
   ALTER TABLE `char` ENGINE=InnoDB;
   ALTER TABLE char_reg_num ENGINE=InnoDB;
   ALTER TABLE char_reg_str ENGINE=InnoDB;
   
   -- Phase B2: Inventory/Storage
   ALTER TABLE inventory ENGINE=InnoDB;
   ALTER TABLE storage ENGINE=InnoDB;
   ALTER TABLE cart_inventory ENGINE=InnoDB;
   
   -- Phase B3: Authentication
   ALTER TABLE login ENGINE=InnoDB;
   ALTER TABLE acc_reg_num ENGINE=InnoDB;
   ALTER TABLE acc_reg_str ENGINE=InnoDB;
   
   -- Phase B4: Social systems
   ALTER TABLE guild ENGINE=InnoDB;
   ALTER TABLE guild_member ENGINE=InnoDB;
   ALTER TABLE guild_storage ENGINE=InnoDB;
   ALTER TABLE party ENGINE=InnoDB;
   
   -- Phase B5: Trading
   ALTER TABLE mail ENGINE=InnoDB;
   ALTER TABLE auction ENGINE=InnoDB;
   ```

4. **Verify Conversions**
   ```sql
   SELECT TABLE_NAME, ENGINE, TABLE_ROWS,
          ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2) AS size_mb
   FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = 'rathena'
     AND TABLE_NAME IN ('char', 'inventory', 'storage', 'login', 'guild')
   ORDER BY TABLE_NAME;
   ```

5. **Optimize Tables**
   ```sql
   OPTIMIZE TABLE `char`, inventory, storage, login, guild;
   ```

6. **Start Servers and Test**
   ```bash
   ./athena-start start
   
   # Monitor logs
   tail -f log/map-server.log
   tail -f /var/log/mysql/error.log
   ```

7. **Functional Testing**
   - Login with test accounts
   - Create character
   - Check inventory
   - Trade items
   - Create/join guild
   - Send mail
   - Perform auction

**Expected Results:**
- 80% of critical data now ACID-compliant
- 2-5x better write concurrency
- Automatic crash recovery
- Eliminated table-level locks

**Rollback Procedure:**
If issues detected within first hour:
```bash
./athena-start stop
mysql -u root -p -e "DROP DATABASE rathena;"
mysql -u root -p -e "CREATE DATABASE rathena;"
mysql -u root -p rathena < backup_before_innodb_*.sql
./athena-start start
```

---

### Phase C: Advanced Features (Iterative Deployment)

**Timeline:** Can be done incrementally over several weeks

**Goals:**
- Leverage modern MariaDB features
- Improve monitoring and diagnostics
- Add audit capabilities

**Prerequisites:**
- ✅ Phase B completed successfully
- ✅ System stable for 1+ week
- ✅ No performance regressions

**Tasks:**

**C1: Logging Tables to Aria (Week 1)**

```sql
-- Convert logging tables for better crash safety
ALTER TABLE chatlog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE picklog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE zenylog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE atcommandlog ENGINE=Aria TRANSACTIONAL=1;
ALTER TABLE mvplog ENGINE=Aria TRANSACTIONAL=1;

-- Add partitioning for easier management
ALTER TABLE chatlog
PARTITION BY RANGE (TO_DAYS(time)) (
    PARTITION p_current VALUES LESS THAN (TO_DAYS(NOW())),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- Create monthly partition management
DELIMITER $$
CREATE EVENT partition_maintenance
ON SCHEDULE EVERY 1 MONTH
DO BEGIN
    -- Add new partition for next month
    -- Drop partitions older than 6 months
END$$
DELIMITER ;
```

**C2: Temporal Tables for Audit (Week 2-3)**

```sql
-- Enable system versioning on key tables
ALTER TABLE `char` ADD SYSTEM VERSIONING;
ALTER TABLE inventory ADD SYSTEM VERSIONING;
ALTER TABLE guild ADD SYSTEM VERSIONING;

-- Partition history tables by year
ALTER TABLE char_history
PARTITION BY RANGE (YEAR(row_end)) (
    PARTITION p2026 VALUES LESS THAN (2027),
    PARTITION p2027 VALUES LESS THAN (2028),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- Create admin interface for history queries
CREATE VIEW v_char_history AS
SELECT char_id, name, base_level, job_level, zeny,
       row_start as valid_from,
       row_end as valid_to,
       CASE WHEN row_end = '2038-01-19 03:14:07' 
            THEN 'Current' ELSE 'Historical' END as status
FROM `char` FOR SYSTEM_TIME ALL;
```

**C3: JSON Configuration Support (Week 4)**

```sql
-- Add JSON column for flexible character config
ALTER TABLE `char` 
ADD COLUMN config JSON DEFAULT NULL,
ALGORITHM=INSTANT;

-- Create helper stored procedures
DELIMITER $$

CREATE PROCEDURE set_char_config(
    IN p_char_id INT,
    IN p_key VARCHAR(100),
    IN p_value JSON
)
BEGIN
    UPDATE `char`
    SET config = JSON_SET(IFNULL(config, '{}'), CONCAT('$.', p_key), p_value)
    WHERE char_id = p_char_id;
END$$

CREATE PROCEDURE get_char_config(
    IN p_char_id INT,
    IN p_key VARCHAR(100)
)
BEGIN
    SELECT JSON_EXTRACT(config, CONCAT('$.', p_key)) as value
    FROM `char`
    WHERE char_id = p_char_id;
END$$

DELIMITER ;

-- Example usage
CALL set_char_config(150001, 'ui_settings', 
    '{"hotkey_layout": "classic", "show_damage": true}');
```

**C4: Advanced Indexing (Week 5)**

```sql
-- Add descending indexes for leaderboards
CREATE INDEX idx_char_level_desc ON `char` (base_level DESC);
CREATE INDEX idx_guild_level_desc ON guild (guild_lv DESC);

-- Functional indexes for case-insensitive search
CREATE INDEX idx_char_name_lower ON `char` ((LOWER(name)));
CREATE INDEX idx_guild_name_lower ON guild ((LOWER(name)));

-- Full-text search for chat logs
ALTER TABLE chatlog ADD FULLTEXT INDEX ft_message (message);
```

**C5: Performance Reporting (Week 6)**

```sql
-- Create performance monitoring database
CREATE DATABASE IF NOT EXISTS monitoring;

-- Query performance tracking
CREATE TABLE monitoring.slow_query_summary (
    date DATE,
    query_pattern VARCHAR(255),
    count INT,
    avg_exec_time DECIMAL(10,4),
    max_exec_time DECIMAL(10,4),
    PRIMARY KEY (date, query_pattern)
);

-- Automated daily summary
CREATE EVENT monitoring.daily_performance_summary
ON SCHEDULE EVERY 1 DAY
DO
INSERT INTO monitoring.slow_query_summary
SELECT DATE(start_time), 
       LEFT(sql_text, 100),
       COUNT(*),
       AVG(query_time),
       MAX(query_time)
FROM mysql.slow_log
WHERE start_time >= CURDATE()
GROUP BY DATE(start_time), LEFT(sql_text, 100);
```

**Expected Results:**
- Complete audit trail for critical tables
- Better crash safety for logs
- Flexible configuration system
- Comprehensive performance monitoring

---

### Phase D: Long-Term Strategic Improvements

**Timeline:** 3-6 months, ongoing optimization

**Goals:**
- Prepare for scale
- Advanced analytics
- High availability

**Tasks:**

**D1: Read Replicas for Reporting**

```ini
# Master server configuration
[mysqld]
server_id = 1
log_bin = /var/lib/mysql/binlog/mysql-bin
binlog_format = ROW

# Replica server configuration
[mysqld]
server_id = 2
relay_log = /var/lib/mysql/relay-log/mysql-relay
read_only = 1
```

```sql
-- On replica: Set up replication
CHANGE MASTER TO
    MASTER_HOST='master.server.com',
    MASTER_USER='repl',
    MASTER_PASSWORD='password',
    MASTER_LOG_FILE='mysql-bin.000001',
    MASTER_LOG_POS=107;

START SLAVE;

-- Verify
SHOW SLAVE STATUS\G
```

**D2: ColumnStore for Analytics**

```sql
-- Create analytics database
CREATE DATABASE rathena_analytics;

-- Create ColumnStore tables for historical analysis
CREATE TABLE rathena_analytics.player_stats_daily (
    date DATE,
    char_id INT,
    base_level INT,
    job_level INT,
    zeny BIGINT,
    login_count INT,
    playtime_minutes INT,
    KEY (date, char_id)
) ENGINE=ColumnStore;

-- ETL process: daily aggregation from main DB
INSERT INTO rathena_analytics.player_stats_daily
SELECT CURDATE(), char_id, base_level, job_level, zeny, 0, 0
FROM rathena.char
WHERE last_login >= CURDATE();

-- Analytics queries run 10-100x faster
SELECT date, COUNT(DISTINCT char_id) as daily_active_users
FROM rathena_analytics.player_stats_daily
WHERE date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY date;
```

**D3: ProxySQL for Load Balancing**

```ini
# /etc/proxysql.cnf
datadir="/var/lib/proxysql"

admin_variables=
{
    admin_credentials="admin:admin"
    mysql_ifaces="0.0.0.0:6032"
}

mysql_variables=
{
    threads=4
    max_connections=2048
    default_query_delay=0
    default_query_timeout=36000000
}

# Server groups
mysql_servers=
(
    { address="master.db.local", port=3306, hostgroup=0, max_connections=200 },
    { address="replica1.db.local", port=3306, hostgroup=1, max_connections=200 },
    { address="replica2.db.local", port=3306, hostgroup=1, max_connections=200 }
)

# Query routing rules
mysql_query_rules=
(
    # Route SELECT to read replicas
    {
        rule_id=1
        active=1
        match_pattern="^SELECT.*FOR UPDATE$"
        destination_hostgroup=0
        apply=1
    },
    {
        rule_id=2
        active=1
        match_pattern="^SELECT"
        destination_hostgroup=1
        apply=1
    }
)
```

**D4: Automated Backup Strategy**

```bash
#!/bin/bash
# /usr/local/bin/mariadb_backup.sh

BACKUP_DIR="/backup/mysql"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)

# Full backup
mariabackup --backup \
    --target-dir=$BACKUP_DIR/full_$DATE \
    --user=backup --password=PASSWORD

# Compress
tar -czf $BACKUP_DIR/full_$DATE.tar.gz $BACKUP_DIR/full_$DATE/
rm -rf $BACKUP_DIR/full_$DATE/

# Upload to S3
aws s3 cp $BACKUP_DIR/full_$DATE.tar.gz s3://backups/mysql/

# Clean old backups
find $BACKUP_DIR -name "full_*.tar.gz" -mtime +$RETENTION_DAYS -delete

# Verify backup
if [ -f "$BACKUP_DIR/full_$DATE.tar.gz" ]; then
    echo "Backup successful: full_$DATE.tar.gz"
else
    echo "Backup FAILED!" | mail -s "MySQL Backup Alert" admin@example.com
fi
```

**D5: Disaster Recovery Plan**

```markdown
# Disaster Recovery Runbook

## Scenario 1: Database Server Failure

1. Promote read replica to master
   ```sql
   STOP SLAVE;
   RESET SLAVE ALL;
   SET GLOBAL read_only = 0;
   ```

2. Update application servers to new master
   ```bash
   # Update DNS or reconfigure connection strings
   ```

3. Set up new replica from promoted master

## Scenario 2: Data Corruption

1. Stop applications
2. Identify corruption time from binlog
3. Restore from last good backup
4. Apply binlogs up to corruption point
   ```bash
   mysqlbinlog --stop-datetime="2026-01-06 14:30:00" \
       /var/lib/mysql/binlog/mysql-bin.* | mysql
   ```

## Scenario 3: Accidental Data Deletion

1. Use temporal tables to view historical data
   ```sql
   SELECT * FROM char 
   FOR SYSTEM_TIME AS OF '2026-01-06 12:00:00'
   WHERE char_id = 150001;
   ```

2. Restore specific data from history table
   ```sql
   INSERT INTO char SELECT * FROM char_history 
   WHERE char_id = 150001 AND row_end > row_start
   ORDER BY row_end DESC LIMIT 1;
   ```
```

**Expected Results:**
- High availability setup
- Fast analytics without impacting production
- Automated backup and recovery
- Prepared for 10x scale

---

## Conclusion

This optimization plan transforms the rathena database from a high-risk MyISAM configuration to a production-grade, ACID-compliant, high-performance system using modern MariaDB features.

### Key Takeaways

1. **Start with MariaDB 10.11 LTS** for production stability
2. **Prioritize InnoDB conversion** for critical tables (char, inventory, storage, guild, login)
3. **Use Aria for logging** tables (better than MyISAM, lighter than InnoDB)
4. **Optimize InnoDB configuration** for game server workload
5. **Add strategic indexes** for common query patterns
6. **Implement temporal tables** for audit trail
7. **Monitor continuously** to catch issues early

### Next Steps

1. Review this plan with your team
2. Set up test environment
3. Execute Phase A (Quick Wins)
4. Schedule maintenance window for Phase B
5. Deploy Phase C incrementally
6. Plan for Phase D long-term improvements

### Support and Resources

- [MariaDB Documentation](https://mariadb.com/kb/en/)
- [rAthena Forums](https://rathena.org/board/)
- [MySQL Performance Blog](https://www.percona.com/blog/)
- MariaDB community support: IRC #mariadb on Freenode

---

**Document End**

For questions or clarification, refer to:
- MariaDB official documentation
- This document sections (A-H)
- rAthena database schema: [`rathena/sql-files/main.sql`](sql-files/main.sql:1), [`rathena/sql-files/logs.sql`](sql-files/logs.sql:1)

**Last Updated:** 2026-01-06  
**Next Review:** After Phase B completion
