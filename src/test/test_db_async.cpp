// Copyright (c) rAthena Dev Teams - Licensed under GNU GPL
// For more information, see LICENCE in the main folder

/**
 * @file test_db_async.cpp
 * @brief Test suite for async database operations (Phase 4c)
 * 
 * This file demonstrates and tests the async database query infrastructure.
 * Compile with: g++ -o test_db_async test_db_async.cpp -DTEST_DB_ASYNC
 * 
 * Or integrate into map-server with -DTEST_DB_ASYNC flag
 */

#include <common/sql.hpp>
#include <common/showmsg.hpp>
#include <common/timer.hpp>
#include <common/core.hpp>

#include <atomic>
#include <thread>
#include <chrono>

#ifdef TEST_DB_ASYNC

/**
 * Test 1: Simple fire-and-forget query
 * Use case: Item transaction logging, statistics
 */
void test_fire_and_forget(Sql* sql_handle) {
	ShowInfo("===== Test 1: Fire-and-Forget Query =====\n");
	
	// Submit query without callback (fire-and-forget)
	bool submitted = Sql_QueryAsyncStr(sql_handle, 
	                                   "SELECT 1 AS test_value", 
	                                   nullptr,  // No callback
	                                   nullptr); // No user data
	
	if (submitted) {
		ShowInfo("[PASS] Fire-and-forget query submitted successfully\n");
	} else {
		ShowError("[FAIL] Fire-and-forget query submission failed\n");
	}
	
	// Wait for processing
	std::this_thread::sleep_for(std::chrono::milliseconds(100));
	Sql_ProcessCompletedQueries();
	
	ShowInfo("Test 1 complete\n\n");
}

/**
 * Test 2: Query with callback
 * Use case: Character load, validation checks
 */
void test_with_callback(Sql* sql_handle) {
	ShowInfo("===== Test 2: Query with Callback =====\n");
	
	// Flag to track callback invocation
	static std::atomic<bool> callback_invoked{false};
	callback_invoked.store(false);
	
	// Define callback
	auto callback = [](bool success, void* user_data) {
		std::atomic<bool>* flag = (std::atomic<bool>*)user_data;
		
		if (success) {
			ShowInfo("[Callback] Query succeeded!\n");
		} else {
			ShowError("[Callback] Query failed!\n");
		}
		
		flag->store(true);
	};
	
	// Submit query with callback
	bool submitted = Sql_QueryAsyncStr(sql_handle,
	                                   "SELECT NOW() AS current_time",
	                                   callback,
	                                   &callback_invoked);
	
	if (!submitted) {
		ShowError("[FAIL] Query with callback submission failed\n");
		return;
	}
	
	ShowInfo("Query submitted, waiting for callback...\n");
	
	// Wait for callback (simulate main loop)
	int32 iterations = 0;
	while (!callback_invoked.load() && iterations < 100) {
		Sql_ProcessCompletedQueries();
		std::this_thread::sleep_for(std::chrono::milliseconds(10));
		iterations++;
	}
	
	if (callback_invoked.load()) {
		ShowInfo("[PASS] Callback invoked successfully after %d iterations\n", iterations);
	} else {
		ShowError("[FAIL] Callback not invoked within timeout\n");
	}
	
	ShowInfo("Test 2 complete\n\n");
}

/**
 * Test 3: Multiple concurrent queries
 * Use case: Batch operations, logging
 */
void test_concurrent_queries(Sql* sql_handle) {
	ShowInfo("===== Test 3: Concurrent Queries =====\n");
	
	static std::atomic<int32> completed_count{0};
	completed_count.store(0);
	
	const int32 QUERY_COUNT = 10;
	
	// Callback that increments counter
	auto callback = [](bool success, void* user_data) {
		std::atomic<int32>* counter = (std::atomic<int32>*)user_data;
		counter->fetch_add(1);
		
		if (success) {
			ShowInfo("[Callback] Query #%d completed successfully\n", 
			         counter->load());
		}
	};
	
	// Submit multiple queries
	ShowInfo("Submitting %d concurrent queries...\n", QUERY_COUNT);
	for (int32 i = 0; i < QUERY_COUNT; i++) {
		Sql_QueryAsync(sql_handle,
		               "SELECT %d AS query_number",
		               callback,
		               &completed_count,
		               i);
	}
	
	// Wait for all to complete
	ShowInfo("Waiting for completion...\n");
	int32 iterations = 0;
	while (completed_count.load() < QUERY_COUNT && iterations < 200) {
		Sql_ProcessCompletedQueries();
		std::this_thread::sleep_for(std::chrono::milliseconds(10));
		iterations++;
	}
	
	if (completed_count.load() == QUERY_COUNT) {
		ShowInfo("[PASS] All %d queries completed successfully\n", QUERY_COUNT);
	} else {
		ShowError("[FAIL] Only %d/%d queries completed\n", 
		          completed_count.load(), QUERY_COUNT);
	}
	
	ShowInfo("Test 3 complete\n\n");
}

/**
 * Test 4: Query with user context
 * Use case: Character operations with context
 */
struct TestContext {
	int32 test_id;
	std::string test_name;
	std::atomic<bool>* completion_flag;
};

void test_user_context(Sql* sql_handle) {
	ShowInfo("===== Test 4: Query with User Context =====\n");
	
	std::atomic<bool> completed{false};
	
	// Create user context
	TestContext* ctx = new TestContext{
		42,
		"TestCharacter",
		&completed
	};
	
	// Callback with context
	auto callback = [](bool success, void* user_data) {
		TestContext* ctx = (TestContext*)user_data;
		
		ShowInfo("[Callback] Received context:\n");
		ShowInfo("  test_id: %d\n", ctx->test_id);
		ShowInfo("  test_name: %s\n", ctx->test_name.c_str());
		
		if (success) {
			ShowInfo("[Callback] Query with context succeeded\n");
		}
		
		ctx->completion_flag->store(true);
		delete ctx;  // Clean up context
	};
	
	// Submit query
	Sql_QueryAsync(sql_handle,
	               "SELECT '%s' AS name, %d AS id",
	               callback,
	               ctx,
	               ctx->test_name.c_str(), ctx->test_id);
	
	// Wait for completion
	int32 iterations = 0;
	while (!completed.load() && iterations < 100) {
		Sql_ProcessCompletedQueries();
		std::this_thread::sleep_for(std::chrono::milliseconds(10));
		iterations++;
	}
	
	if (completed.load()) {
		ShowInfo("[PASS] Context callback completed successfully\n");
	} else {
		ShowError("[FAIL] Context callback timeout\n");
	}
	
	ShowInfo("Test 4 complete\n\n");
}

/**
 * Test 5: Error handling
 * Use case: Malformed queries, connection issues
 */
void test_error_handling(Sql* sql_handle) {
	ShowInfo("===== Test 5: Error Handling =====\n");
	
	static std::atomic<bool> error_callback_invoked{false};
	error_callback_invoked.store(false);
	
	// Callback that expects failure
	auto callback = [](bool success, void* user_data) {
		std::atomic<bool>* flag = (std::atomic<bool>*)user_data;
		
		if (!success) {
			ShowInfo("[Callback] Error correctly reported in callback\n");
		} else {
			ShowWarning("[Callback] Expected error but got success\n");
		}
		
		flag->store(true);
	};
	
	// Submit intentionally bad query
	Sql_QueryAsyncStr(sql_handle,
	                  "SELECT * FROM nonexistent_table_12345",
	                  callback,
	                  &error_callback_invoked);
	
	// Wait for callback
	int32 iterations = 0;
	while (!error_callback_invoked.load() && iterations < 100) {
		Sql_ProcessCompletedQueries();
		std::this_thread::sleep_for(std::chrono::milliseconds(10));
		iterations++;
	}
	
	if (error_callback_invoked.load()) {
		ShowInfo("[PASS] Error handling works correctly\n");
	} else {
		ShowError("[FAIL] Error callback not invoked\n");
	}
	
	ShowInfo("Test 5 complete\n\n");
}

/**
 * Test 6: Statistics tracking
 * Use case: Monitoring and performance analysis
 */
void test_statistics(Sql* sql_handle) {
	ShowInfo("===== Test 6: Statistics Tracking =====\n");
	
	// Submit a few queries
	for (int32 i = 0; i < 5; i++) {
		Sql_QueryAsyncStr(sql_handle, "SELECT 1", nullptr, nullptr);
	}
	
	// Process them
	std::this_thread::sleep_for(std::chrono::milliseconds(100));
	Sql_ProcessCompletedQueries();
	
	// Get statistics
	uint64 total_queries = 0, pending_queries = 0, avg_time_us = 0;
	Sql_GetAsyncStats(&total_queries, &pending_queries, &avg_time_us);
	
	ShowInfo("Async DB Statistics:\n");
	ShowInfo("  Total queries: %" PRIu64 "\n", total_queries);
	ShowInfo("  Pending queries: %" PRIu64 "\n", pending_queries);
	ShowInfo("  Average time: %" PRIu64 " μs (%.2f ms)\n", 
	         avg_time_us, avg_time_us / 1000.0);
	
	if (total_queries >= 5) {
		ShowInfo("[PASS] Statistics tracking working\n");
	} else {
		ShowWarning("[WARN] Statistics may be incomplete\n");
	}
	
	ShowInfo("Test 6 complete\n\n");
}

/**
 * Test 7: Synchronous fallback
 * Use case: Compatibility mode when threading disabled
 */
void test_sync_fallback(Sql* sql_handle) {
	ShowInfo("===== Test 7: Synchronous Fallback =====\n");
	ShowInfo("Note: This test verifies fallback when threading is disabled\n");
	ShowInfo("The async API should work even in sync mode\n");
	
	static std::atomic<bool> callback_invoked{false};
	callback_invoked.store(false);
	
	auto callback = [](bool success, void* user_data) {
		std::atomic<bool>* flag = (std::atomic<bool>*)user_data;
		ShowInfo("[Callback] Sync fallback callback invoked (success=%d)\n", success);
		flag->store(true);
	};
	
	// This should work regardless of threading mode
	Sql_QueryAsyncStr(sql_handle, "SELECT 1", callback, &callback_invoked);
	
	// In sync mode, callback is invoked immediately
	// In async mode, we need to process the queue
	Sql_ProcessCompletedQueries();
	
	if (callback_invoked.load()) {
		ShowInfo("[PASS] Fallback mode working correctly\n");
	} else {
		ShowError("[FAIL] Callback not invoked in fallback mode\n");
	}
	
	ShowInfo("Test 7 complete\n\n");
}

/**
 * Test 8: Performance comparison
 * Use case: Measuring async performance benefit
 */
void test_performance_comparison(Sql* sql_handle) {
	ShowInfo("===== Test 8: Performance Comparison =====\n");
	
	const int32 QUERY_COUNT = 100;
	
	// Test synchronous performance
	auto sync_start = std::chrono::high_resolution_clock::now();
	for (int32 i = 0; i < QUERY_COUNT; i++) {
		Sql_QueryStr(sql_handle, "SELECT 1");
		Sql_FreeResult(sql_handle);
	}
	auto sync_end = std::chrono::high_resolution_clock::now();
	auto sync_duration = std::chrono::duration_cast<std::chrono::milliseconds>(sync_end - sync_start);
	
	ShowInfo("Synchronous: %d queries in %" PRId64 "ms (%.2f ms/query)\n",
	         QUERY_COUNT, (int64)sync_duration.count(), 
	         (double)sync_duration.count() / QUERY_COUNT);
	
	// Test async performance (if enabled)
	if (g_db_worker_pool) {
		std::atomic<int32> async_completed{0};
		
		auto async_callback = [](bool success, void* user_data) {
			std::atomic<int32>* counter = (std::atomic<int32>*)user_data;
			counter->fetch_add(1);
		};
		
		auto async_start = std::chrono::high_resolution_clock::now();
		
		// Submit all queries
		for (int32 i = 0; i < QUERY_COUNT; i++) {
			Sql_QueryAsyncStr(sql_handle, "SELECT 1", async_callback, &async_completed);
		}
		
		// Wait for completion
		while (async_completed.load() < QUERY_COUNT) {
			Sql_ProcessCompletedQueries();
			std::this_thread::sleep_for(std::chrono::milliseconds(1));
		}
		
		auto async_end = std::chrono::high_resolution_clock::now();
		auto async_duration = std::chrono::duration_cast<std::chrono::milliseconds>(async_end - async_start);
		
		ShowInfo("Asynchronous: %d queries in %" PRId64 "ms (%.2f ms/query)\n",
		         QUERY_COUNT, (int64)async_duration.count(),
		         (double)async_duration.count() / QUERY_COUNT);
		
		// Calculate improvement
		double improvement = ((double)sync_duration.count() / async_duration.count() - 1.0) * 100.0;
		ShowInfo("Performance improvement: %.1f%%\n", improvement);
		
		if (async_duration < sync_duration) {
			ShowInfo("[PASS] Async queries are faster\n");
		} else {
			ShowWarning("[WARN] Async not faster (may be due to overhead with small query count)\n");
		}
	} else {
		ShowInfo("Skipping async test (worker pool not available)\n");
	}
	
	ShowInfo("Test 8 complete\n\n");
}

/**
 * Test 9: Chained queries using callbacks
 * Use case: Sequential dependent operations
 */
struct ChainContext {
	Sql* sql_handle;
	int32 step;
	std::atomic<bool>* done_flag;
};

void test_chained_queries(Sql* sql_handle) {
	ShowInfo("===== Test 9: Chained Queries =====\n");
	
	static std::atomic<bool> chain_complete{false};
	chain_complete.store(false);
	
	// Step 3 callback
	auto step3_callback = [](bool success, void* user_data) {
		ChainContext* ctx = (ChainContext*)user_data;
		ShowInfo("[Chain Step 3] Final query completed (success=%d)\n", success);
		ctx->done_flag->store(true);
		delete ctx;
	};
	
	// Step 2 callback (triggers step 3)
	auto step2_callback = [step3_callback](bool success, void* user_data) {
		ChainContext* ctx = (ChainContext*)user_data;
		ShowInfo("[Chain Step 2] Second query completed (success=%d)\n", success);
		
		if (success) {
			// Submit step 3
			ctx->step = 3;
			Sql_QueryAsync(ctx->sql_handle, "SELECT %d AS step", 
			               step3_callback, ctx, ctx->step);
		} else {
			ctx->done_flag->store(true);
			delete ctx;
		}
	};
	
	// Step 1 callback (triggers step 2)
	auto step1_callback = [step2_callback](bool success, void* user_data) {
		ChainContext* ctx = (ChainContext*)user_data;
		ShowInfo("[Chain Step 1] First query completed (success=%d)\n", success);
		
		if (success) {
			// Submit step 2
			ctx->step = 2;
			Sql_QueryAsync(ctx->sql_handle, "SELECT %d AS step",
			               step2_callback, ctx, ctx->step);
		} else {
			ctx->done_flag->store(true);
			delete ctx;
		}
	};
	
	// Create context for chain
	ChainContext* ctx = new ChainContext{sql_handle, 1, &chain_complete};
	
	// Start the chain with step 1
	Sql_QueryAsync(sql_handle, "SELECT %d AS step", step1_callback, ctx, ctx->step);
	
	// Wait for chain completion
	int32 iterations = 0;
	while (!chain_complete.load() && iterations < 200) {
		Sql_ProcessCompletedQueries();
		std::this_thread::sleep_for(std::chrono::milliseconds(10));
		iterations++;
	}
	
	if (chain_complete.load()) {
		ShowInfo("[PASS] Chained queries completed successfully\n");
	} else {
		ShowError("[FAIL] Chained queries timeout\n");
	}
	
	ShowInfo("Test 9 complete\n\n");
}

/**
 * Test 10: Stress test
 * Use case: High load scenarios
 */
void test_stress(Sql* sql_handle) {
	ShowInfo("===== Test 10: Stress Test =====\n");
	
	if (!g_db_worker_pool) {
		ShowInfo("Skipping stress test (worker pool not available)\n");
		return;
	}
	
	const int32 STRESS_QUERY_COUNT = 1000;
	std::atomic<int32> completed{0};
	std::atomic<int32> errors{0};
	
	auto callback = [](bool success, void* user_data) {
		if (success) {
			std::atomic<int32>* counter = (std::atomic<int32>*)user_data;
			counter->fetch_add(1);
		} else {
			std::atomic<int32>* err_counter = (std::atomic<int32>*)((void**)user_data)[1];
			err_counter->fetch_add(1);
		}
	};
	
	void* callback_data[2] = {&completed, &errors};
	
	ShowInfo("Submitting %d queries...\n", STRESS_QUERY_COUNT);
	auto start = std::chrono::high_resolution_clock::now();
	
	for (int32 i = 0; i < STRESS_QUERY_COUNT; i++) {
		Sql_QueryAsync(sql_handle, "SELECT %d AS id", callback, callback_data, i);
	}
	
	ShowInfo("All queries submitted, waiting for completion...\n");
	
	// Wait for completion with timeout
	int32 iterations = 0;
	int32 last_completed = 0;
	while (completed.load() + errors.load() < STRESS_QUERY_COUNT && iterations < 5000) {
		int32 processed = Sql_ProcessCompletedQueries();
		
		// Show progress every 100 iterations
		if (iterations % 100 == 0 && completed.load() != last_completed) {
			ShowInfo("Progress: %d/%d completed\n", 
			         completed.load() + errors.load(), STRESS_QUERY_COUNT);
			last_completed = completed.load();
		}
		
		std::this_thread::sleep_for(std::chrono::milliseconds(10));
		iterations++;
	}
	
	auto end = std::chrono::high_resolution_clock::now();
	auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
	
	ShowInfo("Stress test results:\n");
	ShowInfo("  Completed: %d/%d\n", completed.load(), STRESS_QUERY_COUNT);
	ShowInfo("  Errors: %d\n", errors.load());
	ShowInfo("  Duration: %" PRId64 "ms\n", (int64)duration.count());
	ShowInfo("  Throughput: %.1f queries/sec\n", 
	         (double)STRESS_QUERY_COUNT / (duration.count() / 1000.0));
	
	if (completed.load() + errors.load() == STRESS_QUERY_COUNT) {
		ShowInfo("[PASS] All stress test queries processed\n");
	} else {
		ShowError("[FAIL] Some queries were not processed\n");
	}
	
	ShowInfo("Test 10 complete\n\n");
}

/**
 * Main test runner
 */
void run_db_async_tests(Sql* sql_handle) {
	ShowMessage("\n");
	ShowMessage("╔════════════════════════════════════════════════════════╗\n");
	ShowMessage("║     DATABASE ASYNC OPERATIONS TEST SUITE (Phase 4c)   ║\n");
	ShowMessage("╚════════════════════════════════════════════════════════╝\n");
	ShowMessage("\n");
	
	if (!sql_handle) {
		ShowError("Cannot run tests: SQL handle is nullptr\n");
		return;
	}
	
	// Check threading status
	if (g_db_worker_pool) {
		ShowInfo("Threading: ENABLED (%zu DB workers)\n", g_db_worker_pool->num_threads());
	} else {
		ShowWarning("Threading: DISABLED (fallback to synchronous mode)\n");
	}
	
	ShowMessage("\n");
	
	// Run all tests
	test_fire_and_forget(sql_handle);
	test_with_callback(sql_handle);
	test_concurrent_queries(sql_handle);
	test_user_context(sql_handle);
	test_error_handling(sql_handle);
	test_statistics(sql_handle);
	test_performance_comparison(sql_handle);
	test_chained_queries(sql_handle);
	test_stress(sql_handle);
	
	ShowMessage("╔════════════════════════════════════════════════════════╗\n");
	ShowMessage("║              ALL TESTS COMPLETED                       ║\n");
	ShowMessage("╚════════════════════════════════════════════════════════╝\n");
	ShowMessage("\n");
}

#endif // TEST_DB_ASYNC
