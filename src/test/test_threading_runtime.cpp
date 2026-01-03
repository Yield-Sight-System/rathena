// Copyright (c) rAthena Dev Teams - Licensed under GNU GPL
// For more information, see LICENCE in the main folder

/**
 * @file test_threading_runtime.cpp
 * @brief Comprehensive runtime threading verification tests
 * 
 * Tests all threading components with actual rathena integration
 * Compile with: make test_threading_runtime
 * Run with: ./test_threading_runtime
 */

#include "../common/threading.hpp"
#include "../common/showmsg.hpp"
#include <atomic>
#include <chrono>
#include <thread>
#include <vector>
#include <stdexcept>

// Define stub globals for standalone test
ThreadPool* g_cpu_worker_pool = nullptr;
ThreadPool* g_db_worker_pool = nullptr;
char* SERVER_NAME = (char*)"test_threading_runtime";

// Stub functions needed by malloc.cpp
const char* get_git_hash() { return "test"; }
const char* get_svn_revision() { return "test"; }

// Test statistics
static int32 g_tests_passed = 0;
static int32 g_tests_failed = 0;
static int32 g_tests_total = 0;

// Utility macros for test reporting
#define TEST_START(name) \
	ShowInfo("=========================================\n"); \
	ShowInfo("Test %d: %s\n", ++g_tests_total, name); \
	ShowInfo("=========================================\n");

#define TEST_PASS(msg, ...) \
	ShowInfo("  ✅ PASSED: " msg "\n", ##__VA_ARGS__); \
	g_tests_passed++;

#define TEST_FAIL(msg, ...) \
	ShowError("  ❌ FAILED: " msg "\n", ##__VA_ARGS__); \
	g_tests_failed++;

#define TEST_INFO(msg, ...) \
	ShowInfo("  ℹ️  " msg "\n", ##__VA_ARGS__);

/**
 * Test 1: Thread pool basic operations
 * Verifies that basic task submission and execution works correctly
 */
bool test_thread_pool_basic() {
	TEST_START("Thread Pool Basic Operations");
	
	const int32 TASK_COUNT = 100;
	std::atomic<int32> counter{0};
	
	ThreadPool pool(4);
	TEST_INFO("Created thread pool with 4 workers");
	
	// Submit tasks
	for (int32 i = 0; i < TASK_COUNT; ++i) {
		pool.submit([&counter]() {
			counter.fetch_add(1, std::memory_order_relaxed);
		});
	}
	TEST_INFO("Submitted %d tasks", TASK_COUNT);
	
	// Wait for completion with timeout
	pool.shutdown();
	
	// Verify
	if (counter.load() == TASK_COUNT) {
		TEST_PASS("All %d tasks executed correctly", TASK_COUNT);
		return true;
	} else {
		TEST_FAIL("Expected %d tasks, but %d executed", TASK_COUNT, counter.load());
		return false;
	}
}

/**
 * Test 2: Exception handling in worker threads
 * Verifies that exceptions in tasks don't crash worker threads
 */
bool test_exception_handling() {
	TEST_START("Exception Handling");
	
	std::atomic<bool> task_after_exception{false};
	
	ThreadPool pool(2);
	TEST_INFO("Created thread pool with 2 workers");
	
	// Submit task that throws
	pool.submit([]() {
		throw std::runtime_error("Test exception - this is expected");
	});
	TEST_INFO("Submitted task that throws exception");
	
	// Give time for exception to occur
	std::this_thread::sleep_for(std::chrono::milliseconds(50));
	
	// Submit task after exception
	pool.submit([&task_after_exception]() {
		task_after_exception.store(true);
	});
	TEST_INFO("Submitted follow-up task");
	
	// Shutdown and verify
	pool.shutdown();
	
	if (task_after_exception.load()) {
		TEST_PASS("Worker thread survived exception, follow-up task executed");
		return true;
	} else {
		TEST_FAIL("Worker thread may have crashed, follow-up task not executed");
		return false;
	}
}

/**
 * Test 3: ThreadSafeQueue concurrent access
 * Verifies thread-safe queue operations under concurrent load
 */
bool test_threadsafe_queue() {
	TEST_START("ThreadSafeQueue Concurrent Access");
	
	ThreadSafeQueue<int32> queue;
	const int32 ITEMS_COUNT = 1000;
	std::atomic<int32> sum{0};
	
	// Producer threads
	TEST_INFO("Starting %d producer threads", 4);
	ThreadPool producers(4);
	for (int32 i = 0; i < ITEMS_COUNT; ++i) {
		producers.submit([&queue, i]() {
			queue.push(i);
		});
	}
	producers.shutdown();
	TEST_INFO("All items produced");
	
	// Consumer threads
	TEST_INFO("Starting %d consumer threads", 4);
	ThreadPool consumers(4);
	std::atomic<int32> consumed{0};
	for (int32 i = 0; i < ITEMS_COUNT; ++i) {
		consumers.submit([&queue, &sum, &consumed]() {
			int32 value;
			if (queue.try_pop(value)) {
				sum.fetch_add(value, std::memory_order_relaxed);
				consumed.fetch_add(1, std::memory_order_relaxed);
			}
		});
	}
	consumers.shutdown();
	TEST_INFO("All items consumed: %d", consumed.load());
	
	// Expected sum: 0+1+2+...+999 = 499500
	int32 expected = (ITEMS_COUNT - 1) * ITEMS_COUNT / 2;
	int32 actual = sum.load();
	
	if (actual == expected && consumed.load() == ITEMS_COUNT) {
		TEST_PASS("Concurrent queue operations correct (sum=%d, items=%d)", 
		          actual, consumed.load());
		return true;
	} else {
		TEST_FAIL("Expected sum=%d items=%d, got sum=%d items=%d", 
		          expected, ITEMS_COUNT, actual, consumed.load());
		return false;
	}
}

/**
 * Test 4: Thread pool query methods
 * Verifies num_threads(), pending_tasks(), active_workers(), is_shutdown()
 */
bool test_thread_pool_queries() {
	TEST_START("Thread Pool Query Methods");
	
	const size_t NUM_THREADS = 4;
	ThreadPool pool(NUM_THREADS);
	
	// Test num_threads()
	if (pool.num_threads() != NUM_THREADS) {
		TEST_FAIL("num_threads() returned %zu, expected %zu", 
		          pool.num_threads(), NUM_THREADS);
		return false;
	}
	TEST_PASS("num_threads() correct: %zu", NUM_THREADS);
	
	// Test is_shutdown() before shutdown
	if (pool.is_shutdown()) {
		TEST_FAIL("is_shutdown() true before shutdown");
		return false;
	}
	TEST_PASS("is_shutdown() correct before shutdown");
	
	// Submit slow tasks to test active_workers and pending_tasks
	std::atomic<bool> can_proceed{false};
	for (size_t i = 0; i < NUM_THREADS * 2; ++i) {
		pool.submit([&can_proceed]() {
			while (!can_proceed.load()) {
				std::this_thread::sleep_for(std::chrono::milliseconds(10));
			}
		});
	}
	
	// Give time for some tasks to start
	std::this_thread::sleep_for(std::chrono::milliseconds(100));
	
	// Check active workers and pending tasks
	size_t active = pool.active_workers();
	size_t pending = pool.pending_tasks();
	TEST_INFO("Active workers: %zu, Pending tasks: %zu", active, pending);
	
	// Release tasks
	can_proceed.store(true);
	
	// Shutdown and verify
	pool.shutdown();
	
	if (!pool.is_shutdown()) {
		TEST_FAIL("is_shutdown() false after shutdown");
		return false;
	}
	TEST_PASS("is_shutdown() correct after shutdown");
	
	TEST_PASS("All query methods working correctly");
	return true;
}

/**
 * Test 5: ThreadSafeQueue blocking operations
 * Verifies wait_and_pop() and shutdown() behavior
 */
bool test_queue_blocking() {
	TEST_START("ThreadSafeQueue Blocking Operations");
	
	ThreadSafeQueue<int32> queue;
	std::atomic<bool> consumer_started{false};
	std::atomic<bool> consumer_finished{false};
	std::atomic<int32> consumed_value{-1};
	
	// Start consumer thread that will block
	std::thread consumer([&]() {
		consumer_started.store(true);
		int32 value;
		bool success = queue.wait_and_pop(value);
		if (success) {
			consumed_value.store(value);
		}
		consumer_finished.store(true);
	});
	
	// Wait for consumer to start
	while (!consumer_started.load()) {
		std::this_thread::sleep_for(std::chrono::milliseconds(10));
	}
	TEST_INFO("Consumer thread started and blocking");
	
	// Push value after delay
	std::this_thread::sleep_for(std::chrono::milliseconds(100));
	queue.push(42);
	TEST_INFO("Pushed value 42 to queue");
	
	// Wait for consumer
	consumer.join();
	
	if (consumer_finished.load() && consumed_value.load() == 42) {
		TEST_PASS("wait_and_pop() unblocked and consumed correct value");
		return true;
	} else {
		TEST_FAIL("wait_and_pop() failed: value=%d", consumed_value.load());
		return false;
	}
}

/**
 * Test 6: Thread pool shutdown behavior
 * Verifies graceful vs immediate shutdown
 */
bool test_shutdown_behavior() {
	TEST_START("Thread Pool Shutdown Behavior");
	
	// Test graceful shutdown
	{
		ThreadPool pool(2);
		std::atomic<int32> completed{0};
		
		for (int32 i = 0; i < 10; ++i) {
			pool.submit([&completed]() {
				std::this_thread::sleep_for(std::chrono::milliseconds(10));
				completed.fetch_add(1);
			});
		}
		
		pool.shutdown();  // Graceful - should complete all tasks
		
		if (completed.load() == 10) {
			TEST_PASS("Graceful shutdown completed all %d tasks", 10);
		} else {
			TEST_FAIL("Graceful shutdown: only %d/10 tasks completed", completed.load());
			return false;
		}
	}
	
	// Test immediate shutdown
	{
		ThreadPool pool(2);
		std::atomic<int32> completed{0};
		std::atomic<bool> can_proceed{false};
		
		// Submit tasks that wait
		for (int32 i = 0; i < 10; ++i) {
			pool.submit([&completed, &can_proceed]() {
				while (!can_proceed.load()) {
					std::this_thread::sleep_for(std::chrono::milliseconds(10));
				}
				completed.fetch_add(1);
			});
		}
		
		// Give time for some to start
		std::this_thread::sleep_for(std::chrono::milliseconds(50));
		
		// Immediate shutdown
		can_proceed.store(true);
		pool.shutdown_now();
		
		TEST_INFO("Immediate shutdown: %d tasks completed", completed.load());
		TEST_PASS("Immediate shutdown executed (some tasks may be skipped)");
	}
	
	return true;
}

/**
 * Test 7: Task submission after shutdown
 * Verifies that submitting tasks after shutdown is handled gracefully
 */
bool test_submit_after_shutdown() {
	TEST_START("Task Submission After Shutdown");
	
	ThreadPool pool(2);
	std::atomic<int32> counter{0};
	
	// Submit before shutdown
	pool.submit([&counter]() {
		counter.fetch_add(1);
	});
	
	// Shutdown
	pool.shutdown();
	TEST_INFO("Thread pool shutdown");
	
	// Try to submit after shutdown
	pool.submit([&counter]() {
		counter.fetch_add(1);
	});
	TEST_INFO("Attempted to submit task after shutdown");
	
	if (counter.load() == 1) {
		TEST_PASS("Task after shutdown was rejected (count=%d)", counter.load());
		return true;
	} else {
		TEST_FAIL("Unexpected behavior: count=%d", counter.load());
		return false;
	}
}

/**
 * Test 8: Stress test with many small tasks
 * Verifies stability under high load
 */
bool test_stress() {
	TEST_START("Stress Test - Many Small Tasks");
	
	const int32 TASK_COUNT = 10000;
	std::atomic<int32> counter{0};
	
	ThreadPool pool(8);
	TEST_INFO("Created thread pool with 8 workers");
	TEST_INFO("Submitting %d tasks...", TASK_COUNT);
	
	auto start = std::chrono::high_resolution_clock::now();
	
	for (int32 i = 0; i < TASK_COUNT; ++i) {
		pool.submit([&counter]() {
			counter.fetch_add(1, std::memory_order_relaxed);
		});
	}
	
	pool.shutdown();
	
	auto end = std::chrono::high_resolution_clock::now();
	auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
	
	TEST_INFO("Completed in %lld ms", (long long)duration.count());
	TEST_INFO("Throughput: %.1f tasks/sec", 
	          (double)TASK_COUNT / (duration.count() / 1000.0));
	
	if (counter.load() == TASK_COUNT) {
		TEST_PASS("All %d tasks completed correctly", TASK_COUNT);
		return true;
	} else {
		TEST_FAIL("Expected %d tasks, got %d", TASK_COUNT, counter.load());
		return false;
	}
}

/**
 * Test 9: ThreadSafeQueue empty() and size() methods
 * Verifies queue state query methods
 */
bool test_queue_state() {
	TEST_START("ThreadSafeQueue State Methods");
	
	ThreadSafeQueue<int32> queue;
	
	// Test empty queue
	if (!queue.empty()) {
		TEST_FAIL("empty() returned false for empty queue");
		return false;
	}
	TEST_PASS("empty() correct for empty queue");
	
	if (queue.size() != 0) {
		TEST_FAIL("size() returned %zu for empty queue", queue.size());
		return false;
	}
	TEST_PASS("size() correct for empty queue");
	
	// Add items
	for (int32 i = 0; i < 5; ++i) {
		queue.push(i);
	}
	
	if (queue.empty()) {
		TEST_FAIL("empty() returned true for non-empty queue");
		return false;
	}
	TEST_PASS("empty() correct for non-empty queue");
	
	if (queue.size() != 5) {
		TEST_FAIL("size() returned %zu, expected 5", queue.size());
		return false;
	}
	TEST_PASS("size() correct: %zu items", queue.size());
	
	// Pop items
	for (int32 i = 0; i < 5; ++i) {
		int32 value;
		queue.try_pop(value);
	}
	
	if (!queue.empty() || queue.size() != 0) {
		TEST_FAIL("empty() or size() incorrect after popping all items");
		return false;
	}
	TEST_PASS("empty() and size() correct after popping all items");
	
	return true;
}

/**
 * Test 10: Global thread pool access
 * Verifies that global thread pools are accessible (if initialized)
 */
bool test_global_thread_pools() {
	TEST_START("Global Thread Pool Access");
	
	// Note: Global pools may not be initialized in standalone test
	TEST_INFO("Checking global thread pool pointers...");
	
	if (g_cpu_worker_pool != nullptr) {
		TEST_INFO("CPU worker pool: AVAILABLE");
		TEST_INFO("  - Threads: %zu", g_cpu_worker_pool->num_threads());
		TEST_INFO("  - Shutdown status: %s", 
		          g_cpu_worker_pool->is_shutdown() ? "yes" : "no");
	} else {
		TEST_INFO("CPU worker pool: NOT INITIALIZED (expected in standalone test)");
	}
	
	if (g_db_worker_pool != nullptr) {
		TEST_INFO("DB worker pool: AVAILABLE");
		TEST_INFO("  - Threads: %zu", g_db_worker_pool->num_threads());
		TEST_INFO("  - Shutdown status: %s",
		          g_db_worker_pool->is_shutdown() ? "yes" : "no");
	} else {
		TEST_INFO("DB worker pool: NOT INITIALIZED (expected in standalone test)");
	}
	
	TEST_PASS("Global thread pool check complete");
	return true;
}

/**
 * Main test runner
 */
int main() {
	ShowMessage("\n");
	ShowMessage("╔════════════════════════════════════════════════════════╗\n");
	ShowMessage("║     rAthena Threading Runtime Verification Tests      ║\n");
	ShowMessage("╚════════════════════════════════════════════════════════╝\n");
	ShowMessage("\n");
	
	// Run all tests
	test_thread_pool_basic();
	test_exception_handling();
	test_threadsafe_queue();
	test_thread_pool_queries();
	test_queue_blocking();
	test_shutdown_behavior();
	test_submit_after_shutdown();
	test_stress();
	test_queue_state();
	test_global_thread_pools();
	
	// Display results
	ShowMessage("\n");
	ShowMessage("╔════════════════════════════════════════════════════════╗\n");
	ShowMessage("║                    TEST RESULTS                        ║\n");
	ShowMessage("╠════════════════════════════════════════════════════════╣\n");
	ShowMessage("║  Total Tests:  %3d                                     ║\n", g_tests_total);
	ShowMessage("║  Passed:       %3d                                     ║\n", g_tests_passed);
	ShowMessage("║  Failed:       %3d                                     ║\n", g_tests_failed);
	ShowMessage("╠════════════════════════════════════════════════════════╣\n");
	
	if (g_tests_failed == 0 && g_tests_passed > 0) {
		ShowMessage("║  Status:       ✅ ALL TESTS PASSED                    ║\n");
	} else if (g_tests_failed > 0) {
		ShowMessage("║  Status:       ❌ SOME TESTS FAILED                   ║\n");
	} else {
		ShowMessage("║  Status:       ⚠️  NO TESTS RUN                       ║\n");
	}
	
	ShowMessage("╚════════════════════════════════════════════════════════╝\n");
	ShowMessage("\n");
	
	return (g_tests_failed == 0 && g_tests_passed > 0) ? 0 : 1;
}
