# Documentation Index

This directory contains all documentation for rAthena with multi-threading and AI integration.

## Organizational Structure

```
doc/
├── README.md                          # Master documentation index
├── DOCUMENTATION_INDEX.md             # This file
├── PROJECT_SUMMARY.md                 # Complete project overview
├── BUILD_RESULTS.md                   # Build and test results
│
├── ai-sidecar/                        # AI Sidecar documentation
│   └── API_REFERENCE.md              # Complete API reference (4000+ lines)
│
├── deployment/                        # Deployment guides
│   ├── DEPLOYMENT_GUIDE.md           # Production deployment
│   ├── QUICK_START.md                # 5-minute quick start
│   └── CLOUDFLARE_TUNNEL.md          # Tunnel configuration
│
├── integration/                       # Integration documentation
│   ├── INTEGRATION_COMPLETE.md       # Integration status
│   ├── COMPLIANCE_REPORT.md          # Feature compliance
│   ├── VALIDATION_REPORT.md          # Validation results
│   └── COMPLIANCE_STATUS.md          # Compliance tracking
│
└── [existing files]                   # Original rathena docs
    ├── ai_client.md                   # C++ client library
    ├── threading.md                   # Multi-threading guide
    ├── MULTITHREADING_SUMMARY.md      # Performance results
    ├── MULTITHREADING_DEPLOYMENT.md   # Multi-threading deployment
    ├── db_async_examples.md           # Async database
    ├── achievements.md                # Achievement system
    ├── effect_list.md                 # Visual effects
    ├── packet_struct_notation.md      # Network packets
    └── map_server_generator.md        # Map generation
```

## Production Environment

- **AI Sidecar**: https://rathena.cakobox.com
- **API Documentation**: https://rathena.cakobox.com/docs
- **Health Endpoint**: https://rathena.cakobox.com/health

## Quick Access

- **Get Started**: [deployment/QUICK_START.md](deployment/QUICK_START.md)
- **API Reference**: [ai-sidecar/API_REFERENCE.md](ai-sidecar/API_REFERENCE.md)
- **Deploy to Production**: [deployment/DEPLOYMENT_GUIDE.md](deployment/DEPLOYMENT_GUIDE.md)
- **Integration Status**: [integration/INTEGRATION_COMPLETE.md](integration/INTEGRATION_COMPLETE.md)

## Documentation Categories

### AI Sidecar (New Feature)

Complete AI integration for dynamic NPCs, quests, and world events:

- **[API Reference](ai-sidecar/API_REFERENCE.md)** - Full REST & gRPC API documentation with examples
- **[C++ Client](ai_client.md)** - Integration guide for map-server
- **[Integration Status](integration/INTEGRATION_COMPLETE.md)** - 100% feature completion report
- **[Compliance](integration/COMPLIANCE_REPORT.md)** - Alignment with concept2.md requirements

### Deployment & Operations

Production-ready deployment guides:

- **[Deployment Guide](deployment/DEPLOYMENT_GUIDE.md)** - Complete production setup (3500+ lines)
- **[Quick Start](deployment/QUICK_START.md)** - Get running in 5 minutes
- **[Cloudflare Tunnel](deployment/CLOUDFLARE_TUNNEL.md)** - Public HTTPS access setup
- **[Test Script](../tools/test_tunnel.sh)** - Connectivity verification

### Multi-Threading (Core Enhancement)

Performance optimization through parallel processing:

- **[Threading Guide](threading.md)** - Implementation details
- **[Performance Summary](MULTITHREADING_SUMMARY.md)** - Benchmark results (2.5-4× improvement)
- **[Deployment Guide](MULTITHREADING_DEPLOYMENT.md)** - Production rollout procedures
- **[Async Database](db_async_examples.md)** - Non-blocking database operations

### Project Documentation

High-level overviews and results:

- **[Project Summary](PROJECT_SUMMARY.md)** - Complete feature list and architecture
- **[Build Results](BUILD_RESULTS.md)** - Compilation and testing outcomes

### Original rAthena Documentation

Core server documentation:

- **[Achievements](achievements.md)** - Achievement system configuration
- **[Effect List](effect_list.md)** - Visual effect IDs and usage
- **[Packet Structure](packet_struct_notation.md)** - Network protocol documentation
- **[Map Server Generator](map_server_generator.md)** - Map generation utilities

## External References

### Workspace Root
- `concept.md` - Original project concept
- `concept2.md` - Detailed specification (reference document)
- `secret.txt` - Credentials (not for repository)

### Planning Directory
- `plans/rathena-ai-sidecar-proposal.md` - Initial AI sidecar proposal
- `plans/rathena-ai-sidecar-system-architecture.md` - System architecture design
- `plans/rathena-multithreading-architecture-design.md` - Threading architecture

## Documentation Standards

### URL References
All documentation uses production URLs:
- **Base URL**: https://rathena.cakobox.com
- **Health Check**: https://rathena.cakobox.com/health
- **API Docs**: https://rathena.cakobox.com/docs

### Link Format
Internal links use relative paths from their location:
```markdown
[Document Title](relative/path/to/file.md)
```

### Organization Principles
1. **Topical Separation**: Related docs grouped in subdirectories
2. **Clear Naming**: Descriptive, consistent file names
3. **Cross-References**: Extensive internal linking
4. **Production URLs**: All examples use live production endpoints

## Getting Help

### Documentation Issues
- Check [README.md](README.md) for overview
- Review specific category documentation
- Verify links using `../tools/verify_links.sh` (if created)

### System Support
- **AI Sidecar Issues**: Check [API Reference](ai-sidecar/API_REFERENCE.md)
- **Deployment Problems**: See [Deployment Guide](deployment/DEPLOYMENT_GUIDE.md)
- **Performance Questions**: Review [Performance Summary](MULTITHREADING_SUMMARY.md)
- **Integration Help**: Consult [Integration Complete](integration/INTEGRATION_COMPLETE.md)

---

**Last Updated**: January 2026  
**Documentation Version**: 1.0  
**Status**: Production Ready
