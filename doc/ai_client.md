# AI Client Integration Guide

## Overview

The AI Client provides gRPC-based integration between rAthena game server and the AI Sidecar service, enabling AI-powered features such as:

- **Dynamic NPC Dialogue**: NPCs can respond intelligently to player messages using LLM
- **Decision Making**: NPCs make context-aware decisions based on game state
- **Quest Generation**: Procedurally generated quests tailored to player level and location
- **And more**: 25+ AI agent capabilities via gRPC

## Architecture

```
┌─────────────────────┐         gRPC          ┌──────────────────────┐
│   rAthena Server    │◄──────────────────────►│  AI Sidecar Server   │
│                     │    (port 50051)        │                      │
│  ┌───────────────┐  │                        │  ┌────────────────┐  │
│  │  Map Server   │  │                        │  │  AI Agents     │  │
│  │               │  │                        │  │                │  │
│  │  ┌─────────┐  │  │                        │  │  - Dialogue    │  │
│  │  │AIClient │◄─┼──┼────────────────────────┼──┤  - Quest Gen   │  │
│  │  └─────────┘  │  │                        │  │  - Decision    │  │
│  │               │  │                        │  │  - Economy     │  │
│  │  NPC System   │  │                        │  │  - Memory      │  │
│  │  Script Cmds  │  │                        │  └────────────────┘  │
│  └───────────────┘  │                        │                      │
└─────────────────────┘                        └──────────────────────┘
```

## Configuration

### 1. Enable AI Client

Edit `conf/battle/ai_client.conf`:

```conf
// Enable AI Client integration
enable_ai_client: 1

// AI Sidecar endpoint
ai_server_endpoint: localhost:50051

// Server ID (get from AI Sidecar admin)
ai_server_id: your-server-id-here
```

### 2. Key Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `enable_ai_client` | 1 | Enable/disable AI integration |
| `ai_server_endpoint` | localhost:50051 | gRPC endpoint of AI Sidecar |
| `ai_server_id` | rathena-server-1 | Unique server identifier |
| `ai_connection_timeout` | 5000 | Connection timeout (ms) |
| `ai_rpc_timeout` | 30000 | RPC timeout (ms) |
| `ai_use_async` | 1 | Use async mode (non-blocking) |
| `ai_fallback_enabled` | 1 | Fallback to legacy NPCs on failure |
| `ai_debug_logging` | 0 | Enable verbose debug logs |

See `conf/battle/ai_client.conf` for all options.

## API Reference

### C++ API

```cpp
#include "ai_client/ai_client.hpp"

// Get singleton instance
AIClient& client = AIClient::getInstance();

// Connect to AI Sidecar
bool success = client.connect("localhost:50051", "my_server_id");

// Get AI-generated dialogue
std::string response = client.getDialogue(npc_id, player_id, "Hello!");

// Get NPC decision
std::vector<std::string> actions = {"attack", "defend", "flee"};
std::string decision = client.getDecision(npc_id, "enemy_nearby", actions);

// Generate quest
Quest quest = client.generateQuest(player_id, player_level, "prontera");

// Async dialogue (non-blocking)
client.getDialogueAsync(npc_id, player_id, "Hi!", [](const std::string& resp) {
    ShowInfo("Got response: %s\n", resp.c_str());
});

// Check connection
if (client.isConnected()) {
    // Connected
}

// Get statistics
uint64 total, failed;
double avg_latency;
client.getStats(total, failed, avg_latency);

// Disconnect
client.disconnect();
```

### Script Commands

#### ai_dialogue

Generate AI dialogue for an NPC.

```c
// Syntax: ai_dialogue(<npc_id>, <player_id>, <message>)
// Returns: string (AI-generated response)

.@npc_id = getnpcid(0);
.@player_id = getcharid(3);
.@response$ = ai_dialogue(.@npc_id, .@player_id, "Tell me about Prontera");

mes .@response$;
```

#### ai_decision

Get AI decision for an NPC.

```c
// Syntax: ai_decision(<npc_id>, <situation>, <actions_array>)
// Returns: string (chosen action)

.@npc_id = getnpcid(0);
setarray .@actions$[0], "greet", "ignore", "warn";
.@decision$ = ai_decision(.@npc_id, "stranger_approaches", .@actions$);

if (.@decision$ == "greet") {
    mes "Hello, traveler!";
} else if (.@decision$ == "warn") {
    mes "State your business!";
}
```

#### ai_quest

Generate a dynamic quest.

```c
// Syntax: ai_quest(<player_id>, <player_level>, <location>)
// Returns: quest_id (0 on failure)

.@player_id = getcharid(3);
.@level = BaseLevel;
.@quest_id = ai_quest(.@player_id, .@level, "prt_fild08");

if (.@quest_id > 0) {
    mes "I have a special task for you!";
    // Quest has been added to player
} else {
    mes "No quests available right now.";
}
```

## NPC Integration Examples

### Basic AI Dialogue NPC

```c
prontera,150,150,4	script	AI Guide	4_M_SAGE_C,{
	mes "[AI Guide]";
	mes "Hello! I'm an AI-powered NPC.";
	mes "What would you like to know?";
	next;
	
	input .@message$;
	
	if (.@message$ == "") {
		mes "[AI Guide]";
		mes "You didn't say anything...";
		close;
	}
	
	// Get AI response
	.@npc_id = getnpcid(0);
	.@player_id = getcharid(3);
	.@response$ = ai_dialogue(.@npc_id, .@player_id, .@message$);
	
	mes "[AI Guide]";
	mes .@response$;
	close;
}
```

### AI Quest Generator NPC

```c
prontera,160,180,4	script	Quest Master	4_M_KHMAN,{
	mes "[Quest Master]";
	mes "I can generate quests tailored to your level!";
	next;
	
	menu "Generate Quest", L_Generate, "Cancel", L_Cancel;
	
L_Generate:
	.@player_id = getcharid(3);
	.@level = BaseLevel;
	.@map$ = strcharinfo(3);  // Current map
	
	.@quest_id = ai_quest(.@player_id, .@level, .@map$);
	
	if (.@quest_id > 0) {
		mes "[Quest Master]";
		mes "I've prepared a special quest for you!";
		mes "Check your quest log for details.";
	} else {
		mes "[Quest Master]";
		mes "Sorry, I couldn't generate a quest right now.";
		mes "Please try again later.";
	}
	close;
	
L_Cancel:
	close;
}
```

### AI Decision-Making NPC

```c
prontera,170,170,4	script	Guard	4_M_JOB_KNIGHT1,{
	// NPC reacts based on player's reputation/karma
	.@npc_id = getnpcid(0);
	.@karma = getd("Karma_" + getcharid(0));  // Assume karma system exists
	
	// Define possible actions
	setarray .@actions$[0], "friendly_greeting", "neutral_greeting", 
	                         "suspicious_question", "hostile_warning";
	
	// Get situation description
	if (.@karma > 50) {
		.@situation$ = "trusted_citizen_approaches";
	} else if (.@karma < -50) {
		.@situation$ = "known_troublemaker_approaches";
	} else {
		.@situation$ = "unknown_person_approaches";
	}
	
	// Get AI decision
	.@action$ = ai_decision(.@npc_id, .@situation$, .@actions$);
	
	mes "[Guard]";
	switch (.@action$) {
		case "friendly_greeting":
			mes "Welcome back, friend!";
			break;
		case "neutral_greeting":
			mes "Halt. State your business.";
			break;
		case "suspicious_question":
			mes "I'm watching you...";
			break;
		case "hostile_warning":
			mes "You're not welcome here!";
			break;
		default:
			mes "...";
	}
	close;
}
```

## Building from Source

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt-get install libgrpc++-dev libprotobuf-dev protobuf-compiler-grpc

# Fedora/RHEL
sudo dnf install grpc-devel protobuf-devel grpc-plugins

# Arch Linux
sudo pacman -S grpc protobuf
```

### Compile

```bash
cd rathena
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_AI_CLIENT=ON
make -j$(nproc)
```

To disable AI Client:

```bash
cmake .. -DBUILD_AI_CLIENT=OFF
```

### Generate Proto Files

If you need to regenerate the gRPC code:

```bash
cd rathena/src/ai_client
./generate_proto.sh
```

## Initialization

The AI Client is automatically initialized when map-server starts (if enabled in config).

Manual initialization (in custom code):

```cpp
#include "ai_client/ai_client.hpp"

void init_my_ai_features() {
    AIClient& client = AIClient::getInstance();
    
    if (battle_config.enable_ai_client) {
        bool success = client.connect(
            battle_config.ai_server_endpoint,
            battle_config.ai_server_id
        );
        
        if (!success && !battle_config.ai_fallback_enabled) {
            ShowError("AI Client connection failed!\n");
        }
    }
}
```

## Troubleshooting

### Connection Issues

**Problem**: `AI Client connection failed`

**Solutions**:
1. Check AI Sidecar is running: `curl http://localhost:50051`
2. Verify endpoint in `conf/battle/ai_client.conf`
3. Check firewall: `sudo ufw allow 50051/tcp`
4. Check server_id is correct

### Build Errors

**Problem**: `gRPC not found`

**Solution**: Install gRPC development packages:

```bash
# Ubuntu/Debian
sudo apt-get install libgrpc++-dev protobuf-compiler-grpc

# From source
git clone --recurse-submodules -b v1.58.0 https://github.com/grpc/grpc
cd grpc
mkdir -p cmake/build
cd cmake/build
cmake -DgRPC_INSTALL=ON -DgRPC_BUILD_TESTS=OFF ../..
make -j$(nproc)
sudo make install
```

**Problem**: `protoc: command not found`

**Solution**: Install Protocol Buffers compiler:

```bash
sudo apt-get install protobuf-compiler
```

### Performance Issues

**Problem**: High latency / slow responses

**Solutions**:
1. Enable async mode: `ai_use_async: 1`
2. Increase thread pool size (conf/battle/threading.conf)
3. Enable caching:
   - `ai_dialogue_cache_timeout: 300`
   - `ai_quest_cache_timeout: 600`
4. Check AI Sidecar performance
5. Use rate limiting to prevent overload:
   - `ai_rate_limit_rps: 100`

### Debugging

Enable debug logging:

```conf
// In conf/battle/ai_client.conf
ai_debug_logging: 1
ai_enable_stats: 1
ai_stats_report_interval: 60
```

Check logs for detailed information:

```bash
tail -f log/map-server.log | grep "AI"
```

## Statistics & Monitoring

The AI Client tracks performance metrics:

```cpp
AIClient& client = AIClient::getInstance();
uint64 total, failed;
double avg_latency;
client.getStats(total, failed, avg_latency);

ShowInfo("AI Stats: %llu total, %llu failed, %.2f ms avg\n",
         total, failed, avg_latency);
```

Statistics are automatically logged every `ai_stats_report_interval` seconds.

## Advanced Topics

### Custom AI Agents

To add support for new AI agents:

1. Update proto file: `src/ai_client/protos/ai_service.proto`
2. Regenerate code: `./generate_proto.sh`
3. Add methods to `AIClient` class
4. Create script commands if needed

### Async Operations

For non-blocking AI calls:

```cpp
client.getDialogueAsync(npc_id, player_id, message, 
    [](const std::string& response) {
        // This callback runs when AI responds
        // Handle response here
        ShowInfo("AI Response: %s\n", response.c_str());
    }
);

// Main thread continues immediately
```

### Thread Pool Integration

AI Client uses the threading system from Phase 3-4:

```conf
// In conf/battle/threading.conf
enable_threading: 1
cpu_worker_threads: 4

// In conf/battle/ai_client.conf
ai_use_async: 1
```

## Security Considerations

**Production Deployment:**

1. **Use TLS**: Update `ai_client.cpp` to use SSL credentials
2. **Authentication**: Implement API key validation
3. **Rate Limiting**: Enable to prevent abuse
4. **Firewall**: Restrict AI Sidecar access
5. **Network**: Use VPN or private network for AI traffic

**Example TLS Configuration** (ai_client.cpp):

```cpp
// Replace InsecureChannelCredentials with:
auto ssl_opts = grpc::SslCredentialsOptions();
ssl_opts.pem_root_certs = read_file("ca.pem");
ssl_opts.pem_cert_chain = read_file("client.pem");
ssl_opts.pem_private_key = read_file("client.key");
auto creds = grpc::SslCredentials(ssl_opts);
channel_ = grpc::CreateChannel(endpoint, creds);
```

## Performance Best Practices

1. **Enable Async Mode**: Prevents blocking main thread
2. **Use Caching**: Reduce redundant AI calls
3. **Rate Limiting**: Prevent overload
4. **Thread Pool**: Size appropriately for load
5. **Timeouts**: Set reasonable RPC timeouts
6. **Fallback**: Enable legacy NPC fallback
7. **Monitoring**: Track stats and latency

## Support & Resources

- **Documentation**: `/doc/ai_client.md` (this file)
- **Configuration**: `conf/battle/ai_client.conf`
- **Proto Definition**: `src/ai_client/protos/ai_service.proto`
- **Example Scripts**: See NPC Integration Examples above
- **rAthena Forums**: https://rathena.org/board/
- **GitHub Issues**: Report bugs and request features

## Version History

- **Phase 9**: Initial gRPC client implementation
- **Integration**: Thread pool async support
- **Features**: Dialogue, Decision, Quest generation

## License

Copyright (c) rAthena Dev Teams - Licensed under GNU GPL
For more information, see LICENCE in the main folder
