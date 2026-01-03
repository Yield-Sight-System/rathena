# AI Client - gRPC Integration Module

## Overview

This module provides gRPC client functionality for connecting rAthena game server to the AI Sidecar service. It enables AI-powered NPC dialogue, quest generation, decision making, and other advanced features.

## Quick Start

### 1. Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get install libgrpc++-dev libprotobuf-dev protobuf-compiler-grpc
```

**Fedora/RHEL:**
```bash
sudo dnf install grpc-devel protobuf-devel grpc-plugins
```

### 2. Generate Proto Code

```bash
cd rathena/src/ai_client
./generate_proto.sh
```

This will generate C++ code in the `generated/` directory from `protos/ai_service.proto`.

### 3. Build

```bash
cd rathena
mkdir build && cd build
cmake .. -DBUILD_AI_CLIENT=ON
make -j$(nproc)
```

### 4. Configure

Edit `conf/battle/ai_client.conf`:

```conf
enable_ai_client: 1
ai_server_endpoint: localhost:50051
ai_server_id: your-server-id
```

### 5. Test

```bash
./test_ai_client localhost:50051 test_server
```

## Module Structure

```
ai_client/
├── README.md              # This file
├── CMakeLists.txt         # Build configuration
├── generate_proto.sh      # Proto code generator script
├── ai_client.hpp          # AI Client header
├── ai_client.cpp          # AI Client implementation
├── test_client.cpp        # Test program
├── protos/
│   └── ai_service.proto   # gRPC service definition
└── generated/             # Auto-generated files (create by running generate_proto.sh)
    ├── ai_service.pb.h
    ├── ai_service.pb.cc
    ├── ai_service.grpc.pb.h
    └── ai_service.grpc.pb.cc
```

## Usage

### C++ API

```cpp
#include "ai_client/ai_client.hpp"

// Get singleton instance
AIClient& client = AIClient::getInstance();

// Connect to AI Sidecar
client.connect("localhost:50051", "my_server");

// Get dialogue
std::string response = client.getDialogue(npc_id, player_id, "Hello!");

// Disconnect
client.disconnect();
```

### Script Commands

```c
// In NPC script
.@response$ = ai_dialogue(getnpcid(0), getcharid(3), "Hello!");
mes .@response$;

// Generate quest
.@quest_id = ai_quest(getcharid(3), BaseLevel, "prontera");
```

## Features

- **Dialogue**: AI-powered NPC conversations
- **Decisions**: Context-aware NPC decision making
- **Quest Generation**: Dynamic, procedural quests
- **Async Support**: Non-blocking operations with thread pool
- **Statistics**: Performance tracking and monitoring
- **Fallback**: Graceful degradation to legacy NPCs
- **Configurable**: Extensive configuration options

## Documentation

See [`/doc/ai_client.md`](../../doc/ai_client.md) for complete documentation, including:
- Full configuration reference
- API documentation
- NPC integration examples
- Troubleshooting guide
- Performance tuning

## Dependencies

- **gRPC** >= 1.50.0 (C++ implementation)
- **Protocol Buffers** >= 3.20.0
- **C++17** compatible compiler
- **CMake** >= 3.13

## Configuration

Key settings in `conf/battle/ai_client.conf`:

| Setting | Default | Description |
|---------|---------|-------------|
| `enable_ai_client` | 1 | Enable AI integration |
| `ai_server_endpoint` | localhost:50051 | gRPC endpoint |
| `ai_server_id` | rathena-server-1 | Server identifier |
| `ai_use_async` | 1 | Use async mode |
| `ai_fallback_enabled` | 1 | Fallback to legacy NPCs |

## Testing

Run the test client to verify connection:

```bash
./test_ai_client [endpoint] [server_id]
```

Example output:
```
╔═══════════════════════════════════════════════════╗
║       rAthena AI Client Test Program             ║
║       Phase 9: gRPC Integration Test             ║
╚═══════════════════════════════════════════════════╝

[✓] Successfully connected to AI Sidecar
[✓] Dialogue RPC successful
[✓] Decision RPC successful
[✓] Quest Generation RPC successful
[✓] All critical tests passed!
```

## Troubleshooting

**Build Error: gRPC not found**
```bash
# Install gRPC development packages
sudo apt-get install libgrpc++-dev protobuf-compiler-grpc
```

**Runtime Error: Connection refused**
- Ensure AI Sidecar server is running
- Check endpoint in configuration
- Verify firewall allows port 50051

**Empty responses**
- Check AI Sidecar logs for errors
- Verify server_id is registered
- Enable debug logging: `ai_debug_logging: 1`

## Integration Points

This module integrates with:

- **Map Server**: Linked as dependency in `src/map/CMakeLists.txt`
- **Threading**: Uses Phase 3-4 thread pool for async operations
- **Configuration**: Battle config system (`conf/battle/`)
- **Logging**: rAthena ShowMsg system

## Phase Information

- **Phase**: 9 - rAthena C++ gRPC Client Integration
- **Prerequisites**: Phase 8 (AI Sidecar Server), Phase 3-4 (Threading)
- **Next Phase**: 10 - End-to-End Testing

## License

Copyright (c) rAthena Dev Teams - Licensed under GNU GPL
For more information, see LICENCE in the main folder

## Support

- **Documentation**: `/doc/ai_client.md`
- **rAthena Forums**: https://rathena.org/board/
- **Issues**: Report via GitHub

## Version History

- **v1.0.0** (Phase 9): Initial gRPC client implementation
  - Dialogue, Decision, Quest generation RPCs
  - Async support with thread pool
  - Configuration system
  - Test client
