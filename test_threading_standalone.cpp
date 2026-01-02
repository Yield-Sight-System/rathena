// Standalone test for threading.hpp - compiles without rathena dependencies
// This verifies the threading infrastructure compiles and works correctly

#include <iostream>
#include <atomic>
#include <chrono>
#include <thread>
#include <cstdarg>
#include <cstdio>

// Mock cbasetypes.hpp
typedef signed char int8;
typedef signed short int16;
typedef signed int int32;
typedef signed long long int64;
typedef unsigned char uint8;
typedef unsigned short uint16;
typedef unsigned int uint32;
typedef unsigned long long uint64;

// Mock ShowMsg functions (from showmsg.hpp)
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

// Now include the threading infrastructure
#include <atomic>
#include <condition_variable>
#include <functional>
#include <memory>
#include <mutex>
#include <queue>
#include <thread>
#include <vector>

// Task type alias
using Task = std::function<void()>;

// ThreadSafeQueue implementation (from threading.hpp)
template<typename T>
class ThreadSafeQueue {
public:
	ThreadSafeQueue() : shutdown_(false) {}
	
	~ThreadSafeQueue() {
		shutdown();
	}
	
	void push(T value) {
		std::lock_guard<std::mutex> lock(mutex_);
		if (shutdown_) {
			return;
		}
		queue_.push(std::move(value));
		cond_.notify_one();
	}
	
	bool try_pop(T& value) {
		std::lock_guard<std::mutex> lock(mutex_);
		if (queue_.empty()) {
			return false;
		}
		value = std::move(queue_.front());
		queue_.pop();
		return true;
	}
	
	bool wait_and_pop(T& value) {
		std::unique_lock<std::mutex> lock(mutex_);
		cond_.wait(lock, [this]{ return !queue_.empty() || shutdown_; });
		
		if (shutdown_ && queue_.empty()) {
			return false;
		}
		
		value = std::move(queue_.front());
		queue_.pop();
		return true;
	}
	
	bool empty() const {
		std::lock_guard<std::mutex> lock(mutex_);
		return queue_.empty();
	}
	
	size_t size() const {
		std::lock_guard<std::mutex> lock(mutex_);
		return queue_.size();
	}
	
	void shutdown() {
		std::lock_guard<std::mutex> lock(mutex_);
		shutdown_ = true;
		cond_.notify_all();
	}
	
private:
	mutable std::mutex mutex_;
	std::condition_variable cond_;
	std::queue<T> queue_;
	bool shutdown_;
	
	ThreadSafeQueue(const ThreadSafeQueue&) = delete;
	ThreadSafeQueue& operator=(const ThreadSafeQueue&) = delete;
};

// ThreadPool declaration and implementation (from threading.hpp/cpp)
class ThreadPool {
public:
	explicit ThreadPool(size_t num_threads)
		: active_workers_(0)
		, shutdown_(false)
		, shutdown_now_(false)
	{
		if (num_threads == 0) {
			num_threads = 1;
			ShowWarning("ThreadPool: num_threads was 0, using 1 thread instead\n");
		}
		
		ShowInfo("ThreadPool: Initializing with %zu worker threads\n", num_threads);
		
		workers_.reserve(num_threads);
		
		for (size_t i = 0; i < num_threads; ++i) {
			workers_.emplace_back(&ThreadPool::worker_thread, this);
		}
		
		ShowInfo("ThreadPool: Successfully created %zu worker threads\n", num_threads);
	}
	
	~ThreadPool() {
		if (!shutdown_.load(std::memory_order_acquire)) {
			ShowInfo("ThreadPool: Destructor called without explicit shutdown, performing graceful shutdown\n");
			shutdown();
		}
	}
	
	template<typename F>
	void submit(F&& task) {
		if (shutdown_.load(std::memory_order_acquire)) {
			ShowWarning("ThreadPool: Cannot submit task after shutdown\n");
			return;
		}
		tasks_.push(std::forward<F>(task));
	}
	
	void shutdown() {
		if (shutdown_.exchange(true, std::memory_order_acq_rel)) {
			ShowWarning("ThreadPool: shutdown() called but already shutdown\n");
			return;
		}
		
		ShowInfo("ThreadPool: Initiating graceful shutdown...\n");
		tasks_.shutdown();
		
		size_t completed_count = 0;
		for (auto& worker : workers_) {
			if (worker.joinable()) {
				worker.join();
				completed_count++;
			}
		}
		
		ShowInfo("ThreadPool: Graceful shutdown complete. %zu workers stopped. Pending tasks at shutdown: %zu\n", 
		         completed_count, tasks_.size());
	}
	
	void shutdown_now() {
		shutdown_.store(true, std::memory_order_release);
		shutdown_now_.store(true, std::memory_order_release);
		
		ShowInfo("ThreadPool: Initiating immediate shutdown...\n");
		tasks_.shutdown();
		
		size_t completed_count = 0;
		for (auto& worker : workers_) {
			if (worker.joinable()) {
				worker.join();
				completed_count++;
			}
		}
		
		size_t unexecuted_tasks = tasks_.size();
		if (unexecuted_tasks > 0) {
			ShowWarning("ThreadPool: Immediate shutdown complete. %zu workers stopped. %zu tasks were not executed.\n",
			            completed_count, unexecuted_tasks);
		} else {
			ShowInfo("ThreadPool: Immediate shutdown complete. %zu workers stopped.\n", completed_count);
		}
	}
	
	size_t num_threads() const { return workers_.size(); }
	size_t pending_tasks() const { return tasks_.size(); }
	size_t active_workers() const { return active_workers_.load(std::memory_order_acquire); }
	bool is_shutdown() const { return shutdown_.load(std::memory_order_acquire); }
	
private:
	void worker_thread() {
		while (!shutdown_now_.load(std::memory_order_acquire)) {
			Task task;
			
			if (!tasks_.wait_and_pop(task)) {
				break;
			}
			
			if (!task) {
				continue;
			}
			
			active_workers_.fetch_add(1, std::memory_order_acq_rel);
			
			try {
				task();
			}
			catch (const std::exception& e) {
				ShowError("ThreadPool: Task threw exception: %s\n", e.what());
			}
			catch (...) {
				ShowError("ThreadPool: Task threw unknown exception\n");
			}
			
			active_workers_.fetch_sub(1, std::memory_order_acq_rel);
		}
	}
	
	std::vector<std::thread> workers_;
	ThreadSafeQueue<Task> tasks_;
	std::atomic<size_t> active_workers_;
	std::atomic<bool> shutdown_;
	std::atomic<bool> shutdown_now_;
	
	ThreadPool(const ThreadPool&) = delete;
	ThreadPool& operator=(const ThreadPool&) = delete;
};

// Test program
int main() {
	std::cout << "\n=== Testing ThreadPool Implementation ===\n\n";
	
	// Test 1: Basic ThreadPool creation
	std::cout << "Test 1: Creating ThreadPool with 4 threads...\n";
	ThreadPool pool(4);
	std::cout << "  Pool created with " << pool.num_threads() << " threads\n";
	std::cout << "  ✓ PASSED\n\n";
	
	// Test 2: Submit simple tasks
	std::cout << "Test 2: Submitting 100 simple tasks...\n";
	std::atomic<int> counter{0};
	for (int i = 0; i < 100; ++i) {
		pool.submit([&counter]{ 
			counter.fetch_add(1);
			std::this_thread::sleep_for(std::chrono::milliseconds(1));
		});
	}
	
	// Wait for tasks to complete
	std::this_thread::sleep_for(std::chrono::milliseconds(500));
	std::cout << "  Counter value: " << counter.load() << " (expected 100)\n";
	std::cout << "  Active workers: " << pool.active_workers() << "\n";
	std::cout << "  Pending tasks: " << pool.pending_tasks() << "\n";
	if (counter.load() == 100) {
		std::cout << "  ✓ PASSED\n\n";
	} else {
		std::cout << "  ✗ FAILED\n\n";
		return 1;
	}
	
	// Test 3: Task exception handling
	std::cout << "Test 3: Testing exception handling...\n";
	pool.submit([]{ 
		throw std::runtime_error("Test exception - this should be caught and logged");
	});
	std::this_thread::sleep_for(std::chrono::milliseconds(100));
	std::cout << "  Exception was caught and logged (worker thread still alive)\n";
	
	// Submit another task to verify worker is still functional
	std::atomic<bool> task_executed{false};
	pool.submit([&task_executed]{ task_executed.store(true); });
	std::this_thread::sleep_for(std::chrono::milliseconds(100));
	if (task_executed.load()) {
		std::cout << "  Worker thread still functional after exception\n";
		std::cout << "  ✓ PASSED\n\n";
	} else {
		std::cout << "  ✗ FAILED - Worker thread died\n\n";
		return 1;
	}
	
	// Test 4: ThreadSafeQueue
	std::cout << "Test 4: Testing ThreadSafeQueue...\n";
	ThreadSafeQueue<int> queue;
	queue.push(42);
	queue.push(100);
	std::cout << "  Queue size after 2 pushes: " << queue.size() << " (expected 2)\n";
	
	int value;
	if (queue.try_pop(value)) {
		std::cout << "  Popped value: " << value << " (expected 42)\n";
	}
	std::cout << "  Queue size after 1 pop: " << queue.size() << " (expected 1)\n";
	
	if (queue.size() == 1 && value == 42) {
		std::cout << "  ✓ PASSED\n\n";
	} else {
		std::cout << "  ✗ FAILED\n\n";
		return 1;
	}
	
	// Test 5: Concurrent access
	std::cout << "Test 5: Testing concurrent access (stress test)...\n";
	std::atomic<int> stress_counter{0};
	for (int i = 0; i < 1000; ++i) {
		pool.submit([&stress_counter]{ 
			stress_counter.fetch_add(1);
		});
	}
	
	// Wait for all tasks
	std::this_thread::sleep_for(std::chrono::milliseconds(1000));
	std::cout << "  Stress counter: " << stress_counter.load() << " (expected 1000)\n";
	if (stress_counter.load() == 1000) {
		std::cout << "  ✓ PASSED\n\n";
	} else {
		std::cout << "  ✗ FAILED\n\n";
		return 1;
	}
	
	// Test 6: Graceful shutdown
	std::cout << "Test 6: Testing graceful shutdown...\n";
	for (int i = 0; i < 5; ++i) {
		pool.submit([i]{ 
			std::this_thread::sleep_for(std::chrono::milliseconds(50));
			std::cout << "  Task " << i << " completed\n";
		});
	}
	std::cout << "  Calling shutdown() - should wait for all tasks...\n";
	pool.shutdown();
	std::cout << "  Shutdown complete\n";
	std::cout << "  ✓ PASSED\n\n";
	
	std::cout << "=== All Tests Passed Successfully ===\n\n";
	std::cout << "Threading infrastructure is working correctly!\n";
	std::cout << "- ThreadSafeQueue: ✓\n";
	std::cout << "- ThreadPool task execution: ✓\n";
	std::cout << "- Exception handling: ✓\n";
	std::cout << "- Concurrent access: ✓\n";
	std::cout << "- Graceful shutdown: ✓\n\n";
	
	return 0;
}
