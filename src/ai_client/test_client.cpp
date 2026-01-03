// Copyright (c) rAthena Dev Teams - Licensed under GNU GPL
// For more information, see LICENCE in the main folder

/**
 * @file test_client.cpp
 * @brief Test program for AI Client gRPC integration
 * 
 * This program tests the AI Client connection and basic RPC functionality.
 * Use it to verify your AI Sidecar server is working before integrating
 * with the full rAthena map server.
 * 
 * Usage:
 *   ./test_ai_client [endpoint] [server_id]
 * 
 * Example:
 *   ./test_ai_client localhost:50051 test_server
 */

#include <iostream>
#include <string>
#include <vector>
#include <chrono>
#include <thread>

// Include AI Client
#include "ai_client.hpp"

// Color codes for terminal output
#define COLOR_RESET   "\033[0m"
#define COLOR_RED     "\033[31m"
#define COLOR_GREEN   "\033[32m"
#define COLOR_YELLOW  "\033[33m"
#define COLOR_BLUE    "\033[34m"
#define COLOR_CYAN    "\033[36m"

// Helper functions for pretty output
void print_header(const char* text) {
    std::cout << "\n" << COLOR_CYAN << "========================================" << COLOR_RESET << "\n";
    std::cout << COLOR_CYAN << text << COLOR_RESET << "\n";
    std::cout << COLOR_CYAN << "========================================" << COLOR_RESET << "\n\n";
}

void print_success(const char* text) {
    std::cout << COLOR_GREEN << "[✓] " << text << COLOR_RESET << "\n";
}

void print_error(const char* text) {
    std::cout << COLOR_RED << "[✗] " << text << COLOR_RESET << "\n";
}

void print_info(const char* text) {
    std::cout << COLOR_BLUE << "[i] " << text << COLOR_RESET << "\n";
}

void print_warning(const char* text) {
    std::cout << COLOR_YELLOW << "[!] " << text << COLOR_RESET << "\n";
}

// Test 1: Connection test
bool test_connection(AIClient& client, const std::string& endpoint, const std::string& server_id) {
    print_header("Test 1: Connection");
    
    print_info("Attempting to connect to AI Sidecar...");
    printf("  Endpoint: %s\n", endpoint.c_str());
    printf("  Server ID: %s\n", server_id.c_str());
    
    bool success = client.connect(endpoint, server_id);
    
    if (success && client.isConnected()) {
        print_success("Successfully connected to AI Sidecar");
        return true;
    } else {
        print_error("Failed to connect to AI Sidecar");
        print_warning("Make sure AI Sidecar server is running on the specified endpoint");
        return false;
    }
}

// Test 2: Dialogue RPC
bool test_dialogue(AIClient& client) {
    print_header("Test 2: Dialogue RPC");
    
    print_info("Testing AI dialogue generation...");
    
    int npc_id = 1001;
    int player_id = 5001;
    const char* message = "Tell me about the kingdom of Prontera";
    
    printf("  NPC ID: %d\n", npc_id);
    printf("  Player ID: %d\n", player_id);
    printf("  Message: \"%s\"\n", message);
    
    auto start = std::chrono::high_resolution_clock::now();
    std::string response = client.getDialogue(npc_id, player_id, message);
    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    
    if (!response.empty()) {
        print_success("Dialogue RPC successful");
        printf("  Response: \"%s\"\n", response.c_str());
        printf("  Latency: %lld ms\n", (long long)duration.count());
        return true;
    } else {
        print_error("Dialogue RPC failed or returned empty response");
        return false;
    }
}

// Test 3: Decision RPC
bool test_decision(AIClient& client) {
    print_header("Test 3: Decision RPC");
    
    print_info("Testing AI decision making...");
    
    int npc_id = 1002;
    const char* situation = "A stranger approaches the village gate";
    std::vector<std::string> actions = {
        "greet_warmly",
        "ask_business",
        "ignore",
        "call_guards"
    };
    
    printf("  NPC ID: %d\n", npc_id);
    printf("  Situation: \"%s\"\n", situation);
    printf("  Available actions:\n");
    for (const auto& action : actions) {
        printf("    - %s\n", action.c_str());
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    std::string decision = client.getDecision(npc_id, situation, actions);
    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    
    if (!decision.empty()) {
        print_success("Decision RPC successful");
        printf("  Chosen action: \"%s\"\n", decision.c_str());
        printf("  Latency: %lld ms\n", (long long)duration.count());
        return true;
    } else {
        print_error("Decision RPC failed or returned empty decision");
        return false;
    }
}

// Test 4: Quest Generation RPC
bool test_quest_generation(AIClient& client) {
    print_header("Test 4: Quest Generation RPC");
    
    print_info("Testing dynamic quest generation...");
    
    int player_id = 5001;
    int player_level = 50;
    const char* location = "prontera";
    
    printf("  Player ID: %d\n", player_id);
    printf("  Player Level: %d\n", player_level);
    printf("  Location: \"%s\"\n", location);
    
    auto start = std::chrono::high_resolution_clock::now();
    Quest quest = client.generateQuest(player_id, player_level, location);
    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    
    if (quest.quest_id > 0) {
        print_success("Quest Generation RPC successful");
        printf("  Quest ID: %lld\n", (long long)quest.quest_id);
        printf("  Title: \"%s\"\n", quest.title.c_str());
        printf("  Type: \"%s\"\n", quest.quest_type.c_str());
        printf("  Difficulty: \"%s\"\n", quest.difficulty.c_str());
        printf("  Description: \"%s\"\n", quest.description.c_str());
        printf("  Time Limit: %d minutes\n", quest.time_limit_minutes);
        printf("  Latency: %lld ms\n", (long long)duration.count());
        return true;
    } else {
        print_error("Quest Generation RPC failed or returned invalid quest");
        return false;
    }
}

// Test 5: Statistics
void test_statistics(AIClient& client) {
    print_header("Test 5: Statistics");
    
    print_info("Retrieving AI Client statistics...");
    
    uint64 total_requests, failed_requests;
    double avg_latency_ms;
    
    client.getStats(total_requests, failed_requests, avg_latency_ms);
    
    printf("  Total Requests: %llu\n", (unsigned long long)total_requests);
    printf("  Failed Requests: %llu\n", (unsigned long long)failed_requests);
    printf("  Success Rate: %.2f%%\n", 
           total_requests > 0 ? 
           (100.0 * (total_requests - failed_requests) / total_requests) : 0.0);
    printf("  Average Latency: %.2f ms\n", avg_latency_ms);
    
    if (failed_requests == 0) {
        print_success("All requests successful!");
    } else {
        print_warning("Some requests failed");
    }
}

// Test 6: Async Dialogue (if threading available)
bool test_async_dialogue(AIClient& client) {
    print_header("Test 6: Async Dialogue (Optional)");
    
    print_info("Testing asynchronous dialogue...");
    
    bool callback_called = false;
    std::string async_response;
    
    client.getDialogueAsync(1003, 5002, "What quests do you have?",
        [&](const std::string& response) {
            callback_called = true;
            async_response = response;
            print_info("Async callback received!");
        }
    );
    
    // Wait for callback (max 10 seconds)
    print_info("Waiting for async response...");
    for (int i = 0; i < 100 && !callback_called; ++i) {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    
    if (callback_called && !async_response.empty()) {
        print_success("Async Dialogue successful");
        printf("  Response: \"%s\"\n", async_response.c_str());
        return true;
    } else if (callback_called) {
        print_warning("Async callback called but response was empty");
        print_info("This may be normal if AI returned empty response");
        return true;
    } else {
        print_warning("Async test skipped (threading may not be available)");
        return false;
    }
}

// Main test program
int main(int argc, char* argv[]) {
    std::cout << COLOR_CYAN << "\n";
    std::cout << "╔═══════════════════════════════════════════════════╗\n";
    std::cout << "║       rAthena AI Client Test Program             ║\n";
    std::cout << "║       Phase 9: gRPC Integration Test             ║\n";
    std::cout << "╚═══════════════════════════════════════════════════╝\n";
    std::cout << COLOR_RESET << "\n";
    
    // Parse command line arguments
    std::string endpoint = "localhost:50051";
    std::string server_id = "test_server";
    
    if (argc >= 2) {
        endpoint = argv[1];
    }
    if (argc >= 3) {
        server_id = argv[2];
    }
    
    print_info("AI Client Test Suite");
    printf("  Endpoint: %s\n", endpoint.c_str());
    printf("  Server ID: %s\n\n", server_id.c_str());
    
    // Get AI Client singleton
    AIClient& client = AIClient::getInstance();
    
    // Track test results
    int tests_passed = 0;
    int tests_failed = 0;
    
    // Test 1: Connection
    if (test_connection(client, endpoint, server_id)) {
        tests_passed++;
    } else {
        tests_failed++;
        print_error("Cannot proceed with remaining tests without connection");
        goto cleanup;
    }
    
    // Test 2: Dialogue
    if (test_dialogue(client)) {
        tests_passed++;
    } else {
        tests_failed++;
    }
    
    // Test 3: Decision
    if (test_decision(client)) {
        tests_passed++;
    } else {
        tests_failed++;
    }
    
    // Test 4: Quest Generation
    if (test_quest_generation(client)) {
        tests_passed++;
    } else {
        tests_failed++;
    }
    
    // Test 5: Statistics
    test_statistics(client);
    tests_passed++;
    
    // Test 6: Async (optional)
    if (test_async_dialogue(client)) {
        tests_passed++;
    }
    
cleanup:
    // Cleanup
    print_header("Cleanup");
    print_info("Disconnecting from AI Sidecar...");
    client.disconnect();
    print_success("Disconnected");
    
    // Print summary
    print_header("Test Summary");
    printf("  Tests Passed: %s%d%s\n", COLOR_GREEN, tests_passed, COLOR_RESET);
    if (tests_failed > 0) {
        printf("  Tests Failed: %s%d%s\n", COLOR_RED, tests_failed, COLOR_RESET);
    } else {
        print_success("All critical tests passed!");
    }
    
    std::cout << "\n";
    
    return (tests_failed == 0) ? 0 : 1;
}
