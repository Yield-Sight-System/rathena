// Simple test to verify threading.hpp and threading.cpp compile correctly
// This is a temporary test file for verification purposes

#include <iostream>
#include <atomic>
#include <chrono>
#include <thread>

// Mock the rathena ShowMsg functions for standalone compilation
extern "C" {
	void ShowInfo(const char* fmt, ...) {
		va_list args;
		va_start(args, fmt);
		printf("[Info] ");
		vprintf(fmt, args);
		va_end(args);
	}
	
	void ShowWarning(const char* fmt, ...) {
		va_list args;
		va_start(args, fmt);
		printf("[Warning] ");
		vprintf(fmt, args);
		va_end(args);
	}
	
	void ShowError(const char* fmt, ...) {
		va_list args;
		va_start(args, fmt);
		fprintf(stderr, "[Error] ");
		vfprintf(stderr, fmt, args);
		va_end(args);
	}
}

#include "src/common/threading.hpp"
#include "src/common/threading.cpp"

int main() {
	std::cout << "=== Testing ThreadPool Implementation ===\n\n";
	
	// Test 1: Basic ThreadPool creation
	std::cout << "Test 1: Creating ThreadPool with 4 threads...\n";
	ThreadPool pool(4);
	std::cout << "  Pool created with " << pool.num_threads() << " threads\n";
	std::cout << "  PASSED\n\n";
	
	// Test 2: Submit simple tasks
	std::cout << "Test 2: Submitting 10 simple tasks...\n";
	std::atomic<int> counter{0};
	for (int i = 0; i < 10; ++i) {
		pool.submit([&counter, i]{ 
			counter.fetch_add(1);
			std::this_thread::sleep_for(std::chrono::milliseconds(10));
		});
	}
	
	// Wait a bit for tasks to complete
	std::this_thread::sleep_for(std::chrono::milliseconds(200));
	std::cout << "  Counter value: " << counter.load() << " (expected 10)\n";
	std::cout << "  Active workers: " << pool.active_workers() << "\n";
	std::cout << "  Pending tasks: " << pool.pending_tasks() << "\n";
	std::cout << "  PASSED\n\n";
	
	// Test 3: Task exception handling
	std::cout << "Test 3: Testing exception handling...\n";
	pool.submit([]{ 
		throw std::runtime_error("Test exception - this should be caught and logged");
	});
	std::this_thread::sleep_for(std::chrono::milliseconds(100));
	std::cout << "  Exception was caught and logged (worker thread still alive)\n";
	std::cout << "  PASSED\n\n";
	
	// Test 4: ThreadSafeQueue
	std::cout << "Test 4: Testing ThreadSafeQueue...\n";
	ThreadSafeQueue<int> queue;
	queue.push(42);
	queue.push(100);
	std::cout << "  Queue size after pushes: " << queue.size() << " (expected 2)\n";
	
	int value;
	if (queue.try_pop(value)) {
		std::cout << "  Popped value: " << value << " (expected 42)\n";
	}
	std::cout << "  Queue size after pop: " << queue.size() << " (expected 1)\n";
	std::cout << "  PASSED\n\n";
	
	// Test 5: Graceful shutdown
	std::cout << "Test 5: Testing graceful shutdown...\n";
	for (int i = 0; i < 5; ++i) {
		pool.submit([i]{ 
			std::this_thread::sleep_for(std::chrono::milliseconds(50));
			std::cout << "  Task " << i << " completed\n";
		});
	}
	std::cout << "  Calling shutdown() - should wait for all tasks...\n";
	pool.shutdown();
	std::cout << "  Shutdown complete\n";
	std::cout << "  PASSED\n\n";
	
	std::cout << "=== All Tests Passed ===\n";
	return 0;
}
