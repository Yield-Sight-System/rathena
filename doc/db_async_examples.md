# Database Async Operations - Usage Examples

## Overview

This document provides practical examples for using the async database API introduced in Phase 4c.

## Table of Contents

1. [Basic Usage](#basic-usage)
2. [Fire-and-Forget Queries](#fire-and-forget-queries)
3. [Queries with Callbacks](#queries-with-callbacks)
4. [User Context Handling](#user-context-handling)
5. [Error Handling](#error-handling)
6. [Advanced Patterns](#advanced-patterns)
7. [Performance Best Practices](#performance-best-practices)
8. [Common Pitfalls](#common-pitfalls)

## Basic Usage

### Simple Async Query (No Callback)

Perfect for logging, statistics, or any operation where you don't need to wait for the result:

```cpp
// src/map/log.cpp - Item pickup logging
void log_pick_async(int char_id, int item_id, int amount) {
    // Query executes in worker thread, doesn't block game loop
    Sql_QueryAsync(log_sql_handle,
                   "INSERT INTO picklog (char_id, nameid, amount, time) VALUES (%d, %d, %d, NOW())",
                   nullptr,  // No callback
                   nullptr,  // No user data
                   char_id, item_id, amount);
    
    // Main thread continues immediately - zero perceived latency
}
```

**Benefits:**
- Zero blocking time
- Main thread continues processing
- Automatic error logging
- Perfect for high-frequency operations

### Async Query with Callback

Use when you need to process the query result:

```cpp
// Character load callback
void on_character_loaded(bool success, void* user_data) {
    int account_id = *(int*)user_data;
    
    if (success) {
        ShowInfo("Character loaded successfully for account %d\n", account_id);
        // Proceed with character spawn logic
    } else {
        ShowError("Failed to load character for account %d\n", account_id);
        // Send error to client
    }
    
    delete (int*)user_data;  // Clean up
}

// Initiate async character load
void load_character_async(int account_id, int char_num) {
    int* context = new int(account_id);
    
    Sql_QueryAsync(char_sql_handle,
                   "SELECT * FROM `char` WHERE account_id=%d AND char_num=%d",
                   on_character_loaded,
                   context,
                   account_id, char_num);
    
    // Main thread continues, callback invoked when query completes
}
```

## Fire-and-Forget Queries

### Item Transaction Logging

```cpp
// High-frequency logging without blocking
void log_zeny_async(int char_id, int amount, const char* type) {
    Sql_QueryAsync(log_sql_handle,
                   "INSERT INTO zenylog (char_id, amount, type, time) VALUES (%d, %d, '%s', NOW())",
                   nullptr, nullptr,
                   char_id, amount, type);
}

// Usage
log_zeny_async(char_id, 1000, "SHOP");  // Returns immediately
```

### Statistics Updates

```cpp
// Update server statistics asynchronously
void update_server_stats_async() {
    int player_count = map_getusers();
    int mob_count = map_id_db->count();
    
    Sql_QueryAsync(stats_sql_handle,
                   "UPDATE server_stats SET players=%d, mobs=%d, last_update=NOW() WHERE server_id=1",
                   nullptr, nullptr,
                   player_count, mob_count);
}
```

### NPC Event Logging

```cpp
// Log NPC interactions
void log_npc_transaction_async(int char_id, int npc_id, int item_id, int quantity) {
    Sql_QueryAsync(log_sql_handle,
                   "INSERT INTO npclog (char_id, npc_id, item_id, quantity, time) VALUES (%d, %d, %d, %d, NOW())",
                   nullptr, nullptr,
                   char_id, npc_id, item_id, quantity);
}
```

## Queries with Callbacks

### Character Save with Confirmation

```cpp
struct SaveContext {
    int char_id;
    t_tick save_tick;
};

void on_character_saved(bool success, void* user_data) {
    SaveContext* ctx = (SaveContext*)user_data;
    t_tick elapsed = gettick() - ctx->save_tick;
    
    if (success) {
        ShowInfo("Character %d saved successfully (%" PRIu64 "ms)\n", 
                 ctx->char_id, (uint64)elapsed);
    } else {
        ShowError("Failed to save character %d - implementing retry\n", ctx->char_id);
        // Trigger retry logic here
        retry_character_save(ctx->char_id);
    }
    
    delete ctx;
}

void save_character_async(int char_id, struct mmo_charstatus* p) {
    SaveContext* ctx = new SaveContext{char_id, gettick()};
    
    Sql_QueryAsync(char_sql_handle,
                   "UPDATE `char` SET base_level=%d, job_level=%d, zeny=%d WHERE char_id=%d",
                   on_character_saved,
                   ctx,
                   p->base_level, p->job_level, p->zeny, char_id);
}
```

### Validation Query

```cpp
struct ValidationContext {
    int account_id;
    const char* operation;
};

void on_account_validated(bool success, void* user_data) {
    ValidationContext* ctx = (ValidationContext*)user_data;
    
    if (success) {
        // Account validated, proceed with operation
        ShowInfo("Account %d validated for %s\n", ctx->account_id, ctx->operation);
        proceed_with_operation(ctx->account_id, ctx->operation);
    } else {
        // Validation failed
        ShowWarning("Account %d validation failed for %s\n", 
                    ctx->account_id, ctx->operation);
        send_error_to_client(ctx->account_id);
    }
    
    delete ctx;
}

void validate_account_async(int account_id, const char* operation) {
    ValidationContext* ctx = new ValidationContext{account_id, operation};
    
    Sql_QueryAsync(login_sql_handle,
                   "SELECT 1 FROM login WHERE account_id=%d AND state=0",
                   on_account_validated,
                   ctx,
                   account_id);
}
```

## User Context Handling

### Complex Context with Multiple Fields

```cpp
struct ItemPurchaseContext {
    int char_id;
    int item_id;
    int quantity;
    int price;
    std::atomic<bool>* completion_flag;
};

void on_purchase_logged(bool success, void* user_data) {
    ItemPurchaseContext* ctx = (ItemPurchaseContext*)user_data;
    
    if (success) {
        ShowInfo("Purchase logged: char=%d, item=%d, qty=%d, price=%d\n",
                 ctx->char_id, ctx->item_id, ctx->quantity, ctx->price);
    }
    
    if (ctx->completion_flag) {
        ctx->completion_flag->store(true);
    }
    
    delete ctx;
}

void log_item_purchase_async(int char_id, int item_id, int quantity, int price) {
    ItemPurchaseContext* ctx = new ItemPurchaseContext{
        char_id, item_id, quantity, price, nullptr
    };
    
    Sql_QueryAsync(log_sql_handle,
                   "INSERT INTO purchaselog (char_id, item_id, quantity, price, time) "
                   "VALUES (%d, %d, %d, %d, NOW())",
                   on_purchase_logged,
                   ctx,
                   char_id, item_id, quantity, price);
}
```

### Shared Context Between Multiple Queries

```cpp
struct BatchContext {
    int batch_id;
    std::atomic<int>* completed_count;
    int total_operations;
};

void on_batch_operation_complete(bool success, void* user_data) {
    BatchContext* ctx = (BatchContext*)user_data;
    
    int completed = ctx->completed_count->fetch_add(1) + 1;
    
    if (completed == ctx->total_operations) {
        ShowInfo("Batch %d completed (%d/%d operations)\n",
                 ctx->batch_id, completed, ctx->total_operations);
        delete ctx->completed_count;
    }
    
    delete ctx;
}

void execute_batch_operations(int batch_id, int* item_ids, int count) {
    std::atomic<int>* completed = new std::atomic<int>(0);
    
    for (int i = 0; i < count; i++) {
        BatchContext* ctx = new BatchContext{batch_id, completed, count};
        
        Sql_QueryAsync(log_sql_handle,
                       "INSERT INTO batch_log (batch_id, item_id) VALUES (%d, %d)",
                       on_batch_operation_complete,
                       ctx,
                       batch_id, item_ids[i]);
    }
}
```

## Error Handling

### Retry Logic

```cpp
struct RetryContext {
    std::string query;
    int retry_count;
    int max_retries;
};

void on_query_with_retry(bool success, void* user_data) {
    RetryContext* ctx = (RetryContext*)user_data;
    
    if (success) {
        ShowInfo("Query succeeded after %d retries\n", ctx->retry_count);
        delete ctx;
        return;
    }
    
    // Query failed
    if (ctx->retry_count < ctx->max_retries) {
        ctx->retry_count++;
        ShowWarning("Query failed, retrying (%d/%d)...\n", 
                    ctx->retry_count, ctx->max_retries);
        
        // Exponential backoff (optional)
        std::this_thread::sleep_for(
            std::chrono::milliseconds(100 * ctx->retry_count)
        );
        
        // Retry the query
        Sql_QueryAsyncStr(sql_handle, ctx->query.c_str(), 
                         on_query_with_retry, ctx);
    } else {
        ShowError("Query failed after %d retries, giving up\n", ctx->max_retries);
        // Log critical failure
        log_critical_db_failure(ctx->query);
        delete ctx;
    }
}

void submit_query_with_retry(const char* query, int max_retries = 3) {
    RetryContext* ctx = new RetryContext{query, 0, max_retries};
    Sql_QueryAsyncStr(sql_handle, query, on_query_with_retry, ctx);
}
```

### Error Notification

```cpp
struct ErrorNotificationContext {
    int char_id;
    const char* operation;
};

void on_critical_operation(bool success, void* user_data) {
    ErrorNotificationContext* ctx = (ErrorNotificationContext*)user_data;
    
    if (!success) {
        // Send error notification to player
        map_session_data* sd = map_charid2sd(ctx->char_id);
        if (sd) {
            clif_displaymessage(sd->fd, "Database operation failed. Please try again.");
        }
        
        // Log for admin review
        ShowError("Critical DB operation failed: %s for char %d\n",
                  ctx->operation, ctx->char_id);
    }
    
    delete ctx;
}
```

## Advanced Patterns

### Chained Queries

Execute queries in sequence, where each query depends on the previous result:

```cpp
struct ChainContext {
    int char_id;
    int step;
};

// Step 3: Final update
void chain_step3(bool success, void* user_data) {
    ChainContext* ctx = (ChainContext*)user_data;
    ShowInfo("Character %d: All updates completed\n", ctx->char_id);
    delete ctx;
}

// Step 2: Update inventory
void chain_step2(bool success, void* user_data) {
    ChainContext* ctx = (ChainContext*)user_data;
    
    if (!success) {
        ShowError("Chain failed at step 2 for char %d\n", ctx->char_id);
        delete ctx;
        return;
    }
    
    ctx->step = 3;
    Sql_QueryAsync(char_sql_handle,
                   "UPDATE inventory SET amount=amount+1 WHERE char_id=%d",
                   chain_step3, ctx, ctx->char_id);
}

// Step 1: Update character
void chain_step1(bool success, void* user_data) {
    ChainContext* ctx = (ChainContext*)user_data;
    
    if (!success) {
        ShowError("Chain failed at step 1 for char %d\n", ctx->char_id);
        delete ctx;
        return;
    }
    
    ctx->step = 2;
    Sql_QueryAsync(char_sql_handle,
                   "UPDATE `char` SET zeny=zeny+100 WHERE char_id=%d",
                   chain_step2, ctx, ctx->char_id);
}

// Initiate the chain
void execute_character_updates(int char_id) {
    ChainContext* ctx = new ChainContext{char_id, 1};
    
    Sql_QueryAsync(char_sql_handle,
                   "UPDATE `char` SET last_update=NOW() WHERE char_id=%d",
                   chain_step1, ctx, char_id);
}
```

### Batch Processing with Completion Tracking

```cpp
class AsyncBatchProcessor {
private:
    std::atomic<int> completed_;
    std::atomic<int> errors_;
    int total_;
    std::function<void()> on_complete_;
    
public:
    AsyncBatchProcessor(int total, std::function<void()> on_complete)
        : completed_(0), errors_(0), total_(total), on_complete_(on_complete) {}
    
    void submit_query(Sql* sql, const char* query) {
        Sql_QueryAsyncStr(sql, query, 
            [this](bool success, void* user_data) {
                if (success) {
                    completed_.fetch_add(1);
                } else {
                    errors_.fetch_add(1);
                }
                
                int done = completed_.load() + errors_.load();
                if (done == total_) {
                    ShowInfo("Batch complete: %d success, %d errors\n",
                             completed_.load(), errors_.load());
                    on_complete_();
                    delete this;  // Self-cleanup
                }
            }, nullptr);
    }
};

// Usage
void save_all_inventory_items(int char_id, struct item* items, int count) {
    auto* processor = new AsyncBatchProcessor(count, [char_id]() {
        ShowInfo("All items saved for character %d\n", char_id);
        notify_save_complete(char_id);
    });
    
    for (int i = 0; i < count; i++) {
        char query[512];
        snprintf(query, sizeof(query),
                 "INSERT INTO inventory (char_id, nameid, amount) VALUES (%d, %d, %d)",
                 char_id, items[i].nameid, items[i].amount);
        
        processor->submit_query(char_sql_handle, query);
    }
}
```

## Performance Best Practices

### 1. Use Async for I/O, Not Computation

**Good:**
```cpp
// Database I/O - perfect for async
Sql_QueryAsync(sql, "INSERT INTO logs ...", nullptr, nullptr);
```

**Bad:**
```cpp
// CPU computation - use CPU worker pool instead
get_cpu_worker_pool()->submit([=]() {
    complex_calculation();
});
```

### 2. Batch Related Queries

**Inefficient:**
```cpp
for (int i = 0; i < 1000; i++) {
    Sql_QueryAsync(sql, "INSERT INTO logs VALUES (%d)", nullptr, nullptr, i);
}
```

**Efficient:**
```cpp
// Build batch INSERT query
std::string query = "INSERT INTO logs VALUES ";
for (int i = 0; i < 1000; i++) {
    query += StringBuf_Printf("(%d)%s", i, i < 999 ? "," : "");
}
Sql_QueryAsyncStr(sql, query.c_str(), nullptr, nullptr);
```

### 3. Don't Mix Sync and Async on Same Handle

**UNSAFE:**
```cpp
Sql_QueryAsync(sql_handle, query1, ...);  // Worker thread will use handle
Sql_Query(sql_handle, query2);             // Main thread (RACE CONDITION!)
```

**SAFE:**
```cpp
// Option 1: Use separate handles
Sql_QueryAsync(async_sql_handle, query1, ...);
Sql_Query(main_sql_handle, query2);

// Option 2: Wait for callback before using handle
Sql_QueryAsync(sql_handle, query1, callback, ...);
// Only use sql_handle again in callback or after completion
```

### 4. Minimize Callback Overhead

**Inefficient:**
```cpp
// Creates new context for every query
for (int i = 0; i < 1000; i++) {
    int* ctx = new int(i);
    Sql_QueryAsync(sql, "...", [](bool s, void* d) {
        delete (int*)d;
    }, ctx);
}
```

**Efficient:**
```cpp
// Fire-and-forget when callback not needed
for (int i = 0; i < 1000; i++) {
    Sql_QueryAsync(sql, "...", nullptr, nullptr, i);
}
```

## Common Pitfalls

### ❌ Pitfall 1: Accessing Query Results

**Wrong:**
```cpp
Sql_QueryAsync(sql, "SELECT * FROM `char` WHERE char_id=%d", nullptr, nullptr, char_id);

// WRONG: Can't access result immediately
if (Sql_NextRow(sql) == SQL_SUCCESS) {  // UNDEFINED BEHAVIOR!
    // Query hasn't executed yet!
}
```

**Correct:**
```cpp
Sql_QueryAsync(sql, "SELECT * FROM `char` WHERE char_id=%d",
               [](bool success, void* data) {
                   if (success) {
                       // Access results in callback
                       // Note: Results need special handling in async context
                   }
               }, nullptr, char_id);
```

### ❌ Pitfall 2: Dangling Pointers in Context

**Wrong:**
```cpp
void some_function() {
    int local_var = 42;
    
    Sql_QueryAsync(sql, "...", [](bool s, void* data) {
        int value = *(int*)data;  // DANGLING POINTER!
    }, &local_var);  // local_var destroyed before callback!
}
```

**Correct:**
```cpp
void some_function() {
    int* heap_var = new int(42);
    
    Sql_QueryAsync(sql, "...", [](bool s, void* data) {
        int value = *(int*)data;
        delete (int*)data;  // Clean up
    }, heap_var);
}
```

### ❌ Pitfall 3: Order Dependency

**Wrong:**
```cpp
// These may complete in any order!
Sql_QueryAsync(sql, "INSERT INTO table1 ...", nullptr, nullptr);
Sql_QueryAsync(sql, "UPDATE table2 WHERE id IN (SELECT id FROM table1)", ...);
// UPDATE may execute before INSERT!
```

**Correct:**
```cpp
// Chain queries using callbacks
Sql_QueryAsync(sql, "INSERT INTO table1 ...",
               [](bool success, void* data) {
                   if (success) {
                       Sql_QueryAsync(sql, "UPDATE table2 ...", nullptr, nullptr);
                   }
               }, nullptr);
```

### ❌ Pitfall 4: Forgetting to Clean Up Context

**Wrong:**
```cpp
void bad_example() {
    char* ctx = new char[100];
    strcpy(ctx, "test");
    
    Sql_QueryAsync(sql, "...", 
                   [](bool s, void* data) {
                       // Forgot to delete!
                   }, ctx);  // MEMORY LEAK!
}
```

**Correct:**
```cpp
void good_example() {
    char* ctx = new char[100];
    strcpy(ctx, "test");
    
    Sql_QueryAsync(sql, "...",
                   [](bool s, void* data) {
                       char* ctx = (char*)data;
                       delete[] ctx;  // Proper cleanup
                   }, ctx);
}
```

## Real-World Integration Examples

### Character Auto-Save System

```cpp
// src/map/chrif.cpp or src/map/pc.cpp

static t_tick last_autosave_tick = 0;
static const t_tick AUTOSAVE_INTERVAL = 300000;  // 5 minutes

void on_character_autosaved(bool success, void* user_data) {
    int char_id = *(int*)user_data;
    
    if (success) {
        ShowInfo("Auto-saved character %d\n", char_id);
    } else {
        ShowWarning("Auto-save failed for character %d\n", char_id);
    }
    
    delete (int*)user_data;
}

void character_autosave_async(map_session_data* sd) {
    if (!sd || sd->state.active == 0) {
        return;
    }
    
    int* char_id_ctx = new int(sd->status.char_id);
    
    // Build save query (simplified example)
    Sql_QueryAsync(char_sql_handle,
                   "UPDATE `char` SET "
                   "base_level=%d, job_level=%d, base_exp=%" PRIu64 ", job_exp=%" PRIu64 ", "
                   "zeny=%d, hp=%d, sp=%d, last_map='%s', last_x=%d, last_y=%d "
                   "WHERE char_id=%d",
                   on_character_autosaved,
                   char_id_ctx,
                   sd->status.base_level, sd->status.job_level,
                   sd->status.base_exp, sd->status.job_exp,
                   sd->status.zeny, sd->status.hp, sd->status.sp,
                   sd->status.last_point.map, sd->status.last_point.x, sd->status.last_point.y,
                   sd->status.char_id);
}

// Call this from a timer
TIMER_FUNC(autosave_timer) {
    if (gettick() - last_autosave_tick < AUTOSAVE_INTERVAL) {
        return 0;
    }
    
    last_autosave_tick = gettick();
    
    // Asynchronously save all online characters
    map_foreachpc([](map_session_data* sd) {
        character_autosave_async(sd);
        return 0;
    });
    
    return 0;
}
```

### Guild Emblem Upload

```cpp
// src/map/guild.cpp

struct EmblemContext {
    int guild_id;
    int emblem_len;
    char* emblem_data;
};

void on_emblem_saved(bool success, void* user_data) {
    EmblemContext* ctx = (EmblemContext*)user_data;
    
    if (success) {
        ShowInfo("Guild emblem saved for guild %d\n", ctx->guild_id);
        
        // Notify guild members
        guild_emblem_changed(ctx->guild_id);
    } else {
        ShowError("Failed to save emblem for guild %d\n", ctx->guild_id);
    }
    
    delete[] ctx->emblem_data;
    delete ctx;
}

void save_guild_emblem_async(int guild_id, int emblem_len, const char* emblem_data) {
    // Create context
    EmblemContext* ctx = new EmblemContext();
    ctx->guild_id = guild_id;
    ctx->emblem_len = emblem_len;
    ctx->emblem_data = new char[emblem_len * 2 + 1];
    
    // Escape binary data
    Sql_EscapeStringLen(guild_sql_handle, ctx->emblem_data, emblem_data, emblem_len);
    
    // Submit async update
    Sql_QueryAsync(guild_sql_handle,
                   "UPDATE guild SET emblem_data='%s', emblem_len=%d WHERE guild_id=%d",
                   on_emblem_saved,
                   ctx,
                   ctx->emblem_data, emblem_len, guild_id);
}
```

### Map-Wide Event Logging

```cpp
// src/map/script.cpp or src/map/npc.cpp

void log_map_event_async(const char* map_name, const char* event_type, const char* details) {
    Sql_QueryAsync(log_sql_handle,
                   "INSERT INTO map_events (map_name, event_type, details, time) "
                   "VALUES ('%s', '%s', '%s', NOW())",
                   nullptr,  // No callback needed for logging
                   nullptr,
                   map_name, event_type, details);
}

// Usage in various places
log_map_event_async("prontera", "MVP_SPAWNED", "Killed by PlayerName");
log_map_event_async("prontera", "WOE_STARTED", "Castle: Prontera");
```

## Monitoring and Debugging

### Query Statistics Display

```cpp
// @command implementation to show DB async stats
ACMD_FUNC(dbstats) {
    uint64 total_queries, pending_queries, avg_time_us;
    Sql_GetAsyncStats(&total_queries, &pending_queries, &avg_time_us);
    
    sprintf(atcmd_output, "=== Async Database Statistics ===");
    clif_displaymessage(fd, atcmd_output);
    
    sprintf(atcmd_output, "Total queries: %" PRIu64, total_queries);
    clif_displaymessage(fd, atcmd_output);
    
    sprintf(atcmd_output, "Pending queries: %" PRIu64, pending_queries);
    clif_displaymessage(fd, atcmd_output);
    
    sprintf(atcmd_output, "Average query time: %.2f ms", avg_time_us / 1000.0);
    clif_displaymessage(fd, atcmd_output);
    
    if (g_db_worker_pool) {
        sprintf(atcmd_output, "DB worker threads: %zu", g_db_worker_pool->num_threads());
        clif_displaymessage(fd, atcmd_output);
        
        sprintf(atcmd_output, "Active workers: %zu", g_db_worker_pool->active_workers());
        clif_displaymessage(fd, atcmd_output);
    }
    
    return 0;
}
```

### Verbose Logging Analysis

Enable in [`conf/battle/threading.conf`](../conf/battle/threading.conf):

```conf
verbose_threading: yes
```

Example output:

```
[Async DB] Submitting query: INSERT INTO picklog (char_id, nameid, amount) VALUES...
[Async DB] Query completed in 23ms (affected: 1 rows)
[Async DB] Submitting query: UPDATE `char` SET zeny=zeny+100 WHERE char_id=150000
[Async DB] Query completed in 15ms (affected: 1 rows)
```

## Migration Checklist

When converting existing synchronous code to async:

- [ ] Identify I/O-bound operations (database queries)
- [ ] Determine if result is needed immediately (use callback if yes)
- [ ] Check for query dependencies (chain if needed)
- [ ] Allocate context on heap if callback needs data
- [ ] Implement proper cleanup in callback
- [ ] Add error handling logic
- [ ] Test with `enable_db_async: no` (fallback mode)
- [ ] Test with `enable_db_async: yes` (async mode)
- [ ] Verify database consistency
- [ ] Monitor performance improvement

## Configuration Reference

### Optimal Settings

```conf
# Production settings for async DB operations
enable_threading: yes
enable_db_async: yes
db_worker_threads: 4      # Adjust based on DB server capacity
verbose_threading: no     # Disable in production
```

### Debug Settings

```conf
# Development/debugging settings
enable_threading: yes
enable_db_async: yes
db_worker_threads: 2      # Lower for easier debugging
verbose_threading: yes    # Enable detailed logging
```

### Compatibility Mode

```conf
# Fallback to synchronous mode (zero threading)
enable_threading: no
# All other threading flags ignored when enable_threading is no
```

## Testing Strategy

### Unit Testing

1. Test with threading disabled (sync fallback)
2. Test with threading enabled (async mode)
3. Verify identical database state in both modes
4. Test error handling (malformed queries)
5. Test callback invocation
6. Test context cleanup
7. Stress test with 1000+ queries

### Integration Testing

1. Enable async DB in test environment
2. Perform character login/logout cycles
3. Execute item transactions
4. Verify database consistency
5. Check for memory leaks (valgrind)
6. Monitor query completion times
7. Test server shutdown (pending queries)

### Performance Testing

```cpp
// Benchmark async vs sync performance
void benchmark_db_async() {
    const int QUERY_COUNT = 1000;
    
    // Sync benchmark
    auto sync_start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < QUERY_COUNT; i++) {
        Sql_QueryStr(sql_handle, "SELECT 1");
        Sql_FreeResult(sql_handle);
    }
    auto sync_duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::high_resolution_clock::now() - sync_start
    );
    
    ShowInfo("Sync: %d queries in %ldms (%.2fms/query)\n",
             QUERY_COUNT, sync_duration.count(),
             (double)sync_duration.count() / QUERY_COUNT);
    
    // Async benchmark (see test_db_async.cpp for full implementation)
}
```

## See Also

- [`src/common/sql.hpp`](../src/common/sql.hpp) - Async API declarations
- [`src/common/sql.cpp`](../src/common/sql.cpp) - Async implementation
- [`src/test/test_db_async.cpp`](../src/test/test_db_async.cpp) - Comprehensive test suite
- [`doc/threading.md`](threading.md) - Threading architecture overview
- [`conf/battle/threading.conf`](../conf/battle/threading.conf) - Configuration

## Version History

- **Phase 4c-1**: Basic async infrastructure (current)
  - Fire-and-forget queries
  - Callback support
  - Automatic fallback to sync mode
  - Statistics tracking

- **Phase 4c-2** (Planned): Advanced features
  - Connection pooling
  - Query result caching
  - Batch optimization
  - Advanced error retry logic
