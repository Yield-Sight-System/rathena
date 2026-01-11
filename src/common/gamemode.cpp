// Copyright (c) rAthena Dev Teams - Licensed under GNU GPL
// For more information, see LICENCE in the main folder

#include "gamemode.hpp"

#include <chrono>

#ifdef HAVE_AI_CLIENT
#include <grpcpp/grpcpp.h>

using grpc::Channel;
using grpc::ClientContext;
using grpc::Status;
#endif

#include "showmsg.hpp"

// Singleton instance
GameModeClient* GameModeClient::instance_ = nullptr;
std::mutex GameModeClient::instance_mutex_;

/**
 * @brief Get singleton instance (thread-safe lazy initialization)
 */
GameModeClient& GameModeClient::getInstance() {
	// Double-checked locking pattern for thread-safe singleton
	if (instance_ == nullptr) {
		std::lock_guard<std::mutex> lock(instance_mutex_);
		if (instance_ == nullptr) {
			instance_ = new GameModeClient();
		}
	}
	return *instance_;
}

/**
 * @brief Private constructor
 */
GameModeClient::GameModeClient() 
	: current_mode_(GAME_MODE_BASIC),
	  running_(false) {
	ShowInfo("GameModeClient: Constructor called\n");
}

/**
 * @brief Destructor
 */
GameModeClient::~GameModeClient() {
	shutdown();
	ShowInfo("GameModeClient: Destructor called\n");
}

/**
 * @brief Initialize client and start listener thread
 */
bool GameModeClient::initialize(const std::string& server_id) {
	std::lock_guard<std::mutex> lock(mutex_);
	
	// Already initialized
	if (running_.load(std::memory_order_acquire)) {
		ShowWarning("GameModeClient: Already initialized\n");
		return true;
	}
	
	server_id_ = server_id;
	
#ifdef HAVE_AI_CLIENT
	// Create gRPC channel (localhost:50051 is default gRPC port)
	const char* grpc_endpoint = "localhost:50051";
	
	ShowStatus("GameModeClient: Connecting to AI Sidecar at %s...\n", grpc_endpoint);
	
	channel_ = grpc::CreateChannel(
		grpc_endpoint,
		grpc::InsecureChannelCredentials()
	);
	
	if (!channel_) {
		ShowError("GameModeClient: Failed to create gRPC channel\n");
		return false;
	}
	
	// Create stub
	stub_ = rathena::ai::AIWorldService::NewStub(channel_);
	
	if (!stub_) {
		ShowError("GameModeClient: Failed to create gRPC stub\n");
		return false;
	}
	
	// Try to get initial mode
	try {
		rathena::ai::ServerModeRequest request;
		request.set_server_id(server_id_);
		
		rathena::ai::ServerModeResponse response;
		ClientContext context;
		
		// Set deadline (5 second timeout)
		auto deadline = std::chrono::system_clock::now() + std::chrono::seconds(5);
		context.set_deadline(deadline);
		
		Status status = stub_->GetServerMode(&context, request, &response);
		
		if (status.ok() && response.success()) {
			// Parse initial mode
			std::string mode_str = response.current_mode();
			if (mode_str == "HORMONE") {
				current_config_.mode = GAME_MODE_HORMONE;
				current_mode_.store(GAME_MODE_HORMONE, std::memory_order_release);
			} else {
				current_config_.mode = GAME_MODE_BASIC;
				current_mode_.store(GAME_MODE_BASIC, std::memory_order_release);
			}
			
			// Parse configuration
			if (response.has_config()) {
				const auto& config = response.config();
				current_config_.exp_rate = config.exp_rate();
				current_config_.drop_rate = config.drop_rate();
				current_config_.quest_difficulty = config.quest_difficulty();
				current_config_.ai_features_enabled = config.ai_features_enabled();
				current_config_.death_penalty = config.death_penalty();
				current_config_.social_features = config.social_features();
				current_config_.achievement_system = config.achievement_system();
				current_config_.bot_farming = config.bot_farming();
			}
			
			ShowStatus("GameModeClient: Initial mode: %s (EXP: %.2fx, Drop: %.2fx)\n",
				mode_str.c_str(), current_config_.exp_rate, current_config_.drop_rate);
		} else {
			ShowWarning("GameModeClient: Failed to get initial mode: %s\n",
				status.error_message().c_str());
			// Continue with defaults
		}
	} catch (const std::exception& e) {
		ShowWarning("GameModeClient: Exception getting initial mode: %s\n", e.what());
		// Continue with defaults
	}
	
	// Start listener thread
	running_.store(true, std::memory_order_release);
	listener_thread_ = std::thread(&GameModeClient::listener_thread_func, this);
	
	ShowStatus("GameModeClient: Initialized successfully for server '%s'\n", server_id_.c_str());
#else
	// Without AI Client, always use BASIC mode
	current_config_.mode = GAME_MODE_BASIC;
	current_mode_.store(GAME_MODE_BASIC, std::memory_order_release);
	running_.store(true, std::memory_order_release);
	ShowStatus("GameModeClient: Initialized in BASIC mode (AI Client disabled)\n");
#endif
	return true;
}

/**
	* @brief Shutdown client
	*/
void GameModeClient::shutdown() {
	ShowInfo("GameModeClient: Shutting down...\n");
	
	// Signal thread to stop
	running_.store(false, std::memory_order_release);
	
	// Wait for thread to finish
	if (listener_thread_.joinable()) {
		listener_thread_.join();
	}
	
	// Reset state
	{
		std::lock_guard<std::mutex> lock(mutex_);
#ifdef HAVE_AI_CLIENT
		channel_.reset();
		stub_.reset();
#endif
		server_id_.clear();
		current_mode_.store(GAME_MODE_BASIC, std::memory_order_release);
	}
	
	ShowStatus("GameModeClient: Shutdown complete\n");
}

/**
 * @brief Background thread for streaming mode changes
 */
void GameModeClient::listener_thread_func() {
#ifdef HAVE_AI_CLIENT
	ShowInfo("GameModeClient: Listener thread started\n");
	
	while (running_.load(std::memory_order_acquire)) {
		try {
			rathena::ai::ServerModeRequest request;
			request.set_server_id(server_id_);
			
			ClientContext context;
			
			// Subscribe to mode changes (server streaming RPC)
			auto reader = stub_->SubscribeToModeChanges(&context, request);
			
			rathena::ai::ModeChangeEvent event;
			
			// Read stream
			while (running_.load(std::memory_order_acquire) && reader->Read(&event)) {
				// Parse new mode
				GameModeConfig new_config;
				
				std::string new_mode_str = event.new_mode();
				if (new_mode_str == "HORMONE") {
					new_config.mode = GAME_MODE_HORMONE;
				} else {
					new_config.mode = GAME_MODE_BASIC;
				}
				
				// Parse configuration
				if (event.has_config()) {
					const auto& config = event.config();
					new_config.exp_rate = config.exp_rate();
					new_config.drop_rate = config.drop_rate();
					new_config.quest_difficulty = config.quest_difficulty();
					new_config.ai_features_enabled = config.ai_features_enabled();
					new_config.death_penalty = config.death_penalty();
					new_config.social_features = config.social_features();
					new_config.achievement_system = config.achievement_system();
					new_config.bot_farming = config.bot_farming();
				}
				
				// Apply the change
				apply_mode_change(new_config);
				
				ShowStatus("GameModeClient: Mode changed to %s (by: %s)\n",
					new_mode_str.c_str(), event.switched_by().c_str());
				ShowStatus("  → EXP Rate: %.2fx\n", new_config.exp_rate);
				ShowStatus("  → Drop Rate: %.2fx\n", new_config.drop_rate);
				ShowStatus("  → AI Features: %s\n", new_config.ai_features_enabled ? "enabled" : "disabled");
				ShowStatus("  → Achievement System: %s\n", new_config.achievement_system ? "enabled" : "disabled");
			}
			
			// Stream ended, check status
			Status status = reader->Finish();
			
			if (!status.ok()) {
				ShowWarning("GameModeClient: Stream ended with error: %s\n",
					status.error_message().c_str());
			}
			
		} catch (const std::exception& e) {
			ShowError("GameModeClient: Exception in listener thread: %s\n", e.what());
		}
		
		// Reconnection backoff (5 seconds)
		if (running_.load(std::memory_order_acquire)) {
			ShowInfo("GameModeClient: Reconnecting in 5 seconds...\n");
			std::this_thread::sleep_for(std::chrono::seconds(5));
		}
	}
	
	ShowInfo("GameModeClient: Listener thread stopped\n");
#endif
}

/**
 * @brief Apply mode change atomically
 */
void GameModeClient::apply_mode_change(const GameModeConfig& new_config) {
	std::lock_guard<std::mutex> lock(mutex_);
	
	GameMode old_mode = current_mode_.load(std::memory_order_acquire);
	
	// Update configuration
	current_config_ = new_config;
	
	// Update atomic mode (for lock-free reads)
	current_mode_.store(new_config.mode, std::memory_order_release);
	
	// Log change if mode actually switched
	if (old_mode != new_config.mode) {
		const char* old_mode_str = (old_mode == GAME_MODE_HORMONE) ? "HORMONE" : "BASIC";
		const char* new_mode_str = (new_config.mode == GAME_MODE_HORMONE) ? "HORMONE" : "BASIC";
		ShowInfo("GameModeClient: Mode switch: %s → %s\n", old_mode_str, new_mode_str);
	}
}

/**
 * @brief Get current configuration (thread-safe copy)
 */
GameModeConfig GameModeClient::getCurrentConfig() const {
	std::lock_guard<std::mutex> lock(mutex_);
	return current_config_;
}

/**
 * @brief Get current EXP rate
 */
float GameModeClient::getExpRate() const {
	std::lock_guard<std::mutex> lock(mutex_);
	return current_config_.exp_rate;
}

/**
 * @brief Get current drop rate
 */
float GameModeClient::getDropRate() const {
	std::lock_guard<std::mutex> lock(mutex_);
	return current_config_.drop_rate;
}

/**
 * @brief Check if AI features enabled
 */
bool GameModeClient::isAIEnabled() const {
	std::lock_guard<std::mutex> lock(mutex_);
	return current_config_.ai_features_enabled;
}

/**
 * @brief Check if achievement system enabled
 */
bool GameModeClient::isAchievementSystemEnabled() const {
	std::lock_guard<std::mutex> lock(mutex_);
	return current_config_.achievement_system;
}

/**
 * @brief Get death penalty multiplier
 */
float GameModeClient::getDeathPenaltyMultiplier() const {
	std::lock_guard<std::mutex> lock(mutex_);
	
	// Parse death penalty string to multiplier
	if (current_config_.death_penalty == "none") {
		return 0.0f;
	} else if (current_config_.death_penalty == "reduced") {
		return 0.5f;
	} else {
		return 1.0f; // "full" or default
	}
}
