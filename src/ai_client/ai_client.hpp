// Copyright (c) rAthena Dev Teams - Licensed under GNU GPL
// For more information, see LICENCE in the main folder

#ifndef AI_CLIENT_HPP
#define AI_CLIENT_HPP

#include <atomic>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "../common/cbasetypes.hpp"

// Forward declarations for gRPC types (avoid including heavy headers)
namespace grpc {
	class Channel;
	class ClientContext;
	class Status;
}

namespace rathena {
namespace ai {
	class AIWorldService;
	class DialogueRequest;
	class DialogueResponse;
	class DecisionRequest;
	class DecisionResponse;
	class QuestRequest;
	class QuestResponse;
}
}

/**
 * @brief Quest structure returned from AI
 */
struct Quest {
	int64 quest_id;
	std::string quest_type;
	std::string difficulty;
	std::string title;
	std::string description;
	int32 time_limit_minutes;
	
	Quest() : quest_id(0), time_limit_minutes(0) {}
};

/**
 * @brief AI Client for communicating with AI Sidecar server via gRPC
 * 
 * This class provides a singleton interface to the AI World Service running
 * on the sidecar server. It handles NPC dialogue, decision making, quest
 * generation, and other AI-powered features.
 * 
 * Thread-safe: All public methods can be called from multiple threads
 * concurrently. The class uses internal locking to ensure thread safety.
 * 
 * Example usage:
 * @code
 * AIClient& client = AIClient::getInstance();
 * if (client.connect("localhost:50051", "my_server_id")) {
 *     std::string response = client.getDialogue(npc_id, player_id, "Hello!");
 *     // Use response...
 *     client.disconnect();
 * }
 * @endcode
 * 
 * @note This class is designed to integrate with rathena's existing threading
 * infrastructure from Phase 3-4 for async operations.
 */
class AIClient {
public:
	/**
	 * @brief Get the singleton instance of AIClient
	 * 
	 * @return Reference to the singleton AIClient instance
	 * @note Thread-safe: Can be called from multiple threads
	 */
	static AIClient& getInstance();
	
	/**
	 * @brief Initialize connection to AI Sidecar server
	 * 
	 * Establishes a gRPC channel to the specified endpoint. The connection
	 * is persistent and reused for all RPC calls.
	 * 
	 * @param endpoint Server endpoint in format "host:port" (e.g., "localhost:50051")
	 * @param server_id Unique identifier for this rathena server instance
	 * @return true if connection was successful, false otherwise
	 * 
	 * @note This function is idempotent - calling it multiple times is safe
	 * @note Thread-safe: Can be called from any thread
	 */
	bool connect(const std::string& endpoint, const std::string& server_id);
	
	/**
	 * @brief Disconnect from AI Sidecar server
	 * 
	 * Closes the gRPC channel and releases resources. After calling this,
	 * connect() must be called again before using any RPC methods.
	 * 
	 * @note Thread-safe: Can be called from any thread
	 * @note This function is idempotent - calling it multiple times is safe
	 */
	void disconnect();
	
	/**
	 * @brief Check if client is connected to AI Sidecar
	 * 
	 * @return true if connected, false otherwise
	 * @note Thread-safe: Can be called from any thread
	 */
	bool isConnected() const;
	
	/**
	 * @brief Get AI-generated dialogue for an NPC
	 * 
	 * Sends a dialogue request to the AI service and returns the NPC's response.
	 * This is a synchronous call that blocks until the response is received.
	 * 
	 * @param npc_id Unique ID of the NPC
	 * @param player_id Unique ID of the player character
	 * @param message Player's message to the NPC
	 * @return AI-generated dialogue response, or empty string on error
	 * 
	 * @note If not connected, logs a warning and returns empty string
	 * @note Thread-safe: Can be called from multiple threads
	 * @note Blocking call - may take time depending on AI processing
	 */
	std::string getDialogue(int npc_id, int player_id, const char* message);
	
	/**
	 * @brief Get AI decision for an NPC given a situation
	 * 
	 * Asks the AI to choose an action for an NPC based on the current situation
	 * and available actions. Uses utility-based decision making.
	 * 
	 * @param npc_id Unique ID of the NPC
	 * @param situation Description of the current situation
	 * @param actions Vector of available actions the NPC can take
	 * @return Chosen action as a string, or empty string on error
	 * 
	 * @note If not connected, logs a warning and returns empty string
	 * @note Thread-safe: Can be called from multiple threads
	 * @note Blocking call - may take time depending on AI processing
	 */
	std::string getDecision(int npc_id, const char* situation, 
	                        const std::vector<std::string>& actions);
	
	/**
	 * @brief Generate a dynamic quest for a player
	 * 
	 * Requests the AI to create a quest appropriate for the player's level
	 * and current location. The quest is procedurally generated and unique.
	 * 
	 * @param player_id Unique ID of the player
	 * @param player_level Current level of the player
	 * @param location Map/location identifier
	 * @return Quest structure with quest details, or empty quest on error
	 * 
	 * @note If not connected, logs a warning and returns empty quest
	 * @note Thread-safe: Can be called from multiple threads
	 * @note Blocking call - may take time depending on AI processing
	 */
	Quest generateQuest(int player_id, int player_level, const char* location);
	
	/**
	 * @brief Get dialogue asynchronously (non-blocking)
	 * 
	 * Submits a dialogue request to the thread pool and calls the callback
	 * when the response is ready. This allows the main thread to continue
	 * processing while waiting for AI response.
	 * 
	 * @param npc_id Unique ID of the NPC
	 * @param player_id Unique ID of the player
	 * @param message Player's message to the NPC
	 * @param callback Function to call when response is ready
	 * 
	 * @note If threading is disabled, falls back to synchronous call
	 * @note The callback may be called from a worker thread
	 * @note Thread-safe: Can be called from multiple threads
	 */
	void getDialogueAsync(int npc_id, int player_id, const char* message,
	                      std::function<void(const std::string&)> callback);
	
	/**
	 * @brief Get the server ID this client is registered with
	 * 
	 * @return Server ID string
	 * @note Thread-safe: Can be called from any thread
	 */
	const std::string& getServerId() const { return server_id_; }
	
	/**
	 * @brief Get statistics about AI client usage
	 * 
	 * @param[out] total_requests Total number of RPC requests made
	 * @param[out] failed_requests Number of failed RPC requests
	 * @param[out] avg_latency_ms Average RPC latency in milliseconds
	 * 
	 * @note Thread-safe: Can be called from any thread
	 */
	void getStats(uint64& total_requests, uint64& failed_requests, 
	              double& avg_latency_ms) const;

private:
	/**
	 * @brief Private constructor (singleton pattern)
	 */
	AIClient();
	
	/**
	 * @brief Destructor - ensures proper cleanup
	 */
	~AIClient();
	
	// Disable copy and assignment
	AIClient(const AIClient&) = delete;
	AIClient& operator=(const AIClient&) = delete;
	
	/**
	 * @brief Update statistics after an RPC call
	 * 
	 * @param success Whether the call succeeded
	 * @param latency_ms Latency of the call in milliseconds
	 */
	void updateStats(bool success, double latency_ms);
	
	// gRPC connection
	std::shared_ptr<grpc::Channel> channel_;
	std::unique_ptr<rathena::ai::AIWorldService::Stub> stub_;
	
	// Connection state
	std::string server_id_;
	std::atomic<bool> connected_;
	
	// Thread safety
	mutable std::mutex mutex_;
	
	// Statistics (atomic for lock-free reads)
	std::atomic<uint64> total_requests_;
	std::atomic<uint64> failed_requests_;
	std::atomic<double> total_latency_ms_;
};

#endif /* AI_CLIENT_HPP */
