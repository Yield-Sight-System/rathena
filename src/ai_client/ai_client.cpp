// Copyright (c) rAthena Dev Teams - Licensed under GNU GPL
// For more information, see LICENCE in the main folder

#include "ai_client.hpp"

#include <chrono>
#include <exception>

#include <grpcpp/grpcpp.h>
#include "generated/ai_service.grpc.pb.h"

#include "../common/showmsg.hpp"
#include "../common/timer.hpp"

// For async operations - we'll reference the global thread pool if available
// This will be properly linked when integrated with map server
extern "C" {
	// Forward declarations for threading functions (from Phase 3)
	// These will be properly defined when linked with map-server
	bool is_threading_enabled();
	void* get_cpu_worker_pool();
	void thread_pool_submit(void* pool, void (*func)(void*), void* arg);
}

// Singleton instance
AIClient& AIClient::getInstance() {
	static AIClient instance;
	return instance;
}

// Constructor
AIClient::AIClient() 
	: connected_(false)
	, total_requests_(0)
	, failed_requests_(0)
	, total_latency_ms_(0.0)
{
	ShowInfo("AI Client initialized\n");
}

// Destructor
AIClient::~AIClient() {
	disconnect();
	ShowInfo("AI Client destroyed\n");
}

// Connect to AI Sidecar server
bool AIClient::connect(const std::string& endpoint, const std::string& server_id) {
	std::lock_guard<std::mutex> lock(mutex_);
	
	if (connected_) {
		ShowWarning("AI Client already connected to %s\n", endpoint.c_str());
		return true;
	}
	
	if (endpoint.empty()) {
		ShowError("AI Client: Cannot connect to empty endpoint\n");
		return false;
	}
	
	if (server_id.empty()) {
		ShowError("AI Client: Cannot connect without server_id\n");
		return false;
	}
	
	try {
		ShowInfo("AI Client: Connecting to %s with server_id '%s'...\n", 
		         endpoint.c_str(), server_id.c_str());
		
		// Create gRPC channel with insecure credentials
		// TODO: In production, use TLS credentials for security
		grpc::ChannelArguments args;
		args.SetInt(GRPC_ARG_KEEPALIVE_TIME_MS, 60000);  // 60 seconds
		args.SetInt(GRPC_ARG_KEEPALIVE_TIMEOUT_MS, 20000);  // 20 seconds
		args.SetInt(GRPC_ARG_KEEPALIVE_PERMIT_WITHOUT_CALLS, 1);
		args.SetInt(GRPC_ARG_HTTP2_MAX_PINGS_WITHOUT_DATA, 0);
		
		channel_ = grpc::CreateCustomChannel(
			endpoint,
			grpc::InsecureChannelCredentials(),
			args
		);
		
		if (!channel_) {
			ShowError("AI Client: Failed to create gRPC channel\n");
			return false;
		}
		
		// Create stub for making RPC calls
		stub_ = rathena::ai::AIWorldService::NewStub(channel_);
		
		if (!stub_) {
			ShowError("AI Client: Failed to create service stub\n");
			channel_.reset();
			return false;
		}
		
		// Try to verify connection with a health check (with timeout)
		grpc::ClientContext context;
		auto deadline = std::chrono::system_clock::now() + std::chrono::seconds(5);
		context.set_deadline(deadline);
		
		rathena::ai::HealthRequest health_req;
		health_req.set_detailed(false);
		rathena::ai::HealthResponse health_resp;
		
		grpc::Status status = stub_->HealthCheck(&context, health_req, &health_resp);
		
		if (!status.ok()) {
			ShowWarning("AI Client: Health check failed (%s), but continuing anyway\n",
			            status.error_message().c_str());
			ShowWarning("AI Client: Server may not be ready yet\n");
		} else {
			ShowInfo("AI Client: Health check OK - Server status: %s\n", 
			         health_resp.status().c_str());
		}
		
		server_id_ = server_id;
		connected_ = true;
		
		ShowInfo("AI Client: Successfully connected to %s\n", endpoint.c_str());
		return true;
		
	} catch (const std::exception& e) {
		ShowError("AI Client: Connection failed with exception: %s\n", e.what());
		channel_.reset();
		stub_.reset();
		return false;
	}
}

// Disconnect from AI Sidecar server
void AIClient::disconnect() {
	std::lock_guard<std::mutex> lock(mutex_);
	
	if (!connected_) {
		return;
	}
	
	ShowInfo("AI Client: Disconnecting from server...\n");
	
	try {
		// Clean up resources
		stub_.reset();
		channel_.reset();
		server_id_.clear();
		connected_ = false;
		
		ShowInfo("AI Client: Disconnected successfully\n");
		ShowInfo("AI Client Stats - Total: %llu, Failed: %llu, Avg Latency: %.2f ms\n",
		         (unsigned long long)total_requests_.load(),
		         (unsigned long long)failed_requests_.load(),
		         total_requests_.load() > 0 ? 
		             (total_latency_ms_.load() / total_requests_.load()) : 0.0);
		
	} catch (const std::exception& e) {
		ShowError("AI Client: Error during disconnection: %s\n", e.what());
	}
}

// Check connection status
bool AIClient::isConnected() const {
	return connected_.load();
}

// Update statistics
void AIClient::updateStats(bool success, double latency_ms) {
	total_requests_++;
	if (!success) {
		failed_requests_++;
	}
	
	// Atomic addition for average latency tracking
	double current_total = total_latency_ms_.load();
	while (!total_latency_ms_.compare_exchange_weak(current_total, 
	                                                 current_total + latency_ms)) {
		// Retry if another thread modified the value
	}
}

// Get AI-generated dialogue
std::string AIClient::getDialogue(int npc_id, int player_id, const char* message) {
	if (!connected_) {
		ShowWarning("AI Client: Not connected, cannot get dialogue\n");
		return "";
	}
	
	if (!message) {
		ShowWarning("AI Client: Null message provided\n");
		return "";
	}
	
	try {
		auto start_time = std::chrono::high_resolution_clock::now();
		
		// Create context with timeout
		grpc::ClientContext context;
		auto deadline = std::chrono::system_clock::now() + std::chrono::seconds(30);
		context.set_deadline(deadline);
		
		// Build request
		rathena::ai::DialogueRequest request;
		request.set_server_id(server_id_);
		request.set_npc_id(npc_id);
		request.set_player_id(player_id);
		request.set_message(message);
		
		// Make RPC call
		rathena::ai::DialogueResponse response;
		grpc::Status status;
		
		{
			// Don't hold the main mutex during the RPC call
			std::lock_guard<std::mutex> lock(mutex_);
			if (!stub_) {
				ShowError("AI Client: Stub not initialized\n");
				return "";
			}
			status = stub_->Dialogue(&context, request, &response);
		}
		
		// Calculate latency
		auto end_time = std::chrono::high_resolution_clock::now();
		auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
			end_time - start_time);
		double latency_ms = duration.count();
		
		if (status.ok()) {
			updateStats(true, latency_ms);
			ShowDebug("AI Dialogue: NPC %d replied to player %d (%.2f ms, %d tokens)\n",
			          npc_id, player_id, latency_ms, response.tokens_used());
			return response.response();
		} else {
			updateStats(false, latency_ms);
			ShowError("AI Dialogue RPC failed: [%d] %s\n",
			          status.error_code(), status.error_message().c_str());
			return "";
		}
		
	} catch (const std::exception& e) {
		updateStats(false, 0.0);
		ShowError("AI Dialogue exception: %s\n", e.what());
		return "";
	}
}

// Get AI decision
std::string AIClient::getDecision(int npc_id, const char* situation,
                                   const std::vector<std::string>& actions) {
	if (!connected_) {
		ShowWarning("AI Client: Not connected, cannot get decision\n");
		return "";
	}
	
	if (!situation) {
		ShowWarning("AI Client: Null situation provided\n");
		return "";
	}
	
	if (actions.empty()) {
		ShowWarning("AI Client: No actions provided for decision\n");
		return "";
	}
	
	try {
		auto start_time = std::chrono::high_resolution_clock::now();
		
		// Create context with timeout
		grpc::ClientContext context;
		auto deadline = std::chrono::system_clock::now() + std::chrono::seconds(30);
		context.set_deadline(deadline);
		
		// Build request
		rathena::ai::DecisionRequest request;
		request.set_server_id(server_id_);
		request.set_npc_id(npc_id);
		request.set_situation(situation);
		for (const auto& action : actions) {
			request.add_available_actions(action);
		}
		
		// Make RPC call
		rathena::ai::DecisionResponse response;
		grpc::Status status;
		
		{
			std::lock_guard<std::mutex> lock(mutex_);
			if (!stub_) {
				ShowError("AI Client: Stub not initialized\n");
				return "";
			}
			status = stub_->Decision(&context, request, &response);
		}
		
		// Calculate latency
		auto end_time = std::chrono::high_resolution_clock::now();
		auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
			end_time - start_time);
		double latency_ms = duration.count();
		
		if (status.ok()) {
			updateStats(true, latency_ms);
			ShowDebug("AI Decision: NPC %d chose '%s' (%.2f ms, confidence: %d)\n",
			          npc_id, response.chosen_action().c_str(), latency_ms,
			          response.confidence_score());
			return response.chosen_action();
		} else {
			updateStats(false, latency_ms);
			ShowError("AI Decision RPC failed: [%d] %s\n",
			          status.error_code(), status.error_message().c_str());
			return "";
		}
		
	} catch (const std::exception& e) {
		updateStats(false, 0.0);
		ShowError("AI Decision exception: %s\n", e.what());
		return "";
	}
}

// Generate quest
Quest AIClient::generateQuest(int player_id, int player_level, const char* location) {
	Quest quest;  // Empty quest on failure
	
	if (!connected_) {
		ShowWarning("AI Client: Not connected, cannot generate quest\n");
		return quest;
	}
	
	if (!location) {
		ShowWarning("AI Client: Null location provided\n");
		return quest;
	}
	
	try {
		auto start_time = std::chrono::high_resolution_clock::now();
		
		// Create context with longer timeout for quest generation
		grpc::ClientContext context;
		auto deadline = std::chrono::system_clock::now() + std::chrono::seconds(45);
		context.set_deadline(deadline);
		
		// Build request
		rathena::ai::QuestRequest request;
		request.set_server_id(server_id_);
		request.set_player_id(player_id);
		request.set_player_level(player_level);
		request.set_location(location);
		request.set_quest_type("dynamic");  // Let AI choose appropriate type
		
		// Make RPC call
		rathena::ai::QuestResponse response;
		grpc::Status status;
		
		{
			std::lock_guard<std::mutex> lock(mutex_);
			if (!stub_) {
				ShowError("AI Client: Stub not initialized\n");
				return quest;
			}
			status = stub_->GenerateQuest(&context, request, &response);
		}
		
		// Calculate latency
		auto end_time = std::chrono::high_resolution_clock::now();
		auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
			end_time - start_time);
		double latency_ms = duration.count();
		
		if (status.ok()) {
			updateStats(true, latency_ms);
			
			// Convert response to Quest structure
			quest.quest_id = response.quest_id();
			quest.quest_type = response.quest_type();
			quest.difficulty = response.difficulty();
			quest.title = response.title();
			quest.description = response.description();
			quest.time_limit_minutes = response.time_limit_minutes();
			
			ShowInfo("AI Quest: Generated '%s' for player %d (level %d) in %s (%.2f ms)\n",
			         quest.title.c_str(), player_id, player_level, location, latency_ms);
			ShowInfo("  Type: %s, Difficulty: %s, Time Limit: %d min\n",
			         quest.quest_type.c_str(), quest.difficulty.c_str(),
			         quest.time_limit_minutes);
			
			return quest;
		} else {
			updateStats(false, latency_ms);
			ShowError("AI Quest RPC failed: [%d] %s\n",
			          status.error_code(), status.error_message().c_str());
			return quest;
		}
		
	} catch (const std::exception& e) {
		updateStats(false, 0.0);
		ShowError("AI Quest exception: %s\n", e.what());
		return quest;
	}
}

// Store memory
bool AIClient::storeMemory(int npc_id, int player_id, const char* content, float importance) {
	if (!connected_) {
		ShowWarning("AI Client: Not connected, cannot store memory\n");
		return false;
	}
	
	if (!content) {
		ShowWarning("AI Client: Null content provided for memory\n");
		return false;
	}
	
	// Clamp importance to valid range
	if (importance < 0.0f) importance = 0.0f;
	if (importance > 1.0f) importance = 1.0f;
	
	try {
		auto start_time = std::chrono::high_resolution_clock::now();
		
		// Create context with timeout
		grpc::ClientContext context;
		auto deadline = std::chrono::system_clock::now() + std::chrono::seconds(30);
		context.set_deadline(deadline);
		
		// Build request
		rathena::ai::MemoryRequest request;
		request.set_server_id(server_id_);
		request.set_entity_id(npc_id);
		request.set_entity_type("npc");
		request.set_content(content);
		request.set_importance(importance);
		
		// Add player_id to metadata for association
		(*request.mutable_metadata())["player_id"] = std::to_string(player_id);
		(*request.mutable_metadata())["memory_type"] = "npc_player_interaction";
		
		// Make RPC call
		rathena::ai::MemoryResponse response;
		grpc::Status status;
		
		{
			std::lock_guard<std::mutex> lock(mutex_);
			if (!stub_) {
				ShowError("AI Client: Stub not initialized\n");
				return false;
			}
			status = stub_->StoreMemory(&context, request, &response);
		}
		
		// Calculate latency
		auto end_time = std::chrono::high_resolution_clock::now();
		auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
			end_time - start_time);
		double latency_ms = duration.count();
		
		if (status.ok() && response.success()) {
			updateStats(true, latency_ms);
			ShowInfo("AI Memory: Stored memory for NPC %d (player %d, importance %.2f) - ID: %lld (%.2f ms)\n",
			         npc_id, player_id, importance, (long long)response.memory_id(), latency_ms);
			return true;
		} else {
			updateStats(false, latency_ms);
			if (!response.success()) {
				ShowError("AI Memory failed: %s\n", response.error_message().c_str());
			} else {
				ShowError("AI Memory RPC failed: [%d] %s\n",
				          status.error_code(), status.error_message().c_str());
			}
			return false;
		}
		
	} catch (const std::exception& e) {
		updateStats(false, 0.0);
		ShowError("AI Memory exception: %s\n", e.what());
		return false;
	}
}

// Async dialogue - callback wrapper structure
struct AsyncDialogueData {
	AIClient* client;
	int npc_id;
	int player_id;
	std::string message;
	std::function<void(const std::string&)> callback;
};

// C-style callback for thread pool
static void async_dialogue_worker(void* data) {
	AsyncDialogueData* async_data = static_cast<AsyncDialogueData*>(data);
	
	if (async_data) {
		std::string result = async_data->client->getDialogue(
			async_data->npc_id,
			async_data->player_id,
			async_data->message.c_str()
		);
		
		// Call the user's callback
		if (async_data->callback) {
			async_data->callback(result);
		}
		
		delete async_data;
	}
}

// Get dialogue asynchronously
void AIClient::getDialogueAsync(int npc_id, int player_id, const char* message,
                                 std::function<void(const std::string&)> callback) {
	if (!message) {
		ShowWarning("AI Client: Null message provided for async dialogue\n");
		if (callback) {
			callback("");
		}
		return;
	}
	
	// Check if threading is available
	// If not, fall back to synchronous call
	bool threading_available = false;
	void* pool = nullptr;
	
	try {
		threading_available = is_threading_enabled();
		if (threading_available) {
			pool = get_cpu_worker_pool();
		}
	} catch (...) {
		// Threading functions not available, fall back to sync
		threading_available = false;
	}
	
	if (!threading_available || !pool) {
		ShowDebug("AI Client: Threading not available, using synchronous call\n");
		std::string result = getDialogue(npc_id, player_id, message);
		if (callback) {
			callback(result);
		}
		return;
	}
	
	// Create async data structure
	AsyncDialogueData* async_data = new AsyncDialogueData();
	async_data->client = this;
	async_data->npc_id = npc_id;
	async_data->player_id = player_id;
	async_data->message = message;
	async_data->callback = callback;
	
	// Submit to thread pool
	try {
		thread_pool_submit(pool, async_dialogue_worker, async_data);
		ShowDebug("AI Client: Dialogue request submitted to thread pool\n");
	} catch (const std::exception& e) {
		ShowError("AI Client: Failed to submit async task: %s\n", e.what());
		delete async_data;
		// Fall back to synchronous
		std::string result = getDialogue(npc_id, player_id, message);
		if (callback) {
			callback(result);
		}
	}
}

// Get statistics
void AIClient::getStats(uint64& total_requests, uint64& failed_requests,
                        double& avg_latency_ms) const {
	total_requests = total_requests_.load();
	failed_requests = failed_requests_.load();
	
	if (total_requests > 0) {
		avg_latency_ms = total_latency_ms_.load() / total_requests;
	} else {
		avg_latency_ms = 0.0;
	}
}
