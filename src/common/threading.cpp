// Copyright (c) rAthena Dev Teams - Licensed under GNU GPL
// For more information, see LICENCE in the main folder

#include "threading.hpp"

#include <exception>
#include <system_error>

// Platform-specific includes for thread naming
#ifdef __linux__
	#include <pthread.h>
#elif defined(_WIN32)
	// Windows thread naming available in Windows 10+
	// We'll skip it for now to maintain compatibility
#endif

/**
 * @brief Constructor - Creates and starts worker threads
 * 
 * @param num_threads Number of worker threads to create
 */
ThreadPool::ThreadPool(size_t num_threads)
	: active_workers_(0)
	, shutdown_(false)
	, shutdown_now_(false)
{
	// Ensure at least one thread
	if (num_threads == 0) {
		num_threads = 1;
		ShowWarning("ThreadPool: num_threads was 0, using 1 thread instead\n");
	}
	
	ShowInfo("ThreadPool: Initializing with %zu worker threads\n", num_threads);
	
	try {
		// Reserve space to avoid reallocations during thread creation
		workers_.reserve(num_threads);
		
		// Create worker threads
		for (size_t i = 0; i < num_threads; ++i) {
			workers_.emplace_back(&ThreadPool::worker_thread, this);
		}
		
		ShowInfo("ThreadPool: Successfully created %zu worker threads\n", num_threads);
	}
	catch (const std::system_error& e) {
		ShowError("ThreadPool: Failed to create worker threads: %s\n", e.what());
		// Clean up any threads that were created
		shutdown_now();
		throw;
	}
	catch (const std::exception& e) {
		ShowError("ThreadPool: Unexpected error during initialization: %s\n", e.what());
		shutdown_now();
		throw;
	}
}

/**
 * @brief Destructor - Ensures graceful shutdown
 */
ThreadPool::~ThreadPool() {
	if (!shutdown_.load(std::memory_order_acquire)) {
		ShowInfo("ThreadPool: Destructor called without explicit shutdown, performing graceful shutdown\n");
		shutdown();
	}
}

/**
 * @brief Main worker thread loop
 * 
 * Each worker continuously fetches and executes tasks until shutdown is signaled.
 */
void ThreadPool::worker_thread() {
	// Optional: Set thread name for debugging (Linux only)
#ifdef __linux__
	pthread_setname_np(pthread_self(), "rathena-worker");
#endif
	
	while (!shutdown_now_.load(std::memory_order_acquire)) {
		Task task;
		
		// Wait for a task (blocking)
		if (!tasks_.wait_and_pop(task)) {
			// Shutdown was signaled and no more tasks
			break;
		}
		
		// Check if we got a valid task
		if (!task) {
			continue;
		}
		
		// Increment active worker count
		active_workers_.fetch_add(1, std::memory_order_acq_rel);
		
		// Execute the task with exception handling
		try {
			task();
		}
		catch (const std::exception& e) {
			// Log the exception but don't crash the worker thread
			ShowError("ThreadPool: Task threw exception: %s\n", e.what());
		}
		catch (...) {
			// Catch any other exceptions
			ShowError("ThreadPool: Task threw unknown exception\n");
		}
		
		// Decrement active worker count
		active_workers_.fetch_sub(1, std::memory_order_acq_rel);
	}
}

/**
 * @brief Gracefully shutdown the thread pool
 * 
 * Waits for all pending tasks to complete before stopping workers.
 */
void ThreadPool::shutdown() {
	// Check if already shutdown (avoid double shutdown)
	if (shutdown_.exchange(true, std::memory_order_acq_rel)) {
		ShowWarning("ThreadPool: shutdown() called but already shutdown\n");
		return;
	}
	
	ShowInfo("ThreadPool: Initiating graceful shutdown...\n");
	
	// Signal the task queue to stop accepting new tasks and wake up waiting threads
	tasks_.shutdown();
	
	// Wait for all worker threads to complete
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

/**
 * @brief Immediately shutdown the thread pool
 * 
 * Stops accepting new tasks and signals workers to stop after current task.
 */
void ThreadPool::shutdown_now() {
	// Set both shutdown flags
	shutdown_.store(true, std::memory_order_release);
	shutdown_now_.store(true, std::memory_order_release);
	
	ShowInfo("ThreadPool: Initiating immediate shutdown...\n");
	
	// Signal the task queue to wake up all waiting threads
	tasks_.shutdown();
	
	// Wait for all worker threads to complete their current task
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

/**
 * @brief Get the number of worker threads
 */
size_t ThreadPool::num_threads() const {
	return workers_.size();
}

/**
 * @brief Get the number of pending tasks
 */
size_t ThreadPool::pending_tasks() const {
	return tasks_.size();
}

/**
 * @brief Get the number of active workers
 */
size_t ThreadPool::active_workers() const {
	return active_workers_.load(std::memory_order_acquire);
}

/**
 * @brief Check if the pool has been shutdown
 */
bool ThreadPool::is_shutdown() const {
	return shutdown_.load(std::memory_order_acquire);
}
