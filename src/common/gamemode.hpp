// Copyright (c) rAthena Dev Teams - Licensed under GNU GPL
// For more information, see LICENCE in the main folder

#ifndef _GAMEMODE_HPP_
#define _GAMEMODE_HPP_

#include <atomic>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

#include "cbasetypes.hpp"

#ifdef HAVE_AI_CLIENT
// Forward declarations for gRPC types
namespace grpc {
	class Channel;
	class ClientContext;
	class Status;
}

// Include generated protobuf/gRPC headers
#include "../ai_client/generated/ai_service.grpc.pb.h"
#endif

/**
 * @brief Game mode enumeration
 */
enum GameMode {
	GAME_MODE_BASIC = 0,
	GAME_MODE_HORMONE = 1
};

/**
 * @brief Game mode configuration structure
 */
struct GameModeConfig {
	GameMode mode;
	float exp_rate;
	float drop_rate;
	std::string quest_difficulty;
	bool ai_features_enabled;
	std::string death_penalty;
	std::string social_features;
	bool achievement_system;
	std::string bot_farming;
	
	GameModeConfig() : 
		mode(GAME_MODE_BASIC),
		exp_rate(1.0f),
		drop_rate(1.0f),
		quest_difficulty("standard"),
		ai_features_enabled(false),
		death_penalty("full"),
		social_features("standard"),
		achievement_system(false),
		bot_farming("prohibited") {}
};

/**
 * @brief Game Mode Client for managing dual-mode system
 * 
 * This singleton class maintains a persistent gRPC streaming connection
 * to the AI Sidecar server to receive real-time mode change notifications.
 * 
 * Thread-safe: All public methods can be called from multiple threads.
 * 
 * Example usage:
 * @code
 * if (GameModeClient::getInstance().initialize("server_001")) {
 *     float exp_multiplier = GameModeClient::getInstance().getExpRate();
 *     // Use multiplier...
 * }
 * @endcode
 */
class GameModeClient {
public:
	/**
	 * @brief Get the singleton instance
	 * 
	 * @return Reference to the singleton instance
	 * @note Thread-safe
	 */
	static GameModeClient& getInstance();
	
	/**
	 * @brief Initialize the game mode client
	 * 
	 * Establishes connection to AI Sidecar server and starts
	 * a background thread to listen for mode changes.
	 * 
	 * @param server_id Server identifier for this rAthena instance
	 * @return true if initialization successful, false otherwise
	 * @note This function is idempotent
	 * @note Thread-safe
	 */
	bool initialize(const std::string& server_id);
	
	/**
	 * @brief Shutdown the client and cleanup resources
	 * 
	 * Stops the listener thread and closes gRPC connection.
	 * 
	 * @note Thread-safe
	 */
	void shutdown();
	
	/**
	 * @brief Get the current game mode
	 * 
	 * @return Current GameMode (BASIC or HORMONE)
	 * @note Thread-safe, lock-free
	 */
	GameMode getCurrentMode() const { 
		return current_mode_.load(std::memory_order_acquire); 
	}
	
	/**
	 * @brief Get complete current mode configuration
	 * 
	 * @return GameModeConfig structure with all settings
	 * @note Thread-safe
	 */
	GameModeConfig getCurrentConfig() const;
	
	/**
	 * @brief Get current EXP rate multiplier
	 * 
	 * @return EXP rate (e.g., 2.5 for 250% EXP)
	 * @note Thread-safe, lock-free
	 */
	float getExpRate() const;
	
	/**
	 * @brief Get current drop rate multiplier
	 * 
	 * @return Drop rate (e.g., 2.0 for 200% drops)
	 * @note Thread-safe, lock-free
	 */
	float getDropRate() const;
	
	/**
	 * @brief Check if AI features are enabled
	 * 
	 * @return true if AI features enabled (HORMONE mode), false otherwise
	 * @note Thread-safe, lock-free
	 */
	bool isAIEnabled() const;
	
	/**
	 * @brief Check if achievement system is enabled
	 * 
	 * @return true if achievement system enabled, false otherwise
	 * @note Thread-safe, lock-free
	 */
	bool isAchievementSystemEnabled() const;
	
	/**
	 * @brief Get death penalty multiplier
	 * 
	 * @return Death penalty multiplier (0.0 = no penalty, 1.0 = full penalty)
	 * @note Thread-safe
	 */
	float getDeathPenaltyMultiplier() const;
	
	/**
	 * @brief Check if client is initialized
	 * 
	 * @return true if initialized and running
	 * @note Thread-safe, lock-free
	 */
	bool isInitialized() const {
		return running_.load(std::memory_order_acquire);
	}

private:
	/**
	 * @brief Private constructor (singleton pattern)
	 */
	GameModeClient();
	
	/**
	 * @brief Destructor
	 */
	~GameModeClient();
	
	// Disable copy and assignment
	GameModeClient(const GameModeClient&) = delete;
	GameModeClient& operator=(const GameModeClient&) = delete;
	
	/**
	 * @brief Background thread function for listening to mode changes
	 *
	 * Maintains a streaming RPC connection and updates configuration
	 * when mode changes are received.
	 */
	void listener_thread_func();
	
	/**
	 * @brief Apply a received mode change to current configuration
	 *
	 * @param new_config New configuration to apply
	 */
	void apply_mode_change(const GameModeConfig& new_config);
	
	// Static members for singleton
	static GameModeClient* instance_;
	static std::mutex instance_mutex_;
	
#ifdef HAVE_AI_CLIENT
	// gRPC connection
	std::shared_ptr<grpc::Channel> channel_;
	std::unique_ptr<rathena::ai::AIWorldService::Stub> stub_;
#endif
	
	// Server identification
	std::string server_id_;
	
	// Current configuration (protected by mutex_)
	GameModeConfig current_config_;
	
	// Current mode (atomic for lock-free reads)
	std::atomic<GameMode> current_mode_;
	
	// Background listener thread
	std::thread listener_thread_;
	std::atomic<bool> running_;
	
	// Thread safety
	mutable std::mutex mutex_;
};

// ============================================================================
// Global Helper Functions
// ============================================================================

/**
 * @brief Check if server is in HORMONE mode
 * 
 * Convenience function for quick mode checks.
 * 
 * @return true if HORMONE mode active, false if BASIC mode
 */
inline bool is_hormone_mode() {
	return GameModeClient::getInstance().getCurrentMode() == GAME_MODE_HORMONE;
}

/**
 * @brief Get current EXP rate multiplier
 * 
 * Convenience function for EXP calculations.
 * 
 * @return EXP rate multiplier
 */
inline float get_mode_exp_rate() {
	return GameModeClient::getInstance().getExpRate();
}

/**
 * @brief Get current drop rate multiplier
 * 
 * Convenience function for drop calculations.
 * 
 * @return Drop rate multiplier
 */
inline float get_mode_drop_rate() {
	return GameModeClient::getInstance().getDropRate();
}

#endif /* _GAMEMODE_HPP_ */
