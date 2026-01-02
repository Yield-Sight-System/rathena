// Copyright (c) rAthena Dev Teams - Licensed under GNU GPL
// For more information, see LICENCE in the main folder

#ifndef THREADING_HPP
#define THREADING_HPP

#include <atomic>
#include <condition_variable>
#include <functional>
#include <memory>
#include <mutex>
#include <queue>
#include <thread>
#include <vector>

#include "cbasetypes.hpp"
#include "showmsg.hpp"

/**
 * @brief Type alias for task functions
 * 
 * Tasks are callable objects that take no parameters and return void.
 * They can be lambdas, function pointers, or functors.
 */
using Task = std::function<void()>;

/**
 * @brief Thread-safe queue implementation using mutex and condition variables
 * 
 * This template class provides a thread-safe queue with blocking and non-blocking operations.
 * All operations are thread-safe and can be called from multiple threads concurrently.
 * 
 * Features:
 * - Blocking pop operation (wait_and_pop) that waits until an item is available
 * - Non-blocking pop operation (try_pop) that returns immediately
 * - Thread-safe push operation with notification
 * - Graceful shutdown mechanism to stop blocking operations
 * 
 * Example usage:
 * @code
 * ThreadSafeQueue<int> queue;
 * 
 * // Producer thread
 * queue.push(42);
 * 
 * // Consumer thread (blocking)
 * int value;
 * queue.wait_and_pop(value);  // Blocks until item available
 * 
 * // Consumer thread (non-blocking)
 * if (queue.try_pop(value)) {
 *     // Process value
 * }
 * 
 * // Shutdown
 * queue.shutdown();  // Wakes up all waiting threads
 * @endcode
 * 
 * @tparam T Type of elements stored in the queue. Must be moveable or copyable.
 * 
 * @note Thread Safety: All operations are thread-safe
 * @note Exception Safety: Strong exception guarantee for push, basic guarantee for pop operations
 */
template<typename T>
class ThreadSafeQueue {
public:
	/**
	 * @brief Construct a new ThreadSafeQueue
	 */
	ThreadSafeQueue() : shutdown_(false) {}
	
	/**
	 * @brief Destructor ensures proper cleanup
	 */
	~ThreadSafeQueue() {
		shutdown();
	}
	
	/**
	 * @brief Push a value onto the queue
	 * 
	 * This operation is thread-safe. After pushing, one waiting thread (if any)
	 * will be notified that an item is available.
	 * 
	 * @param value The value to push (will be moved if possible)
	 * 
	 * @note If shutdown has been called, this operation silently returns without pushing
	 * @note Time Complexity: O(1) amortized
	 */
	void push(T value) {
		std::lock_guard<std::mutex> lock(mutex_);
		if (shutdown_) {
			return;  // Don't accept new items after shutdown
		}
		queue_.push(std::move(value));
		cond_.notify_one();
	}
	
	/**
	 * @brief Try to pop a value without blocking
	 * 
	 * This operation attempts to pop a value from the queue. If the queue is empty,
	 * it returns immediately with false.
	 * 
	 * @param[out] value Reference to store the popped value if successful
	 * @return true if a value was successfully popped, false if queue was empty
	 * 
	 * @note Thread-safe: Can be called from multiple threads
	 * @note Time Complexity: O(1)
	 */
	bool try_pop(T& value) {
		std::lock_guard<std::mutex> lock(mutex_);
		if (queue_.empty()) {
			return false;
		}
		value = std::move(queue_.front());
		queue_.pop();
		return true;
	}
	
	/**
	 * @brief Wait for and pop a value from the queue (blocking)
	 * 
	 * This operation blocks until either:
	 * 1. An item becomes available in the queue, OR
	 * 2. shutdown() is called
	 * 
	 * @param[out] value Reference to store the popped value if successful
	 * @return true if a value was successfully popped, false if shutdown was called
	 * 
	 * @note This function may block indefinitely if no items are pushed and shutdown is not called
	 * @note Thread-safe: Can be called from multiple threads
	 * @note Immune to spurious wakeups
	 */
	bool wait_and_pop(T& value) {
		std::unique_lock<std::mutex> lock(mutex_);
		cond_.wait(lock, [this]{ return !queue_.empty() || shutdown_; });
		
		if (shutdown_ && queue_.empty()) {
			return false;  // Shutdown initiated and no more items
		}
		
		value = std::move(queue_.front());
		queue_.pop();
		return true;
	}
	
	/**
	 * @brief Check if the queue is empty
	 * 
	 * @return true if the queue is empty, false otherwise
	 * 
	 * @note Thread-safe: Can be called from multiple threads
	 * @note The result may become stale immediately after the call returns
	 */
	bool empty() const {
		std::lock_guard<std::mutex> lock(mutex_);
		return queue_.empty();
	}
	
	/**
	 * @brief Get the current size of the queue
	 * 
	 * @return Number of elements in the queue
	 * 
	 * @note Thread-safe: Can be called from multiple threads
	 * @note The result may become stale immediately after the call returns
	 */
	size_t size() const {
		std::lock_guard<std::mutex> lock(mutex_);
		return queue_.size();
	}
	
	/**
	 * @brief Initiate graceful shutdown of the queue
	 * 
	 * After calling this function:
	 * - All threads waiting in wait_and_pop() will be woken up
	 * - Further push() operations will be silently ignored
	 * - Existing items can still be popped
	 * 
	 * This function is idempotent - it's safe to call multiple times.
	 * 
	 * @note Thread-safe: Can be called from multiple threads
	 */
	void shutdown() {
		std::lock_guard<std::mutex> lock(mutex_);
		shutdown_ = true;
		cond_.notify_all();  // Wake up all waiting threads
	}
	
private:
	mutable std::mutex mutex_;           ///< Protects access to queue and shutdown flag
	std::condition_variable cond_;        ///< Notifies waiting threads of new items
	std::queue<T> queue_;                 ///< Underlying queue storage
	bool shutdown_;                       ///< Flag indicating shutdown has been requested
	
	// Disable copy and assignment
	ThreadSafeQueue(const ThreadSafeQueue&) = delete;
	ThreadSafeQueue& operator=(const ThreadSafeQueue&) = delete;
};

/**
 * @brief Thread pool for executing tasks concurrently
 * 
 * ThreadPool manages a fixed number of worker threads that execute submitted tasks.
 * Tasks are queued and executed in FIFO order by available worker threads.
 * 
 * Features:
 * - Fixed-size pool of worker threads
 * - Thread-safe task submission
 * - Graceful and immediate shutdown modes
 * - Exception handling for tasks (exceptions are caught and logged)
 * - Query pool state (active workers, pending tasks)
 * 
 * Example usage:
 * @code
 * ThreadPool pool(4);  // Create pool with 4 worker threads
 * 
 * // Submit tasks
 * pool.submit([]{ 
 *     ShowInfo("Task executed on worker thread\n"); 
 * });
 * 
 * pool.submit([]{
 *     // Do some work
 *     ShowInfo("Another task\n");
 * });
 * 
 * // Query state
 * ShowInfo("Pending tasks: %zu\n", pool.pending_tasks());
 * ShowInfo("Active workers: %zu\n", pool.active_workers());
 * 
 * // Graceful shutdown - wait for all tasks to complete
 * pool.shutdown();
 * @endcode
 * 
 * @note All public methods are thread-safe
 * @note Tasks should not block for extended periods
 * @note Task exceptions are caught and logged, they don't terminate the worker thread
 */
class ThreadPool {
public:
	/**
	 * @brief Construct a ThreadPool with specified number of worker threads
	 * 
	 * Creates and starts the specified number of worker threads immediately.
	 * Each worker will wait for tasks to be submitted.
	 * 
	 * @param num_threads Number of worker threads to create. Should typically
	 *                    be <= hardware thread count for CPU-bound tasks.
	 * 
	 * @throws std::system_error if thread creation fails
	 * 
	 * @note If num_threads is 0, creates 1 thread (minimum viable pool)
	 */
	explicit ThreadPool(size_t num_threads);
	
	/**
	 * @brief Destructor - performs graceful shutdown if not already shutdown
	 * 
	 * If shutdown() hasn't been called, this will call it automatically,
	 * waiting for all pending tasks to complete.
	 */
	~ThreadPool();
	
	/**
	 * @brief Submit a task to the thread pool
	 * 
	 * The task will be queued and executed by an available worker thread.
	 * Tasks are executed in the order they are submitted (FIFO).
	 * 
	 * @tparam F Callable type (lambda, function pointer, functor)
	 * @param task The task to execute. Must be callable with signature void()
	 * 
	 * @note If shutdown has been called, this function logs a warning and returns without queueing
	 * @note Thread-safe: Can be called from multiple threads concurrently
	 * @note The task is moved (not copied) into the queue
	 * 
	 * Example:
	 * @code
	 * pool.submit([]{ ShowInfo("Hello from worker\n"); });
	 * 
	 * // With capture
	 * int value = 42;
	 * pool.submit([value]{ ShowInfo("Value: %d\n", value); });
	 * @endcode
	 */
	template<typename F>
	void submit(F&& task) {
		if (shutdown_.load(std::memory_order_acquire)) {
			ShowWarning("ThreadPool: Cannot submit task after shutdown\n");
			return;
		}
		tasks_.push(std::forward<F>(task));
	}
	
	/**
	 * @brief Gracefully shutdown the thread pool
	 * 
	 * This function:
	 * 1. Stops accepting new tasks
	 * 2. Allows all pending tasks to complete
	 * 3. Waits for all worker threads to finish
	 * 
	 * This function blocks until all workers have stopped.
	 * It's safe to call multiple times (subsequent calls are no-ops).
	 * 
	 * @note Thread-safe: Can be called from any thread
	 * @note Blocking: This function may take time if many tasks are pending
	 */
	void shutdown();
	
	/**
	 * @brief Immediately shutdown the thread pool
	 * 
	 * This function:
	 * 1. Stops accepting new tasks
	 * 2. Signals workers to stop after completing their current task
	 * 3. Waits for all worker threads to finish
	 * 
	 * Pending tasks that haven't started will NOT be executed.
	 * 
	 * @note Thread-safe: Can be called from any thread
	 * @note Blocking: This function waits for currently executing tasks to finish
	 */
	void shutdown_now();
	
	/**
	 * @brief Get the number of worker threads in the pool
	 * 
	 * @return Number of worker threads
	 * 
	 * @note This value is fixed at construction and never changes
	 */
	size_t num_threads() const;
	
	/**
	 * @brief Get the number of tasks waiting to be executed
	 * 
	 * @return Number of tasks in the queue waiting for a worker
	 * 
	 * @note The returned value may be stale immediately after the call
	 * @note Thread-safe: Can be called from any thread
	 */
	size_t pending_tasks() const;
	
	/**
	 * @brief Get the number of workers currently executing tasks
	 * 
	 * @return Number of worker threads actively executing a task
	 * 
	 * @note The returned value may be stale immediately after the call
	 * @note Thread-safe: Can be called from any thread
	 */
	size_t active_workers() const;
	
	/**
	 * @brief Check if the pool has been shutdown
	 * 
	 * @return true if shutdown() or shutdown_now() has been called
	 * 
	 * @note Thread-safe: Can be called from any thread
	 */
	bool is_shutdown() const;
	
private:
	/**
	 * @brief Main worker thread loop
	 * 
	 * Each worker thread runs this function. It continuously:
	 * 1. Waits for a task from the queue
	 * 2. Executes the task (with exception handling)
	 * 3. Repeats until shutdown is signaled
	 */
	void worker_thread();
	
	std::vector<std::thread> workers_;           ///< Worker threads
	ThreadSafeQueue<Task> tasks_;                ///< Queue of pending tasks
	std::atomic<size_t> active_workers_;         ///< Count of workers currently executing tasks
	std::atomic<bool> shutdown_;                 ///< Flag indicating graceful shutdown
	std::atomic<bool> shutdown_now_;             ///< Flag indicating immediate shutdown
	
	// Disable copy and assignment
	ThreadPool(const ThreadPool&) = delete;
	ThreadPool& operator=(const ThreadPool&) = delete;
};

#endif /* THREADING_HPP */
