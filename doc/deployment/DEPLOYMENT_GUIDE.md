# Production Deployment Guide - rAthena AI World System

**Version:** 1.0.0  
**Date:** 2026-01-03  
**Status:** Production Deployment Procedures  
**Architecture:** Two-Machine Deployment (rAthena + AI Sidecar)

---

## Table of Contents

1. [Hardware Requirements](#1-hardware-requirements)
2. [Architecture Overview](#2-architecture-overview)
3. [Pre-Deployment Planning](#3-pre-deployment-planning)
4. [Machine 2 Setup: AI Sidecar Server](#4-machine-2-setup-ai-sidecar-server)
5. [Machine 1 Setup: rAthena Game Server](#5-machine-1-setup-rathena-game-server)
6. [Configuration](#6-configuration)
7. [Security Hardening](#7-security-hardening)
8. [Monitoring & Maintenance](#8-monitoring--maintenance)
9. [Troubleshooting](#9-troubleshooting)
10. [Disaster Recovery](#10-disaster-recovery)

---

## 1. Hardware Requirements

### 1.1 Machine 1: rAthena Game Server

**Minimum Requirements:**

```yaml
CPU: 4 cores (8 threads)
RAM: 8GB DDR4
Storage: 50GB SSD
Network: 1 Gbps, <100ms latency to AI Sidecar
OS: Linux (Ubuntu 22.04 LTS recommended)
```

**Recommended Specifications:**

```yaml
CPU: 8 cores (16 threads)
  - Intel Core i7/i9 or AMD Ryzen 7/9
  - 3.0+ GHz base frequency
RAM: 16GB DDR4
Storage: 100GB NVMe SSD
  - OS: 20GB
  - rAthena: 30GB
  - Databases: 30GB
  - Logs/Backups: 20GB
Network: 1 Gbps Ethernet, <50ms latency to AI Sidecar
OS: Ubuntu 22.04 LTS (or 24.04 LTS)
Additional: Static IP or domain name
```

**Estimated Cost:**

- **Cloud VPS:** $20-50/month
  - Providers: DigitalOcean, Linode, Vultr, Hetzner
  - Example: Linode 8GB ($40/month)

- **Self-Hosted:** $300-600 one-time
  - Used server or desktop PC
  - Electricity: $10-20/month

### 1.2 Machine 2: AI Sidecar Server

**Minimum Requirements:**

```yaml
CPU: 16 cores (32 threads)
RAM: 64GB DDR4
GPU: NVIDIA RTX 3060 12GB (or equivalent)
Storage: 200GB NVMe SSD
Network: 1 Gbps Ethernet
OS: Ubuntu 22.04 LTS
```

**Recommended Specifications (Dell PowerEdge R730 Configuration):**

```yaml
CPU: Dual Intel Xeon E5-2698 v3
  - 32 cores total (16 cores per socket)
  - 64 threads with Hyper-Threading
  - 2.3 GHz base, 3.6 GHz turbo
  - 40MB L3 cache per socket

RAM: 192GB DDR4 ECC
  - 12× 16GB DIMMs
  - 2133 MHz speed
  - ECC protection for production reliability

GPU: NVIDIA RTX 3060 12GB
  - 3584 CUDA cores
  - 112 Tensor cores
  - 12GB GDDR6 VRAM
  - PCIe 4.0 x16 (compatible with PCIe 3.0)
  - 170W TDP

Storage: 1TB NVMe SSD
  - OS: 100GB
  - PostgreSQL: 500GB
  - ML Models: 50GB
  - Logs/Backups: 350GB
  - Sequential Read: 3,500 MB/s
  - Random IOPS: 600,000

Network: 10 Gbps Ethernet (optional but recommended)
  - Dual 1GbE ports (integrated)
  - Optional: Intel X520-DA2 10GbE card

OS: Ubuntu 22.04 LTS Server
  - Kernel: 6.2+ (for RTX 3060 support)
  - Minimal installation (no desktop environment)
```

**Estimated Cost:**

- **Cloud GPU Instance:** $200-400/month
  - Providers: Vast.ai, Lambda Labs, Paperspace
  - Example: Lambda Labs A6000 instance ($300/month)
  - Note: RTX 3060-specific instances rare, may need higher-tier GPU

- **Self-Hosted (Recommended):** $1,200-1,750 one-time + $50-80/month
  - Dell PowerEdge R730 (used): $800-1,200
  - NVIDIA RTX 3060 12GB: $300-400
  - NVMe SSD 1TB: $100-150
  - Electricity: ~420W × $0.15/kWh = $46/month
  - Internet/Colocation: $50-100/month (if co-located)
  - **Total first year:** ~$1,800-2,850
  - **Total subsequent years:** $600-1,200/year

### 1.3 Network Requirements

**Inter-Machine Network:**

```yaml
Latency: <100ms (optimal), <200ms (acceptable)
Bandwidth: 10 Mbps minimum, 100 Mbps recommended
Packet Loss: <0.1%
Jitter: <10ms

Ports Required:
  Machine 1 → Machine 2:
    - 50051/TCP (gRPC - AI communication)
    - 8000/TCP (REST API - optional, for admin)
  
  Machine 2 → Internet:
    - 443/TCP (HTTPS - DeepSeek API)
    - 5432/TCP (PostgreSQL - if remote DB)

Security:
  - Private network recommended (VPN or VLAN)
  - TLS encryption for gRPC (production)
  - Firewall rules (whitelist only)
```

### 1.4 External Services

**Required:**

```yaml
DeepSeek API Account:
  - URL: https://platform.deepseek.com
  - Cost: $0.14/1M input tokens, $0.28/1M output tokens
  - Estimated: $100-250/month (21 agents, optimized)
  - Fallback: Can use CPU-based LLM (Gemma 27B)
```

**Optional:**

```yaml
Monitoring:
  - Prometheus: Self-hosted (free)
  - Grafana: Self-hosted (free)
  - Uptime monitoring: UptimeRobot (free tier)

Backups:
  - S3-compatible storage: Wasabi, Backblaze B2
  - Cost: $5-20/month for 100-500GB
```

---

## 2. Architecture Overview

### 2.1 Deployment Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet / WAN                            │
│                                                                  │
│  Players ──→ Game Client ──→ Machine 1 (Game Server)           │
│                                     ↓                            │
│                             Private Network                      │
│                                     ↓                            │
│                              Machine 2 (AI Sidecar)             │
│                                     ↓                            │
│                             DeepSeek API (Cloud)                │
└─────────────────────────────────────────────────────────────────┘

Machine 1: rAthena Game Server
══════════════════════════════════════════════════════════════════
├─ rAthena Server Components:
│  ├─ login-server (Port 6900)
│  ├─ char-server (Port 6121)
│  └─ map-server (Port 5121) + AI Client
│
├─ AI gRPC Client:
│  ├─ C++ gRPC library
│  ├─ Protocol Buffers
│  ├─ Connection pool (16 connections)
│  └─ Fallback to legacy NPCs
│
└─ Databases:
   ├─ MySQL/MariaDB (rAthena game data)
   └─ Local cache (optional)

Machine 2: AI Sidecar Server
══════════════════════════════════════════════════════════════════
├─ AI Services:
│  ├─ FastAPI REST API (Port 8000, 48 workers)
│  ├─ gRPC Server (Port 50051)
│  ├─ 21 AI Agents (CrewAI orchestration)
│  └─ 28 ML Models (23 GPU + 5 CPU)
│
├─ Databases:
│  ├─ PostgreSQL 17.2 (AI data, multi-tenant)
│  │  ├─ pgvector 0.8.0 (embeddings)
│  │  ├─ TimescaleDB 2.18.0 (time-series)
│  │  └─ Apache AGE 1.6.0 (graph)
│  └─ DragonflyDB 1.24.0 (cache, 16GB)
│
├─ GPU Acceleration:
│  └─ NVIDIA RTX 3060 12GB (28 ML models)
│
└─ External Services:
   └─ DeepSeek API (LLM provider)
```

### 2.2 Data Flow

```
Player Action → rAthena map-server → AI gRPC Client
                                          ↓ gRPC/QUIC
                                     AI Sidecar gRPC Server
                                          ↓
                                   ┌──────┴──────┐
                                   │  FastAPI    │
                                   │  Middleware │
                                   └──────┬──────┘
                                          ↓
                         ┌────────────────┼────────────────┐
                         ↓                ↓                ↓
                    ML Models        AI Agents       Cache Layer
                    (28 models)     (21 agents)    (DragonflyDB)
                         ↓                ↓                ↓
                         └────────────────┼────────────────┘
                                          ↓
                                   Database Layer
                                   (PostgreSQL)
                                          ↓
                              Response → gRPC → rAthena
                                          ↓
                                   Player Receives
```

---

## 3. Pre-Deployment Planning

### 3.1 Deployment Checklist

**Planning Phase:**

- [ ] Hardware procured (both machines)
- [ ] Network topology designed
- [ ] IP addressing planned
- [ ] Domain names registered (optional)
- [ ] TLS certificates ordered (production)
- [ ] DeepSeek API account created
- [ ] Budget approved ($300-700/month for cloud or $100-200/month for self-hosted)
- [ ] Stakeholders notified
- [ ] Maintenance window scheduled

**Security Planning:**

- [ ] Firewall rules documented
- [ ] VPN or private network configured
- [ ] API keys generated and stored securely
- [ ] Database passwords generated (strong, 32+ characters)
- [ ] Backup strategy defined
- [ ] Disaster recovery plan documented
- [ ] Security audit scheduled

**Operational Planning:**

- [ ] Monitoring tools selected
- [ ] Alert thresholds defined
- [ ] On-call schedule established
- [ ] Runbook created
- [ ] Escalation procedures documented
- [ ] Change management process defined

### 3.2 Timeline Estimation

**Total Deployment Time:** 8-12 hours (experienced admin)

| Phase | Duration | Description |
|-------|----------|-------------|
| Machine 2 - OS Installation | 1-2 hours | Ubuntu 22.04, updates, basics |
| Machine 2 - NVIDIA Setup | 1-2 hours | Drivers, CUDA 12.6, cuDNN |
| Machine 2 - Database Setup | 1-2 hours | PostgreSQL 17.2 + extensions |
| Machine 2 - AI Sidecar Install | 2-3 hours | Python, deps, ML models |
| Machine 2 - Configuration | 1 hour | .env setup, testing |
| Machine 1 - rAthena Setup | 1-2 hours | Build, configure, test |
| Integration Testing | 1-2 hours | Verify connectivity |
| Production Verification | 1 hour | Smoke tests, monitoring |

**Recommended Approach:**
1. Set up Machine 2 first (AI Sidecar) - complete and test
2. Set up Machine 1 (rAthena) - integrate with AI Sidecar
3. Run integration tests
4. Go live with gradual rollout

---

## 4. Machine 2 Setup: AI Sidecar Server

### 4.1 Operating System Installation

**Step 1: Install Ubuntu 22.04 LTS Server**

```bash
# Download Ubuntu 22.04 LTS Server
# URL: https://ubuntu.com/download/server

# Create bootable USB (on local machine)
# Use Rufus (Windows) or dd (Linux):
sudo dd if=ubuntu-22.04-server-amd64.iso of=/dev/sdX bs=4M status=progress

# Boot from USB and install:
# - Minimal installation
# - OpenSSH server enabled
# - No snap packages (optional)
# - Use entire disk for simplicity

# After installation, update system
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

**Step 2: Configure Network**

```bash
# Set static IP (if not DHCP)
sudo nano /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  version: 2
  ethernets:
    ens1f0:  # Adjust interface name
      addresses:
        - 192.168.1.100/24
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

```bash
# Apply network configuration
sudo netplan apply

# Verify connectivity
ping -c 4 google.com
```

**Step 3: Configure SSH Access**

```bash
# Generate SSH key on your local machine (if not already done)
ssh-keygen -t ed25519 -C "admin@ai-sidecar"

# Copy public key to server
ssh-copy-id -i ~/.ssh/id_ed25519.pub admin@192.168.1.100

# Disable password authentication (security)
sudo nano /etc/ssh/sshd_config
```

```ini
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

```bash
# Restart SSH
sudo systemctl restart sshd
```

**Step 4: Install Essential Packages**

```bash
# System utilities
sudo apt install -y \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    curl \
    wget \
    git \
    vim \
    htop \
    iotop \
    net-tools \
    lsof \
    screen \
    tmux \
    unzip

# Development tools
sudo apt install -y \
    pkg-config \
    cmake \
    autoconf \
    automake \
    libtool \
    libssl-dev \
    zlib1g-dev
```

### 4.2 NVIDIA Driver and CUDA Installation

**Step 1: Install NVIDIA Driver 570 Series**

```bash
# Remove any existing NVIDIA drivers
sudo apt remove --purge nvidia-* -y
sudo apt autoremove -y

# Add graphics drivers PPA (for latest drivers)
sudo add-apt-repository ppa:graphics-drivers/ppa -y
sudo apt update

# Install NVIDIA driver 570 series (latest as of 2026)
sudo apt install -y nvidia-driver-570 nvidia-utils-570

# Reboot to load driver
sudo reboot

# After reboot, verify installation
nvidia-smi

# Expected output:
# +-----------------------------------------------------------------------------+
# | NVIDIA-SMI 570.XX.XX    Driver Version: 570.XX.XX    CUDA Version: 12.6     |
# |-------------------------------+----------------------+----------------------+
# | GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
# | Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
# |===============================+======================+======================|
# |   0  NVIDIA GeForce ... Off  | 00000000:03:00.0 Off |                  N/A |
# | 30%   35C    P0    25W / 170W |      0MiB / 12288MiB |      0%      Default |
# +-------------------------------+----------------------+----------------------+
```

**Step 2: Install CUDA Toolkit 12.6**

```bash
# Download CUDA 12.6 repository pin
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600

# Download CUDA 12.6 local installer
wget https://developer.download.nvidia.com/compute/cuda/12.6.0/local_installers/cuda-repo-ubuntu2204-12-6-local_12.6.0-570.30.05-1_amd64.deb

# Install repository
sudo dpkg -i cuda-repo-ubuntu2204-12-6-local_12.6.0-570.30.05-1_amd64.deb

# Add repository key
sudo cp /var/cuda-repo-ubuntu2204-12-6-local/cuda-*-keyring.gpg /usr/share/keyrings/

# Update and install CUDA
sudo apt update
sudo apt install -y cuda-toolkit-12-6

# Set environment variables
echo 'export CUDA_HOME=/usr/local/cuda-12.6' >> ~/.bashrc
echo 'export PATH=$CUDA_HOME/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

# Verify CUDA installation
nvcc --version

# Expected output:
# nvcc: NVIDIA (R) Cuda compiler driver
# Copyright (c) 2005-2024 NVIDIA Corporation
# Built on ...
# Cuda compilation tools, release 12.6, V12.6.XX
```

**Step 3: Install cuDNN 9.0**

```bash
# Install cuDNN
sudo apt install -y libcudnn9 libcudnn9-dev libcudnn9-cuda-12

# Verify installation
ldconfig -p | grep cudnn

# Expected: Multiple libcudnn libraries listed
```

**Step 4: Verify GPU Acceleration**

```bash
# Test PyTorch CUDA support (will install in next section)
python3 -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'Device: {torch.cuda.get_device_name(0)}')" 2>/dev/null || echo "PyTorch not yet installed"
```

### 4.3 PostgreSQL 17.2 Installation with Extensions

**Step 1: Install PostgreSQL 17.2**

```bash
# Add PostgreSQL repository
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/pgdg.asc
sudo apt update

# Install PostgreSQL 17.2
sudo apt install -y postgresql-17 postgresql-contrib-17 postgresql-17-pgvector

# Verify installation
psql --version
# Expected: psql (PostgreSQL) 17.2
```

**Step 2: Install pgvector Extension**

```bash
# Install pgvector (should already be installed from previous step)
sudo apt install -y postgresql-17-pgvector

# Verify
sudo -u postgres psql -c "SELECT * FROM pg_available_extensions WHERE name='vector';"
# Expected: vector extension listed
```

**Step 3: Install TimescaleDB Extension**

```bash
# Add TimescaleDB repository
sudo sh -c "echo 'deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main' > /etc/apt/sources.list.d/timescaledb.list"
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo apt-key add -
sudo apt update

# Install TimescaleDB 2.18
sudo apt install -y timescaledb-2-postgresql-17

# Run tuning script (optimizes PostgreSQL for TimescaleDB)
sudo timescaledb-tune --quiet --yes

# Verify
sudo -u postgres psql -c "SELECT * FROM pg_available_extensions WHERE name='timescaledb';"
```

**Step 4: Install Apache AGE Extension**

```bash
# Install dependencies
sudo apt install -y postgresql-server-dev-17 flex bison

# Clone Apache AGE repository
cd /tmp
git clone https://github.com/apache/age.git
cd age
git checkout release/PG17/v1.6.0

# Build and install
make
sudo make install

# Verify
sudo -u postgres psql -c "SELECT * FROM pg_available_extensions WHERE name='age';"
```

**Step 5: Configure PostgreSQL for R730 Hardware**

```bash
# Edit PostgreSQL configuration
sudo nano /etc/postgresql/17/main/postgresql.conf
```

**Optimized Configuration for Dell R730 (192GB RAM, 32 cores):**

```ini
# Connection Settings
listen_addresses = '*'
port = 5432
max_connections = 100
superuser_reserved_connections = 3

# Memory Settings
shared_buffers = 8GB                      # ~4% of RAM
effective_cache_size = 64GB               # ~33% of RAM
maintenance_work_mem = 2GB
work_mem = 64MB

# Parallel Query Settings
max_worker_processes = 32                 # Match CPU cores
max_parallel_workers_per_gather = 8
max_parallel_workers = 32
max_parallel_maintenance_workers = 8

# WAL Settings
wal_level = replica
wal_compression = on
max_wal_size = 8GB
min_wal_size = 2GB
checkpoint_completion_target = 0.9
checkpoint_timeout = 10min

# Query Planner
random_page_cost = 1.1                    # NVMe SSD (default 4.0 for HDD)
effective_io_concurrency = 200            # NVMe can handle high concurrency
cpu_tuple_cost = 0.01
cpu_operator_cost = 0.0025

# Logging
logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_min_duration_statement = 1000         # Log queries >1s

# Statistics
shared_preload_libraries = 'timescaledb,pg_stat_statements,age'
pg_stat_statements.track = all
pg_stat_statements.max = 10000

# Extensions
age.enable_global_graph_contexts = on
```

```bash
# Edit pg_hba.conf for network access
sudo nano /etc/postgresql/17/main/pg_hba.conf
```

```ini
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             postgres                                peer
local   all             all                                     peer
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
host    ai_world        ai_world        192.168.1.0/24          scram-sha-256
```

```bash
# Restart PostgreSQL
sudo systemctl restart postgresql

# Enable PostgreSQL on boot
sudo systemctl enable postgresql
```

**Step 6: Create Database and User**

```bash
# Create database and user
sudo -u postgres psql <<EOF
-- Create user
CREATE USER ai_world WITH ENCRYPTED PASSWORD 'your_very_secure_password_here_32_chars_min';

-- Create database
CREATE DATABASE ai_world OWNER ai_world;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE ai_world TO ai_world;

-- Connect to database
\c ai_world

-- Install extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS age;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Verify extensions
SELECT extname, extversion FROM pg_extension;

-- Expected output:
-- vector     | 0.8.0
-- timescaledb| 2.18.0
-- age        | 1.6.0
-- ...

\q
EOF
```

### 4.4 DragonflyDB Installation

**Step 1: Install DragonflyDB**

```bash
# Install DragonflyDB (Redis-compatible cache)
curl -fsSL https://dragonflydb.io/install.sh | bash

# Verify installation
dragonfly --version
# Expected: dragonfly version 1.24.0 or higher
```

**Step 2: Configure DragonflyDB**

```bash
# Create configuration directory
sudo mkdir -p /etc/dragonfly

# Create configuration file
sudo nano /etc/dragonfly/dragonfly.conf
```

```ini
# DragonflyDB Configuration for AI Sidecar
# Optimized for 192GB RAM system

# Server
bind 127.0.0.1
port 6379
protected-mode yes
requirepass your_redis_password_here_change_this

# Memory
maxmemory 16gb
maxmemory-policy allkeys-lru

# Persistence
dir /var/lib/dragonfly
dbfilename dump.rdb
save 900 1                # Save if 1 key changed in 15 minutes
save 300 10               # Save if 10 keys changed in 5 minutes
save 60 10000             # Save if 10k keys changed in 1 minute

# Performance
io-threads 8              # Use 8 threads for I/O (optimize for 32 cores)
tcp-backlog 511
timeout 0
tcp-keepalive 300

# Logging
loglevel notice
logfile /var/log/dragonfly/dragonfly.log
```

```bash
# Create data directory
sudo mkdir -p /var/lib/dragonfly
sudo mkdir -p /var/log/dragonfly

# Create dragonfly user
sudo useradd -r -s /bin/false dragonfly
sudo chown -R dragonfly:dragonfly /var/lib/dragonfly
sudo chown -R dragonfly:dragonfly /var/log/dragonfly

# Create systemd service
sudo nano /etc/systemd/system/dragonfly.service
```

```ini
[Unit]
Description=DragonflyDB Server
After=network.target
Documentation=https://dragonflydb.io

[Service]
Type=simple
User=dragonfly
Group=dragonfly
WorkingDirectory=/var/lib/dragonfly
ExecStart=/usr/local/bin/dragonfly --logtostderr --alsologtostderr=false --logbuflevel=-1
Restart=always
RestartSec=5s
LimitNOFILE=65535

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/var/lib/dragonfly /var/log/dragonfly

[Install]
WantedBy=multi-user.target
```

```bash
# Start DragonflyDB
sudo systemctl daemon-reload
sudo systemctl enable dragonfly
sudo systemctl start dragonfly

# Verify DragonflyDB is running
sudo systemctl status dragonfly

# Test connection
redis-cli -a your_redis_password_here_change_this ping
# Expected: PONG
```

### 4.5 Python 3.12 and Dependencies Installation

**Step 1: Install Python 3.12.8**

```bash
# Add deadsnakes PPA (for latest Python)
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update

# Install Python 3.12.8
sudo apt install -y \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    python3-pip

# Set Python 3.12 as default (optional)
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

# Verify installation
python3.12 --version
# Expected: Python 3.12.8
```

**Step 2: Clone AI Sidecar Repository**

```bash
# Create application directory
sudo mkdir -p /opt/ai-sidecar
sudo chown $USER:$USER /opt/ai-sidecar
cd /opt/ai-sidecar

# Clone repository (or copy files)
# Option A: Git clone
git clone https://github.com/your-org/rathena-ai-world-sidecar-server.git .

# Option B: Copy from local directory
# scp -r /local/path/rathena-ai-world-sidecar-server/* admin@192.168.1.100:/opt/ai-sidecar/

# Verify files
ls -la
# Expected: main.py, requirements.txt, agents/, ml_models/, etc.
```

**Step 3: Create Python Virtual Environment**

```bash
cd /opt/ai-sidecar

# Create virtual environment
python3.12 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Upgrade pip, setuptools, wheel
pip install --upgrade pip setuptools wheel

# Verify
pip --version
# Expected: pip 24.x from /opt/ai-sidecar/venv/bin/pip
```

**Step 4: Install Python Dependencies**

```bash
# Install all dependencies from requirements.txt
pip install -r requirements.txt

# This will install:
# - FastAPI, Uvicorn (web framework)
# - CrewAI (agent orchestration)
# - PyTorch (ML framework)
# - Transformers (NLP models)
# - gRPC, protobuf (communication)
# - psycopg2-binary (PostgreSQL)
# - redis (DragonflyDB client)
# - And 50+ other dependencies...

# Installation may take 10-15 minutes

# Verify PyTorch with CUDA
python -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')"

# Expected output:
# PyTorch: 2.6.0+cu126
# CUDA available: True
# GPU: NVIDIA GeForce RTX 3060
```

**Step 5: Install gRPC Tools**

```bash
# Install gRPC tools for Protocol Buffers compilation
pip install grpcio-tools

# Verify gRPC installation
python -c "import grpc; print(f'gRPC version: {grpc.__version__}')"
# Expected: gRPC version: 1.60.0 or higher
```

### 4.6 Download ML Models

**Step 1: Run Model Download Script**

```bash
cd /opt/ai-sidecar

# Download all 9 NLP models from HuggingFace
python scripts/download_models.py

# Expected output:
# Downloading ML models from HuggingFace Hub...
# Model cache directory: ./models/
# 
# [1/9] Downloading distilbert-base-uncased... ✓ (250MB)
# [2/9] Downloading cardiffnlp/twitter-roberta-base-sentiment-latest... ✓ (500MB)
# [3/9] Downloading j-hartmann/emotion-english-distilroberta-base... ✓ (300MB)
# [4/9] Downloading dslim/bert-base-NER... ✓ (400MB)
# [5/9] Downloading facebook/bart-large-mnli... ✓ (600MB)
# [6/9] Downloading papluca/xlm-roberta-base-language-detection... ✓ (300MB)
# [7/9] Downloading sentence-transformers/all-MiniLM-L6-v2... ✓ (100MB)
# [8/9] Downloading cross-encoder/ms-marco-MiniLM-L-6-v2... ✓ (80MB)
# [9/9] Downloading unitary/toxic-bert... ✓ (400MB)
# 
# ✅ All 9 NLP models downloaded successfully
# Total size: ~2.5GB
# Cache location: /opt/ai-sidecar/models/
```

**Step 2: Verify Model Files**

```bash
# Check models directory
ls -lh models/

# Expected output: 9 directories with model weights
# distilbert-base-uncased/
# cardiffnlp_twitter-roberta-base-sentiment-latest/
# j-hartmann_emotion-english-distilroberta-base/
# dslim_bert-base-NER/
# facebook_bart-large-mnli/
# papluca_xlm-roberta-base-language-detection/
# sentence-transformers_all-MiniLM-L6-v2/
# cross-encoder_ms-marco-MiniLM-L-6-v2/
# unitary_toxic-bert/

# Check total size
du -sh models/
# Expected: ~2.5GB
```

### 4.7 Database Schema Setup

**Step 1: Run Database Setup Script**

```bash
cd /opt/ai-sidecar

# Run database initialization script
python scripts/setup_database.py

# Expected output:
# Initializing AI World database...
# 
# ✓ Connecting to PostgreSQL at localhost:5432
# ✓ Database 'ai_world' exists
# ✓ Extensions verified: vector, timescaledb, age
# 
# Creating demo server schema...
# ✓ Created schema: server_demo
# ✓ Created table: server_demo.npc_personalities
# ✓ Created table: server_demo.npc_memories
# ✓ Created table: server_demo.npc_relationships
# ✓ Created table: server_demo.npc_knowledge
# ✓ Created table: server_demo.player_profiles
# ✓ Created table: server_demo.conversations
# ✓ Created table: server_demo.quests_dynamic
# ✓ Created table: server_demo.quest_templates
# ✓ Created table: server_demo.world_events
# ✓ Created table: server_demo.world_state_snapshots
# ✓ Created table: server_demo.economic_transactions
# ✓ Created table: server_demo.llm_request_cache
# ✓ Created table: server_demo.npc_decisions_log
# ✓ Created table: server_demo.information_sharing_log
# ✓ Created table: server_demo.reputation_scores
# ✓ Created table: server_demo.faction_nodes
# ✓ Created table: server_demo.agent_performance_metrics
# ✓ Created table: server_demo.ml_model_predictions
# ✓ Created table: server_demo.dialogue_embeddings
# ✓ Created table: server_demo.player_interaction_graph
# 
# Creating shared public schema tables...
# ✓ Created table: public.registered_servers
# ✓ Created table: public.llm_response_cache
# ✓ Created table: public.ml_model_cache
# 
# ✅ Database setup complete!
# Total tables created: 23 (20 in server_demo + 3 in public)
```

**Step 2: Verify Database Schema**

```bash
# Connect to database
sudo -u postgres psql -d ai_world

# List all schemas
\dn

# Expected output:
# List of schemas
#     Name      | Owner
# --------------+----------
#  public       | postgres
#  server_demo  | ai_world
#  ag_catalog   | postgres  (Apache AGE)
#  timescaledb_information | postgres

# List tables in server_demo schema
\dt server_demo.*

# Expected: 20 tables listed

# List tables in public schema
\dt public.*

# Expected: 3-6 tables (registered_servers, llm_response_cache, etc.)

# Exit
\q
```

### 4.8 Configure Environment Variables

**Step 1: Create .env File**

```bash
cd /opt/ai-sidecar

# Copy example environment file
cp .env.example .env

# Edit with actual values
nano .env
```

**Production .env Configuration:**

```bash
# =============================================================================
# AI Sidecar Production Configuration
# =============================================================================

# Application
APP_NAME=rAthena AI World Sidecar
APP_VERSION=1.0.0
ENVIRONMENT=production
DEBUG=false
LOG_LEVEL=INFO

# Server
HOST=0.0.0.0
PORT=8000
WORKERS=48                          # 75% of 64 threads
RELOAD=false

# gRPC Server
GRPC_PORT=50051
GRPC_MAX_WORKERS=48
GRPC_KEEPALIVE_TIME_MS=30000
GRPC_KEEPALIVE_TIMEOUT_MS=10000

# Security
SECRET_KEY=generate_with_python_secrets_token_urlsafe_32
API_KEY_SALT=generate_another_random_secret
ALLOWED_HOSTS=["*"]
CORS_ORIGINS=["*"]

# Database - PostgreSQL
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=ai_world
POSTGRES_USER=ai_world
POSTGRES_PASSWORD=your_very_secure_password_here
POSTGRES_MAX_POOL_SIZE=50
POSTGRES_MIN_POOL_SIZE=10
POSTGRES_POOL_TIMEOUT=30

# Cache - DragonflyDB
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password_here
REDIS_DB=0
REDIS_MAX_CONNECTIONS=100
REDIS_SOCKET_TIMEOUT=5

# LLM Provider - DeepSeek
DEEPSEEK_API_KEY=sk-your-deepseek-api-key-here
DEEPSEEK_API_BASE=https://api.deepseek.com/v1
DEEPSEEK_MODEL=deepseek-chat
DEEPSEEK_MAX_TOKENS=4096
DEEPSEEK_TEMPERATURE=0.7
DEEPSEEK_TIMEOUT=30

# ML Models
ML_DEVICE=cuda                      # cuda, cpu, mps
ML_FP16_INFERENCE=true             # Enable half precision for 2× VRAM savings
ML_BATCH_SIZE=32
ML_MODEL_PATH=./models
LOAD_VISUAL_MODELS=false           # Set to true if using visual models

# Cache Configuration
CACHE_TTL_DIALOGUE=3600            # 1 hour
CACHE_TTL_QUEST=86400              # 24 hours
CACHE_TTL_LLM_RESPONSE=86400       # 24 hours
CACHE_TTL_ML_PREDICTION=7200       # 2 hours
ENABLE_SEMANTIC_DEDUP=true
ENABLE_TEMPLATE_REUSE=true

# Performance
MAX_CONCURRENT_REQUESTS=1000
REQUEST_TIMEOUT=30
RATE_LIMIT_PER_MINUTE=1000
RATE_LIMIT_PER_HOUR=50000

# Monitoring
ENABLE_METRICS=true
METRICS_PORT=9090
PROMETHEUS_MULTIPROC_DIR=/tmp/prometheus_multiproc

# Logging
LOG_FILE=/var/log/ai-sidecar/app.log
LOG_ROTATION=1d
LOG_MAX_SIZE=100MB
LOG_BACKUP_COUNT=30
LOG_JSON_FORMAT=false

# Feature Flags
ENABLE_MULTI_TENANT=true
ENABLE_CROSS_SERVER_MEMORY=false   # Set true if NPCs remember across servers
ENABLE_VISUAL_MODELS=false
ENABLE_ADVANCED_ANALYTICS=true
```

**Step 2: Generate Secret Keys**

```bash
# Generate SECRET_KEY
python3 -c "import secrets; print(f'SECRET_KEY={secrets.token_urlsafe(32)}')"

# Generate API_KEY_SALT
python3 -c "import secrets; print(f'API_KEY_SALT={secrets.token_urlsafe(32)}')"

# Copy generated values to .env file
```

**Step 3: Secure .env File**

```bash
# Set strict permissions (only owner can read)
chmod 600 .env

# Verify
ls -l .env
# Expected: -rw------- 1 user user ... .env
```

### 4.9 Generate gRPC Protocol Buffers

**Step 1: Compile Protocol Buffers**

```bash
cd /opt/ai-sidecar/grpc_service

# Run generation script
bash generate_proto.sh

# Expected output:
# Compiling Protocol Buffers...
# ✓ Generated ai_service_pb2.py
# ✓ Generated ai_service_pb2_grpc.py
# Protocol Buffers compiled successfully
```

**Step 2: Verify Generated Files**

```bash
# Check generated files
ls -l grpc_service/

# Expected files:
# ai_service.proto           (source definition)
# ai_service_pb2.py          (generated messages)
# ai_service_pb2_grpc.py     (generated service)
```

### 4.10 Start AI Sidecar Server

**Step 1: Test Server Startup**

```bash
cd /opt/ai-sidecar
source venv/bin/activate

# Start server in foreground (for testing)
python main.py

# Watch startup sequence carefully
# Expected: All components load successfully (see Integration Testing guide)
# If successful, press Ctrl+C to stop

# Check for errors
# Common issues:
# - Missing environment variables
# - Database connection failures
# - Model loading errors
# - Port already in use
```

**Step 2: Create Systemd Service**

```bash
# Create systemd service file
sudo nano /etc/systemd/system/ai-sidecar.service
```

```ini
[Unit]
Description=rAthena AI World Sidecar Server
Documentation=https://github.com/your-org/rathena-ai-world-sidecar-server
After=network.target postgresql.service dragonfly.service
Wants=postgresql.service dragonfly.service

[Service]
Type=simple
User=aiworld
Group=aiworld
WorkingDirectory=/opt/ai-sidecar
Environment="PATH=/opt/ai-sidecar/venv/bin:/usr/local/cuda-12.6/bin:/usr/local/bin:/usr/bin:/bin"
Environment="LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64"
Environment="CUDA_HOME=/usr/local/cuda-12.6"

# Start command with NUMA optimization
ExecStart=/usr/bin/numactl --cpunodebind=0 --membind=0 \
    /opt/ai-sidecar/venv/bin/uvicorn main:app \
    --host 0.0.0.0 \
    --port 8000 \
    --workers 48 \
    --log-level info \
    --access-log \
    --use-colors

# Restart policy
Restart=always
RestartSec=10s
StartLimitBurst=5
StartLimitInterval=60s

# Resource limits
LimitNOFILE=65535
LimitNPROC=32768

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/opt/ai-sidecar /var/log/ai-sidecar /tmp/prometheus_multiproc

# Process management
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30s

[Install]
WantedBy=multi-user.target
```

**Step 3: Create Service User**

```bash
# Create dedicated user for AI Sidecar
sudo useradd -r -s /bin/bash -d /opt/ai-sidecar -m aiworld

# Set ownership
sudo chown -R aiworld:aiworld /opt/ai-sidecar

# Create log directory
sudo mkdir -p /var/log/ai-sidecar
sudo chown aiworld:aiworld /var/log/ai-sidecar
```

**Step 4: Enable and Start Service**

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service (start on boot)
sudo systemctl enable ai-sidecar

# Start service
sudo systemctl start ai-sidecar

# Check status
sudo systemctl status ai-sidecar

# Expected output:
# ● ai-sidecar.service - rAthena AI World Sidecar Server
#    Loaded: loaded (/etc/systemd/system/ai-sidecar.service; enabled)
#    Active: active (running) since ...
#    Main PID: ...
#    Tasks: 50 (limit: ...)
#    Memory: 45.2G
#    CPU: 12min 3s
```

**Step 5: Verify Service Health**

```bash
# Check logs
sudo journalctl -u ai-sidecar -f

# Test health endpoint
curl http://localhost:8000/api/v1/health

# Expected: {"status": "healthy", ...}

# Test gRPC port
nc -zv localhost 50051
# Expected: Connection to localhost 50051 port [tcp/*] succeeded!

# Monitor resource usage
htop           # CPU and RAM
nvidia-smi -l 1  # GPU (refresh every second)
```

### 4.11 Configure Firewall

**Step 1: Install UFW (if not installed)**

```bash
# Install UFW
sudo apt install -y ufw

# Allow SSH (IMPORTANT - do this first!)
sudo ufw allow 22/tcp comment 'SSH'

# Allow gRPC from rAthena server
sudo ufw allow from 192.168.1.50 to any port 50051 proto tcp comment 'gRPC from rAthena'

# Allow REST API (optional, for admin access)
sudo ufw allow from 192.168.1.0/24 to any port 8000 proto tcp comment 'REST API admin'

# Allow PostgreSQL (only if remote access needed)
# sudo ufw allow from trusted_ip to any port 5432 proto tcp comment 'PostgreSQL'

# Enable firewall
sudo ufw enable

# Verify rules
sudo ufw status numbered

# Expected output:
# Status: active
# 
#      To                         Action      From
#      --                         ------      ----
# [ 1] 22/tcp                     ALLOW IN    Anywhere
# [ 2] 50051/tcp                  ALLOW IN    192.168.1.50
# [ 3] 8000/tcp                   ALLOW IN    192.168.1.0/24
```

### 4.12 Setup Automated Backups

**Step 1: Create Backup Script**

```bash
# Create backup directory
sudo mkdir -p /backups/postgresql
sudo mkdir -p /backups/dragonfly
sudo chown aiworld:aiworld /backups

# Create backup script
sudo nano /usr/local/bin/backup_ai_sidecar.sh
```

```bash
#!/bin/bash
# AI Sidecar Backup Script
# Runs daily at 2 AM via cron

set -e

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

echo "[$(date)] Starting AI Sidecar backup..."

# Backup PostgreSQL
echo "Backing up PostgreSQL..."
sudo -u postgres pg_dump -Fc ai_world > "$BACKUP_DIR/postgresql/ai_world_$DATE.dump"
echo "✓ PostgreSQL backup: ai_world_$DATE.dump"

# Backup DragonflyDB (optional - cache data is ephemeral)
echo "Backing up DragonflyDB..."
redis-cli -a "$REDIS_PASSWORD" --rdb "$BACKUP_DIR/dragonfly/dump_$DATE.rdb"
echo "✓ DragonflyDB backup: dump_$DATE.rdb"

# Backup configuration files
echo "Backing up configuration..."
tar -czf "$BACKUP_DIR/config/config_$DATE.tar.gz" \
    /opt/ai-sidecar/.env \
    /etc/systemd/system/ai-sidecar.service \
    /etc/postgresql/17/main/postgresql.conf \
    /etc/dragonfly/dragonfly.conf
echo "✓ Configuration backup: config_$DATE.tar.gz"

# Delete old backups
echo "Cleaning old backups (>$RETENTION_DAYS days)..."
find "$BACKUP_DIR/postgresql" -name "*.dump" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR/dragonfly" -name "*.rdb" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR/config" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

# Calculate backup sizes
PGSQL_SIZE=$(du -sh "$BACKUP_DIR/postgresql" | cut -f1)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

echo "[$(date)] Backup complete!"
echo "PostgreSQL backups: $PGSQL_SIZE"
echo "Total backup size: $TOTAL_SIZE"

# Send notification (optional)
# curl -X POST https://your-monitoring-service.com/webhook ...

exit 0
```

```bash
# Make executable
sudo chmod +x /usr/local/bin/backup_ai_sidecar.sh

# Test backup
sudo /usr/local/bin/backup_ai_sidecar.sh

# Verify backup created
ls -lh /backups/postgresql/
```

**Step 2: Schedule Automated Backups**

```bash
# Add to crontab (runs daily at 2 AM)
sudo crontab -e
```

```cron
# AI Sidecar automated backups
0 2 * * * /usr/local/bin/backup_ai_sidecar.sh >> /var/log/ai-sidecar/backup.log 2>&1

# Weekly database vacuum (Sundays at 3 AM)
0 3 * * 0 sudo -u postgres psql -d ai_world -c "VACUUM ANALYZE;" >> /var/log/postgresql/vacuum.log 2>&1
```

**Step 3: Test Restore Procedure**

```bash
# Test database restore (on test database)
sudo -u postgres createdb ai_world_test
sudo -u postgres pg_restore -d ai_world_test /backups/postgresql/ai_world_YYYYMMDD_HHMMSS.dump

# Verify restore
sudo -u postgres psql -d ai_world_test -c "\dt server_demo.*"

# Clean up test database
sudo -u postgres dropdb ai_world_test
```

---

## 5. Machine 1 Setup: rAthena Game Server

### 5.1 Operating System Installation

**Step 1: Install Ubuntu 22.04 LTS**

```bash
# Standard Ubuntu 22.04 LTS installation
# Same process as Machine 2 (Section 4.1)

# Update system
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

**Step 2: Install rAthena Dependencies**

```bash
# Install build dependencies
sudo apt install -y \
    git \
    make \
    gcc \
    g++ \
    libmysqlclient-dev \
    zlib1g-dev \
    libpcre3-dev \
    libssl-dev

# Install MySQL/MariaDB (rAthena database)
sudo apt install -y mariadb-server mariadb-client

# Secure MySQL installation
sudo mysql_secure_installation
```

### 5.2 Install gRPC Dependencies (C++)

**Step 1: Install gRPC and Protocol Buffers**

```bash
# Install dependencies
sudo apt install -y \
    build-essential \
    autoconf \
    libtool \
    pkg-config \
    cmake

# Clone gRPC repository
cd /tmp
git clone --recurse-submodules -b v1.60.0 --depth 1 --shallow-submodules https://github.com/grpc/grpc
cd grpc

# Build and install gRPC
mkdir -p cmake/build
cd cmake/build
cmake -DgRPC_INSTALL=ON \
      -DgRPC_BUILD_TESTS=OFF \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      ../..
make -j$(nproc)
sudo make install
sudo ldconfig

# Verify installation
pkg-config --modversion grpc
# Expected: 1.60.0

pkg-config --modversion protobuf
# Expected: 3.21+
```

**Step 2: Install Additional Libraries**

```bash
# Install JSON library (for response parsing)
sudo apt install -y nlohmann-json3-dev

# Install HTTP library (for REST API fallback)
sudo apt install -y libcurl4-openssl-dev

# Verify installations
pkg-config --list-all | grep -E "(grpc|protobuf|json)"
```

### 5.3 Clone and Configure rAthena

**Step 1: Clone rAthena Repository**

```bash
# Create rAthena directory
sudo mkdir -p /opt/rathena
sudo chown $USER:$USER /opt/rathena
cd /opt/rathena

# Clone rAthena (or your fork with AI integration)
git clone https://github.com/rathena/rathena.git .

# Checkout stable branch
git checkout master

# Or clone your AI-integrated fork
# git clone https://github.com/your-org/rathena-ai-integrated.git .
```

**Step 2: Copy AI Client Files**

```bash
# Copy AI gRPC client files to rAthena source
# These files should be in your AI integration branch

cp /path/to/ai_grpc_client.hpp /opt/rathena/src/map/
cp /path/to/ai_grpc_client.cpp /opt/rathena/src/map/
cp /path/to/ai_bridge.hpp /opt/rathena/src/map/
cp /path/to/ai_bridge.cpp /opt/rathena/src/map/

# Copy Protocol Buffer definition
cp /opt/ai-sidecar/grpc_service/protos/ai_service.proto /opt/rathena/src/map/protos/
```

**Step 3: Generate Protocol Buffers for C++**

```bash
cd /opt/rathena/src/map

# Create protos directory if not exists
mkdir -p protos

# Compile Protocol Buffers for C++
protoc --cpp_out=. --grpc_out=. --plugin=protoc-gen-grpc=$(which grpc_cpp_plugin) protos/ai_service.proto

# Expected output:
# protos/ai_service.pb.h
# protos/ai_service.pb.cc
# protos/ai_service.grpc.pb.h
# protos/ai_service.grpc.pb.cc
```

### 5.4 Build rAthena with AI Support

**Step 1: Configure Build**

```bash
cd /opt/rathena

# Run configure script with AI support
./configure \
    --enable-packetver=20211103 \
    --enable-ai-sidecar \
    --with-grpc=/usr/local

# Expected output:
# ...
# AI Sidecar Support: yes
# gRPC Library: /usr/local
# Protocol Buffers: /usr/local
# ...
# Configuration complete
```

**Step 2: Build rAthena**

```bash
# Clean previous builds
make clean

# Build with parallel compilation (use all cores)
make -j$(nproc)

# Expected output:
# CC      src/map/ai_grpc_client.cpp
# CC      src/map/ai_bridge.cpp
# CC      src/map/protos/ai_service.pb.cc
# CC      src/map/protos/ai_service.grpc.pb.cc
# ...
# CC      src/map/map.cpp
# ...
# Linking map-server...
# ✓ Build complete

# Verify executables created
ls -lh login-server char-server map-server
# Expected: Three executables with recent timestamps
```

**Step 3: Install rAthena**

```bash
# Create installation directory
sudo mkdir -p /opt/rathena-server
sudo chown $USER:$USER /opt/rathena-server

# Copy executables and configuration
cp login-server char-server map-server /opt/rathena-server/
cp -r conf/ /opt/rathena-server/
cp -r db/ /opt/rathena-server/
cp -r npc/ /opt/rathena-server/

cd /opt/rathena-server
```

### 5.5 Configure rAthena AI Client

**Step 1: Create AI Sidecar Configuration File**

```bash
cd /opt/rathena-server/conf

# Create AI Sidecar configuration
nano ai_sidecar.conf
```

```ini
//===================================================================
// rAthena AI Sidecar Configuration
//===================================================================

// Enable AI Sidecar Integration
ai_sidecar_enabled: yes

// gRPC Connection Settings
ai_sidecar_protocol: grpc
ai_sidecar_endpoint: 192.168.1.100:50051    // AI Sidecar IP:port
ai_sidecar_transport: quic                  // Use QUIC transport (or tcp)

// TLS Security (production)
ai_sidecar_tls_enabled: yes
ai_sidecar_tls_ca_cert: /opt/rathena-server/certs/ca.crt
ai_sidecar_tls_client_cert: /opt/rathena-server/certs/client.crt
ai_sidecar_tls_client_key: /opt/rathena-server/certs/client.key

// Authentication
ai_sidecar_api_key: sk-your-server-specific-api-key-from-registration
ai_sidecar_game_server_id: server_production_001

// Performance Settings
ai_sidecar_connection_pool_size: 16
ai_sidecar_keepalive_ms: 30000
ai_sidecar_timeout_ms: 5000
ai_sidecar_max_retries: 3
ai_sidecar_retry_delay_ms: 100

// Message Settings
ai_sidecar_compression: gzip
ai_sidecar_max_message_size_mb: 50

// Fallback Behavior
ai_sidecar_fallback_to_legacy: yes
ai_sidecar_fallback_after_errors: 3

// Feature Flags
ai_sidecar_enable_dialogue: yes
ai_sidecar_enable_quests: yes
ai_sidecar_enable_decisions: yes
ai_sidecar_enable_memory: yes

// Logging
ai_sidecar_log_level: info              // debug, info, warning, error
ai_sidecar_log_requests: yes
ai_sidecar_log_responses: no            // Disable in production (verbose)

// Caching (optional local cache)
ai_sidecar_enable_local_cache: yes
ai_sidecar_cache_ttl_seconds: 3600
ai_sidecar_cache_max_entries: 10000
```

**Step 2: Import Configuration**

```bash
# Edit map-server configuration to import AI config
nano conf/map-server.conf
```

```ini
// At the top of map-server.conf, add:
import: conf/ai_sidecar.conf

// ... rest of existing configuration ...
```

### 5.6 Register Server with AI Sidecar

**Step 1: Register Game Server**

```bash
# Register this rAthena server with AI Sidecar
curl -X POST http://192.168.1.100:8000/admin/servers/register \
  -H "Content-Type: application/json" \
  -d '{
    "server_name": "Production Server 001",
    "contact_email": "admin@yourgame.com",
    "billing_tier": "standard",
    "max_concurrent_npcs": 1000,
    "rate_limit_per_minute": 1000
  }'

# Expected response:
{
  "message": "Server registered successfully",
  "server_id": "server-abc123def456",
  "api_key": "sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "schema_name": "server_abc123",
  "warning": "Save this API key securely. It cannot be recovered.",
  "max_concurrent_npcs": 1000,
  "rate_limit_per_minute": 1000
}

# ⚠️ CRITICAL: Save the API key immediately!
# Copy the api_key value to ai_sidecar.conf
```

**Step 2: Update Configuration with API Key**

```bash
# Edit ai_sidecar.conf with the received API key
nano conf/ai_sidecar.conf
```

```ini
# Update these lines with values from registration:
ai_sidecar_api_key: sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ai_sidecar_game_server_id: server-abc123def456
```

### 5.7 Start rAthena Servers

**Step 1: Configure MySQL Database**

```bash
# Create rAthena database
sudo mysql <<EOF
CREATE DATABASE rathena;
CREATE USER 'rathena'@'localhost' IDENTIFIED BY 'secure_password_here';
GRANT ALL PRIVILEGES ON rathena.* TO 'rathena'@'localhost';
FLUSH PRIVILEGES;
EOF

# Import rAthena SQL files
mysql -u rathena -p rathena < sql-files/main.sql
mysql -u rathena -p rathena < sql-files/logs.sql
mysql -u rathena -p rathena < sql-files/mob_db.sql
mysql -u rathena -p rathena < sql-files/item_db.sql
```

**Step 2: Configure Database Connection**

```bash
# Edit inter-server configuration
nano conf/inter-server.conf
```

```ini
// MySQL Database Settings
sql.db_hostname: 127.0.0.1
sql.db_port: 3306
sql.db_username: rathena
sql.db_password: secure_password_here
sql.db_database: rathena
sql.codepage: utf8mb4
```

**Step 3: Start rAthena Servers**

```bash
cd /opt/rathena-server

# Start login server
./login-server &

# Wait 5 seconds
sleep 5

# Start char server
./char-server &

# Wait 5 seconds
sleep 5

# Start map server (with AI integration)
./map-server &

# Check logs
tail -f log/map-server.log

# Expected output:
# [Info]: Loading maps...
# [Info]: Successfully loaded 900+ maps
# [Info]: AI Sidecar: Connecting to 192.168.1.100:50051...
# [Info]: AI Sidecar: gRPC connection established
# [Info]: AI Sidecar: Authenticated as server-abc123def456
# [Info]: AI Sidecar: Schema isolation active: server_abc123
# [Status]: Server is ready and listening on port 5121
# [Status]: AI Sidecar integration: ACTIVE
```

**Step 4: Create Systemd Services (Production)**

```bash
# Create login-server service
sudo nano /etc/systemd/system/rathena-login.service
```

```ini
[Unit]
Description=rAthena Login Server
After=network.target mysql.service

[Service]
Type=simple
User=rathena
Group=rathena
WorkingDirectory=/opt/rathena-server
ExecStart=/opt/rathena-server/login-server
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

```bash
# Create char-server service
sudo nano /etc/systemd/system/rathena-char.service
```

```ini
[Unit]
Description=rAthena Character Server
After=network.target mysql.service rathena-login.service

[Service]
Type=simple
User=rathena
Group=rathena
WorkingDirectory=/opt/rathena-server
ExecStart=/opt/rathena-server/char-server
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

```bash
# Create map-server service (with AI dependency)
sudo nano /etc/systemd/system/rathena-map.service
```

```ini
[Unit]
Description=rAthena Map Server with AI Integration
After=network.target mysql.service rathena-login.service rathena-char.service
Wants=ai-sidecar-connection.service

[Service]
Type=simple
User=rathena
Group=rathena
WorkingDirectory=/opt/rathena-server
ExecStart=/opt/rathena-server/map-server
Restart=always
RestartSec=5s

# Environment
Environment="AI_SIDECAR_ENABLED=1"

[Install]
WantedBy=multi-user.target
```

```bash
# Create rathena user
sudo useradd -r -s /bin/bash -d /opt/rathena-server rathena
sudo chown -R rathena:rathena /opt/rathena-server

# Enable and start services
sudo systemctl daemon-reload
sudo systemctl enable rathena-login rathena-char rathena-map
sudo systemctl start rathena-login
sleep 5
sudo systemctl start rathena-char
sleep 5
sudo systemctl start rathena-map

# Check status
sudo systemctl status rathena-login rathena-char rathena-map
```

### 5.8 Test Connection to AI Sidecar

**Step 1: Test gRPC Connection**

```bash
# Create test script
cd /opt/rathena-server
nano test_ai_connection.sh
```

```bash
#!/bin/bash
# Test AI Sidecar connection from rAthena

echo "Testing AI Sidecar connection..."
echo "Endpoint: 192.168.1.100:50051"
echo "Server ID: server-abc123def456"
echo ""

# Test 1: Network connectivity
echo "Test 1: Network connectivity"
nc -zv 192.168.1.100 50051
if [ $? -eq 0 ]; then
    echo "✓ Port 50051 is accessible"
else
    echo "✗ Cannot reach port 50051"
    exit 1
fi

# Test 2: gRPC health check (if implemented)
echo ""
echo "Test 2: gRPC service availability"
# This requires grpc_health_probe tool
# grpc_health_probe -addr=192.168.1.100:50051

# Test 3: Check map-server logs for AI connection
echo ""
echo "Test 3: Map-server AI connection status"
grep "AI Sidecar" log/map-server.log | tail -n 5

echo ""
echo "Connection test complete"
```

```bash
# Run test
chmod +x test_ai_connection.sh
./test_ai_connection.sh
```

**Step 2: Test In-Game AI NPC**

```bash
# In game:
# 1. Login with test account
# 2. Create character
# 3. Find AI-enabled NPC (ID 1001)
# 4. Talk to NPC
# 5. Say "Hello"

# Check map-server logs for AI request/response
tail -f /opt/rathena-server/log/map-server.log | grep "AI Sidecar"

# Expected log output:
# [Info]: AI Sidecar: Request - NPC 1001, Player 150000, Message: "Hello"
# [Debug]: AI Sidecar: gRPC call latency: 145ms
# [Info]: AI Sidecar: Response received - 58 characters
# [Debug]: AI Sidecar: Emotion: friendly, Relationship delta: +0.1
```

---

## 6. Configuration

### 6.1 Production Configuration Examples

#### AI Sidecar Production .env

```bash
# Production-optimized configuration
# /opt/ai-sidecar/.env

# Core Settings
ENVIRONMENT=production
DEBUG=false
LOG_LEVEL=INFO
WORKERS=48

# Database (use strong passwords!)
POSTGRES_PASSWORD=Use_32_Character_Random_Password_Here
REDIS_PASSWORD=Another_32_Character_Random_Password

# LLM Provider
DEEPSEEK_API_KEY=sk-your-production-deepseek-key

# Security
SECRET_KEY=Generate_With_Python_Secrets_Module
API_KEY_SALT=Another_Random_Secret_For_Hashing

# Performance Tuning
POSTGRES_MAX_POOL_SIZE=50
ML_BATCH_SIZE=32
ML_FP16_INFERENCE=true

# Cache Optimization
CACHE_TTL_DIALOGUE=3600
CACHE_TTL_LLM_RESPONSE=86400
ENABLE_SEMANTIC_DEDUP=true

# Monitoring
ENABLE_METRICS=true
METRICS_PORT=9090

# Multi-Tenant
ENABLE_MULTI_TENANT=true
MAX_SERVERS_SUPPORTED=10
```

#### rAthena Production Configuration

```bash
# /opt/rathena-server/conf/ai_sidecar.conf

// Production AI Sidecar Settings
ai_sidecar_enabled: yes
ai_sidecar_endpoint: 192.168.1.100:50051
ai_sidecar_tls_enabled: yes
ai_sidecar_api_key: sk-your-production-api-key-from-registration
ai_sidecar_game_server_id: server-production-001
ai_sidecar_connection_pool_size: 16
ai_sidecar_timeout_ms: 5000
ai_sidecar_fallback_to_legacy: yes
ai_sidecar_log_level: info
```

### 6.2 TLS Certificate Setup (Production)

**Step 1: Generate TLS Certificates**

```bash
# On AI Sidecar machine (Machine 2)
cd /opt/ai-sidecar

# Create certificates directory
mkdir -p certs
cd certs

# Generate CA certificate
openssl req -x509 -newkey rsa:4096 -days 365 -nodes \
  -keyout ca.key \
  -out ca.crt \
  -subj "/CN=AI Sidecar CA/O=Your Organization/C=US"

# Generate server certificate
openssl req -newkey rsa:4096 -nodes \
  -keyout server.key \
  -out server.csr \
  -subj "/CN=192.168.1.100/O=Your Organization/C=US"

# Sign server certificate with CA
openssl x509 -req -in server.csr -days 365 \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt

# Generate client certificate (for rAthena)
openssl req -newkey rsa:4096 -nodes \
  -keyout client.key \
  -out client.csr \
  -subj "/CN=rathena-client/O=Your Organization/C=US"

# Sign client certificate
openssl x509 -req -in client.csr -days 365 \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out client.crt

# Set permissions
chmod 600 *.key
chmod 644 *.crt

# Verify certificates
openssl x509 -in server.crt -text -noout | grep "Subject:"
# Expected: Subject: CN=192.168.1.100, O=Your Organization, C=US
```

**Step 2: Copy Certificates to rAthena**

```bash
# Copy CA cert and client certs to rAthena machine
scp ca.crt client.crt client.key admin@192.168.1.50:/opt/rathena-server/certs/

# On rAthena machine, set permissions
chmod 600 /opt/rathena-server/certs/client.key
chmod 644 /opt/rathena-server/certs/ca.crt
chmod 644 /opt/rathena-server/certs/client.crt
```

**Step 3: Configure gRPC TLS**

```bash
# Update AI Sidecar to use TLS (in grpc_service/server.py)
# Server credentials loaded from certs/server.crt and certs/server.key

# Update rAthena ai_sidecar.conf
ai_sidecar_tls_enabled: yes
ai_sidecar_tls_ca_cert: /opt/rathena-server/certs/ca.crt
ai_sidecar_tls_client_cert: /opt/rathena-server/certs/client.crt
ai_sidecar_tls_client_key: /opt/rathena-server/certs/client.key
```

### 6.3 Performance Tuning

#### PostgreSQL Performance Tuning

```bash
# Edit PostgreSQL configuration for production
sudo nano /etc/postgresql/17/main/postgresql.conf
```

**Additional Production Optimizations:**

```ini
# Autovacuum (critical for production)
autovacuum = on
autovacuum_max_workers = 4
autovacuum_naptime = 30s
autovacuum_vacuum_threshold = 50
autovacuum_analyze_threshold = 50
autovacuum_vacuum_scale_factor = 0.1
autovacuum_analyze_scale_factor = 0.05

# Statistics
track_activities = on
track_counts = on
track_functions = all
track_io_timing = on

# Connection Pooling (if using pgBouncer)
# default_transaction_read_only = off
# statement_timeout = 60000

# JIT Compilation (PostgreSQL 17 feature)
jit = on
jit_above_cost = 100000
```

#### DragonflyDB Performance Tuning

```bash
# Edit DragonflyDB configuration
sudo nano /etc/dragonfly/dragonfly.conf
```

**Production Optimizations:**

```ini
# Increase I/O threads for 32-core system
io-threads 16

# Enable key eviction info logging
loglevel notice

# Optimize for write-heavy workload
rdbchecksum yes
rdbcompression yes

# Client output buffer limits (prevent slow clients)
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
```

#### System-Level Tuning

```bash
# Edit /etc/sysctl.conf for production
sudo nano /etc/sysctl.conf
```

```ini
# Network performance
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1

# TCP BBR congestion control (low latency)
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# Memory
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1

# File descriptors
fs.file-max = 2097152

# NUMA balancing
kernel.numa_balancing = 1
```

```bash
# Apply settings
sudo sysctl -p

# Set CPU governor to performance
sudo apt install -y cpufrequtils
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
sudo systemctl restart cpufrequtils
```

---

## 7. Security Hardening

### 7.1 System Security

**Step 1: Configure Firewall (UFW)**

```bash
# Machine 2 (AI Sidecar)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp                                    # SSH
sudo ufw allow from 192.168.1.50 to any port 50051      # gRPC from rAthena
sudo ufw allow from 192.168.1.0/24 to any port 8000     # REST API (admin only)
sudo ufw enable

# Machine 1 (rAthena)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp                                    # SSH
sudo ufw allow 6900/tcp                                  # Login server
sudo ufw allow 6121/tcp                                  # Char server
sudo ufw allow 5121/tcp                                  # Map server
sudo ufw enable
```

**Step 2: Disable Unnecessary Services**

```bash
# List all services
systemctl list-unit-files --type=service --state=enabled

# Disable unnecessary services
sudo systemctl disable bluetooth cups avahi-daemon

# Reboot to apply changes
sudo reboot
```

**Step 3: Configure Fail2Ban**

```bash
# Install Fail2Ban
sudo apt install -y fail2ban

# Configure for SSH protection
sudo nano /etc/fail2ban/jail.local
```

```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log
```

```bash
# Start Fail2Ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 7.2 Application Security

**Step 1: Secure Sensitive Files**

```bash
# AI Sidecar
sudo chmod 600 /opt/ai-sidecar/.env
sudo chown aiworld:aiworld /opt/ai-sidecar/.env

# TLS certificates
sudo chmod 600 /opt/ai-sidecar/certs/*.key
sudo chmod 644 /opt/ai-sidecar/certs/*.crt

# rAthena
sudo chmod 600 /opt/rathena-server/conf/ai_sidecar.conf
sudo chown rathena:rathena /opt/rathena-server/conf/ai_sidecar.conf
```

**Step 2: API Key Rotation Policy**

```bash
# Create API key rotation script
sudo nano /usr/local/bin/rotate_ai_keys.sh
```

```bash
#!/bin/bash
# Rotate AI Sidecar API keys (run quarterly)

echo "API Key Rotation - $(date)"
echo "This will generate new API keys for all registered servers"
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted"
    exit 0
fi

# Call AI Sidecar admin API
curl -X POST http://localhost:8000/admin/servers/rotate-keys \
  -H "Authorization: Bearer $ADMIN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"server_id": "server-abc123def456"}'

# New key will be returned - update rAthena configuration
echo "Update rAthena conf/ai_sidecar.conf with new API key"
```

**Step 3: Database Security**

```bash
# Restrict PostgreSQL access
sudo nano /etc/postgresql/17/main/pg_hba.conf
```

```ini
# Only allow connections from localhost and AI Sidecar application
host    ai_world    ai_world    127.0.0.1/32            scram-sha-256
host    ai_world    ai_world    ::1/128                 scram-sha-256

# Reject all other connections
host    all         all         0.0.0.0/0               reject
```

**Step 4: Rate Limiting**

```bash
# Already configured in .env:
RATE_LIMIT_PER_MINUTE=1000
RATE_LIMIT_PER_HOUR=50000

# Monitor rate limiting
curl http://localhost:8000/api/v1/metrics | grep rate_limit
```

---

## 8. Monitoring & Maintenance

### 8.1 Monitoring Setup

#### Prometheus Installation

```bash
# Download Prometheus
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz
tar -xzf prometheus-2.48.0.linux-amd64.tar.gz
sudo mv prometheus-2.48.0.linux-amd64 /opt/prometheus

# Create configuration
sudo nano /opt/prometheus/prometheus.yml
```

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # AI Sidecar metrics
  - job_name: 'ai-sidecar'
    static_configs:
      - targets: ['localhost:9090']
    metrics_path: '/api/v1/metrics'

  # PostgreSQL metrics (requires postgres_exporter)
  - job_name: 'postgresql'
    static_configs:
      - targets: ['localhost:9187']

  # GPU metrics (requires nvidia_gpu_exporter)
  - job_name: 'gpu'
    static_configs:
      - targets: ['localhost:9445']

  # Node metrics (system stats)
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
```

```bash
# Create Prometheus service
sudo nano /etc/systemd/system/prometheus.service
```

```ini
[Unit]
Description=Prometheus Monitoring
After=network.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/opt/prometheus/prometheus \
  --config.file=/opt/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=90d
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# Create prometheus user and directories
sudo useradd -r -s /bin/false prometheus
sudo mkdir -p /var/lib/prometheus
sudo chown prometheus:prometheus /var/lib/prometheus

# Start Prometheus
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

# Access Prometheus UI: http://<ai-sidecar-ip>:9090
```

#### Grafana Installation

```bash
# Install Grafana
sudo apt install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo apt update
sudo apt install -y grafana

# Start Grafana
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

# Access Grafana: http://<ai-sidecar-ip>:3000
# Default credentials: admin/admin (change on first login)

# Configure Prometheus data source in Grafana
# 1. Login to Grafana
# 2. Add Data Source → Prometheus
# 3. URL: http://localhost:9090
# 4. Save & Test
```

**Step 2: Import AI Sidecar Dashboard**

```bash
# Import pre-built dashboard (if available)
# Or create custom dashboard monitoring:
# - Request rates (dialogue, quest, decision)
# - Response times (P50, P95, P99)
# - Error rates
# - GPU metrics (VRAM, utilization, temperature)
# - CPU metrics (per-core usage)
# - Database metrics (connections, queries/sec)
# - Cache metrics (hit rate, evictions)
# - Agent metrics (latency, success rate)
```

### 8.2 Health Check Endpoints

**AI Sidecar Health Checks:**

```bash
# Primary health check
curl http://localhost:8000/api/v1/health

# Detailed component health
curl http://localhost:8000/api/v1/health/detailed

# Prometheus metrics
curl http://localhost:8000/api/v1/metrics

# Service info
curl http://localhost:8000/api/v1/info
```

**rAthena Server Monitoring:**

```bash
# Check map-server status via log
tail -n 100 /opt/rathena-server/log/map-server.log

# Count active players
mysql -u rathena -p -e "SELECT COUNT(*) FROM rathena.char WHERE online=1;"

# Check AI Sidecar connection status
grep "AI Sidecar" /opt/rathena-server/log/map-server.log | tail -n 10
```

### 8.3 Log Management

#### Log Locations

```bash
# AI Sidecar logs
/var/log/ai-sidecar/app.log          # Application logs
/var/log/ai-sidecar/backup.log       # Backup logs
/var/log/postgresql/                  # Database logs
/var/log/dragonfly/dragonfly.log     # Cache logs

# rAthena logs
/opt/rathena-server/log/login-server.log
/opt/rathena-server/log/char-server.log
/opt/rathena-server/log/map-server.log
```

#### Log Rotation

```bash
# Configure logrotate for AI Sidecar
sudo nano /etc/logrotate.d/ai-sidecar
```

```
/var/log/ai-sidecar/*.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 aiworld aiworld
    sharedscripts
    postrotate
        systemctl reload ai-sidecar >/dev/null 2>&1 || true
    endscript
}
```

#### Log Monitoring

```bash
# Real-time log monitoring
sudo journalctl -u ai-sidecar -f                # Systemd logs
tail -f /var/log/ai-sidecar/app.log            # Application logs

# Search for errors in last 24 hours
sudo journalctl -u ai-sidecar -p err --since "24 hours ago"

# Monitor specific patterns
tail -f /var/log/ai-sidecar/app.log | grep -E "(ERROR|CRITICAL|Exception)"
```

### 8.4 Maintenance Procedures

#### Daily Maintenance

```bash
# Create daily maintenance script
sudo nano /usr/local/bin/daily_maintenance.sh
```

```bash
#!/bin/bash
# Daily AI Sidecar Maintenance

echo "=== Daily Maintenance - $(date) ==="

# 1. Check service status
echo "Checking services..."
systemctl is-active --quiet postgresql && echo "✓ PostgreSQL running" || echo "✗ PostgreSQL stopped"
systemctl is-active --quiet dragonfly && echo "✓ DragonflyDB running" || echo "✗ DragonflyDB stopped"
systemctl is-active --quiet ai-sidecar && echo "✓ AI Sidecar running" || echo "✗ AI Sidecar stopped"

# 2. Check resource usage
echo ""
echo "Resource usage:"
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
RAM=$(free -g | awk '/Mem:/ {printf "%.1f%%", $3/$2 * 100}')
GPU_MEM=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | awk '{print $1/1024}')
echo "CPU: ${CPU}%"
echo "RAM: ${RAM}"
echo "GPU VRAM: ${GPU_MEM}GB / 12GB"

# 3. Check disk space
echo ""
echo "Disk usage:"
df -h | grep -E "(Filesystem|/dev/nvme|/dev/sda)"

# 4. Check database connections
echo ""
echo "Database connections:"
CONNECTIONS=$(sudo -u postgres psql -d ai_world -t -c "SELECT count(*) FROM pg_stat_activity;")
echo "Active connections: $CONNECTIONS / 100"

# 5. Check for errors in logs
echo ""
echo "Recent errors:"
ERROR_COUNT=$(sudo journalctl -u ai-sidecar -p err --since "24 hours ago" | wc -l)
echo "Errors in last 24h: $ERROR_COUNT"

# 6. Cache statistics
echo ""
echo "Cache performance:"
CACHE_HITS=$(redis-cli -a "$REDIS_PASSWORD" info stats 2>/dev/null | grep keyspace_hits | cut -d: -f2)
CACHE_MISSES=$(redis-cli -a "$REDIS_PASSWORD" info stats 2>/dev/null | grep keyspace_misses | cut -d: -f2)
if [ -n "$CACHE_HITS" ] && [ -n "$CACHE_MISSES" ]; then
    TOTAL=$((CACHE_HITS + CACHE_MISSES))
    if [ $TOTAL -gt 0 ]; then
        HIT_RATE=$(echo "scale=2; $CACHE_HITS * 100 / $TOTAL" | bc)
        echo "Cache hit rate: ${HIT_RATE}%"
    fi
fi

echo ""
echo "=== Maintenance complete ==="
```

```bash
# Make executable
sudo chmod +x /usr/local/bin/daily_maintenance.sh

# Schedule via cron (runs at 6 AM daily)
(crontab -l 2>/dev/null; echo "0 6 * * * /usr/local/bin/daily_maintenance.sh >> /var/log/ai-sidecar/maintenance.log 2>&1") | crontab -

# Test script
sudo /usr/local/bin/daily_maintenance.sh
```

#### Weekly Maintenance

```bash
# Create weekly maintenance script
sudo nano /usr/local/bin/weekly_maintenance.sh
```

```bash
#!/bin/bash
# Weekly AI Sidecar Maintenance

echo "=== Weekly Maintenance - $(date) ==="

# 1. Database vacuum and analyze
echo "Running database VACUUM ANALYZE..."
sudo -u postgres psql -d ai_world -c "VACUUM ANALYZE;" && echo "✓ Vacuum complete" || echo "✗ Vacuum failed"

# 2. Update statistics
echo "Updating database statistics..."
sudo -u postgres psql -d ai_world -c "ANALYZE;" && echo "✓ Statistics updated"

# 3. Check database size and growth
echo ""
echo "Database size:"
sudo -u postgres psql -d ai_world -c "
SELECT 
    schemaname,
    pg_size_pretty(sum(pg_total_relation_size(schemaname||'.'||tablename))) as total_size
FROM pg_tables
WHERE schemaname LIKE 'server_%' OR schemaname = 'public'
GROUP BY schemaname
ORDER BY sum(pg_total_relation_size(schemaname||'.'||tablename)) DESC;"

# 4. Clean old logs
echo ""
echo "Cleaning old logs..."
find /var/log/ai-sidecar -name "*.log.*" -mtime +30 -delete
echo "✓ Old logs cleaned"

# 5. Update Python packages (cautiously)
echo ""
echo "Checking for package updates..."
source /opt/ai-sidecar/venv/bin/activate
pip list --outdated

# 6. System updates
echo ""
echo "Checking for system updates..."
sudo apt update
UPDATES=$(apt list --upgradable 2>/dev/null | wc -l)
echo "Available updates: $UPDATES"

echo ""
echo "=== Weekly maintenance complete ==="
echo "Review output and plan any necessary updates"
```

```bash
# Schedule weekly maintenance (Sundays at 3 AM)
(sudo crontab -l 2>/dev/null; echo "0 3 * * 0 /usr/local/bin/weekly_maintenance.sh >> /var/log/ai-sidecar/weekly_maintenance.log 2>&1") | sudo crontab -
```

### 8.5 Monitoring Alerts

**Critical Alerts to Configure:**

```yaml
Alert Name: High GPU Memory Usage
Condition: GPU VRAM > 11GB for 5 minutes
Action: Send notification, consider reducing batch size

Alert Name: High Error Rate
Condition: Error rate > 1% for 10 minutes
Action: Send notification, check logs

Alert Name: Database Connection Pool Exhaustion
Condition: Active connections > 90 for 5 minutes
Action: Send notification, investigate slow queries

Alert Name: API Response Time Degradation
Condition: P95 latency > 500ms for 15 minutes
Action: Send notification, check resource usage

Alert Name: Service Down
Condition: Health check fails 3 times in 1 minute
Action: Send critical alert, attempt restart

Alert Name: Disk Space Low
Condition: Disk usage > 85%
Action: Send notification, clean old backups

Alert Name: High Cache Miss Rate
Condition: Cache hit rate < 70% for 1 hour
Action: Send notification, investigate cache configuration
```

---

## 9. Troubleshooting

### 9.1 AI Sidecar Won't Start

**Symptoms:**
- Service fails to start
- Immediate crash after startup
- Error in systemd status

**Diagnosis:**

```bash
# Check service status
sudo systemctl status ai-sidecar

# Check logs
sudo journalctl -u ai-sidecar -n 100

# Check ports
sudo netstat -tulpn | grep -E "(8000|50051)"

# Check GPU
nvidia-smi
```

**Common Causes and Solutions:**

1. **Port already in use:**
   ```bash
   # Find process using port
   sudo lsof -i :8000
   # Kill if necessary
   sudo kill -9 <PID>
   ```

2. **Missing environment variables:**
   ```bash
   # Verify .env file
   cat /opt/ai-sidecar/.env | grep -E "^(POSTGRES|DEEPSEEK|SECRET)"
   # Ensure all required variables set
   ```

3. **Database connection failure:**
   ```bash
   # Test database connection
   psql -h localhost -U ai_world -d ai_world
   # If fails, check PostgreSQL status and credentials
   ```

4. **GPU not detected:**
   ```bash
   # Check NVIDIA driver
   nvidia-smi
   # If fails, reinstall driver (Section 4.2)
   ```

### 9.2 High Latency (>500ms)

**Diagnosis:**

```bash
# Check AI Sidecar metrics
curl http://localhost:8000/api/v1/metrics | grep latency

# Check resource usage
htop           # CPU
free -h        # RAM
nvidia-smi     # GPU

# Check database performance
sudo -u postgres psql -d ai_world -c "
SELECT query, mean_exec_time, calls 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC LIMIT 10;"

# Check cache hit rate
redis-cli -a "$REDIS_PASSWORD" info stats | grep keyspace
```

**Solutions:**

1. **Optimize cache:**
   ```bash
   # Increase cache size
   # Edit /etc/dragonfly/dragonfly.conf
   maxmemory 32gb
   
   # Restart DragonflyDB
   sudo systemctl restart dragonfly
   ```

2. **Optimize database:**
   ```bash
   # Run vacuum
   sudo -u postgres psql -d ai_world -c "VACUUM ANALYZE;"
   
   # Rebuild indexes
   sudo -u postgres psql -d ai_world -c "REINDEX DATABASE ai_world;"
   ```

3. **Reduce ML batch size:**
   ```bash
   # Edit .env
   ML_BATCH_SIZE=16  # Reduce from 32
   
   # Restart service
   sudo systemctl restart ai-sidecar
   ```

### 9.3 Multi-Tenant Schema Issues

**Symptoms:**
- Server A seeing Server B's data
- Wrong NPC personalities
- Cross-schema query errors

**Diagnosis:**

```sql
-- Verify schema isolation
-- Connect to database
sudo -u postgres psql -d ai_world

-- Check registered servers
SELECT server_id, schema_name, status FROM public.registered_servers;

-- Verify data in correct schemas
SELECT 'server_abc123' as schema, count(*) FROM server_abc123.npc_personalities
UNION ALL
SELECT 'server_def456' as schema, count(*) FROM server_def456.npc_personalities;

-- Check for schema leakage
-- This query should FAIL (wrong schema):
SELECT * FROM server_abc123.npc_personalities;  -- If you're authenticated as server_def456
```

**Solutions:**

1. **Verify middleware:**
   ```python
   # Check api/middleware.py ensures request.state.schema is set
   # Verify all database queries use {schema} prefix
   ```

2. **Enable query logging:**
   ```bash
   # Edit postgresql.conf
   log_statement = 'all'
   
   # Restart PostgreSQL
   sudo systemctl restart postgresql
   
   # Monitor queries
   sudo tail -f /var/log/postgresql/postgresql-17-main.log | grep "SELECT"
   ```

3. **Test schema isolation:**
   ```bash
   # Use different API keys for each server
   # Verify each server only sees its own data
   ```

### 9.4 GPU Out of Memory

**Symptoms:**
```
RuntimeError: CUDA out of memory
```

**Solutions:**

1. **Disable visual models:**
   ```bash
   # Edit .env
   LOAD_VISUAL_MODELS=false
   
   # Restart
   sudo systemctl restart ai-sidecar
   ```

2. **Enable FP16:**
   ```bash
   # Edit .env
   ML_FP16_INFERENCE=true
   
   # Restart
   sudo systemctl restart ai-sidecar
   ```

3. **Reduce batch size:**
   ```bash
   # Edit .env
   ML_BATCH_SIZE=16  # Or even 8
   
   # Restart
   sudo systemctl restart ai-sidecar
   ```

4. **Clear GPU cache:**
   ```bash
   # Restart service (clears GPU memory)
   sudo systemctl restart ai-sidecar
   ```

---

## 10. Disaster Recovery

### 10.1 Backup Strategy

**Backup Types:**

1. **Full Database Backup (Daily):**
   - Automated via cron at 2 AM
   - Retention: 30 days
   - Location: /backups/postgresql/
   - Size: ~10-50GB (depends on usage)

2. **Configuration Backup (Weekly):**
   - .env files
   - Service configurations
   - Certificates
   - Retention: 90 days

3. **ML Models (One-time):**
   - Backup ./models/ directory
   - Size: ~2.5GB
   - Only needed if models change

**Backup Verification:**

```bash
# Weekly backup test (automated)
sudo nano /usr/local/bin/test_backup.sh
```

```bash
#!/bin/bash
# Test latest backup integrity

LATEST_BACKUP=$(ls -t /backups/postgresql/*.dump | head -n1)
echo "Testing backup: $LATEST_BACKUP"

# Test restore to temporary database
sudo -u postgres createdb ai_world_backup_test
sudo -u postgres pg_restore -d ai_world_backup_test "$LATEST_BACKUP" 2>&1 | grep -E "(error|Error)"

if [ $? -eq 0 ]; then
    echo "✗ Backup test FAILED - errors found"
    exit 1
else
    echo "✓ Backup test PASSED"
fi

# Cleanup
sudo -u postgres dropdb ai_world_backup_test

exit 0
```

### 10.2 Recovery Procedures

#### Scenario 1: AI Sidecar Server Failure

**Recovery Steps:**

```bash
# 1. Verify hardware status
# - Check power supply
# - Check GPU seated properly
# - Check RAID status (if applicable)

# 2. Boot from backup OS (if disk failure)
# - Boot from USB/network
# - Mount backup disk

# 3. Restore from backup
sudo -u postgres pg_restore -d ai_world -c /backups/postgresql/ai_world_LATEST.dump

# 4. Restore configuration
cd /backups/config
tar -xzf config_LATEST.tar.gz -C /

# 5. Restart services
sudo systemctl start postgresql
sudo systemctl start dragonfly
sudo systemctl start ai-sidecar

# 6. Verify health
curl http://localhost:8000/api/v1/health

# 7. Verify rAthena reconnects
# Check map-server logs for "AI Sidecar: Connection restored"
```

**RTO (Recovery Time Objective):** 2-4 hours  
**RPO (Recovery Point Objective):** 24 hours (last daily backup)

#### Scenario 2: Database Corruption

**Recovery Steps:**

```bash
# 1. Stop AI Sidecar
sudo systemctl stop ai-sidecar

# 2. Verify corruption
sudo -u postgres psql -d ai_world -c "SELECT count(*) FROM server_abc123.npc_personalities;"
# If errors, corruption confirmed

# 3. Drop corrupted database
sudo -u postgres dropdb ai_world

# 4. Recreate database
sudo -u postgres createdb ai_world -O ai_world

# 5. Restore from latest backup
sudo -u postgres pg_restore -d ai_world /backups/postgresql/ai_world_LATEST.dump

# 6. Reinstall extensions
sudo -u postgres psql -d ai_world <<EOF
CREATE EXTENSION vector;
CREATE EXTENSION timescaledb;
CREATE EXTENSION age;
\q
EOF

# 7. Restart AI Sidecar
sudo systemctl start ai-sidecar

# 8. Verify data integrity
curl http://localhost:8000/api/v1/health
```

#### Scenario 3: Network Partition

**Symptoms:**
- rAthena cannot reach AI Sidecar
- Connection timeouts
- Fallback to legacy NPCs activated

**Recovery Steps:**

```bash
# 1. Diagnose network issue
ping 192.168.1.100                 # Test connectivity
traceroute 192.168.1.100           # Check network path
nc -zv 192.168.1.100 50051         # Test gRPC port

# 2. Check firewall rules (both machines)
sudo ufw status

# 3. Check routing
ip route show

# 4. Verify services listening
# On AI Sidecar:
sudo netstat -tulpn | grep 50051

# 5. Test with telnet
telnet 192.168.1.100 50051

# 6. Once network restored, verify reconnection
# Check map-server logs
tail -f /opt/rathena-server/log/map-server.log | grep "AI Sidecar"
```

**Expected:** Automatic reconnection within 30 seconds

### 10.3 Rollback Procedures

#### Rolling Back AI Sidecar Update

```bash
# 1. Stop current version
sudo systemctl stop ai-sidecar

# 2. Checkout previous version
cd /opt/ai-sidecar
git log --oneline -n 10
git checkout <previous-commit-hash>

# 3. Restore previous virtual environment (if dependencies changed)
rm -rf venv
python3.12 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 4. Restore previous database schema (if schema changed)
sudo -u postgres pg_restore -d ai_world /backups/postgresql/ai_world_BEFORE_UPDATE.dump

# 5. Restart service
sudo systemctl start ai-sidecar

# 6. Verify rollback successful
curl http://localhost:8000/api/v1/health
```

---

## 11. Production Checklist

### 11.1 Pre-Launch Checklist

**Infrastructure:**

- [ ] Machine 2 (AI Sidecar) deployed and tested
- [ ] Machine 1 (rAthena) deployed and tested
- [ ] Network connectivity verified (<100ms latency)
- [ ] Firewall rules configured correctly
- [ ] TLS certificates installed and valid
- [ ] Domain names configured (if applicable)

**Software:**

- [ ] PostgreSQL 17.2+ with all extensions
- [ ] DragonflyDB 1.24.0+ running
- [ ] NVIDIA driver 570+ and CUDA 12.6 installed
- [ ] Python 3.12.8 with all dependencies
- [ ] All 28 ML models downloaded and loaded
- [ ] All 21 agents initialized successfully
- [ ] rAthena built with AI client support
- [ ] gRPC communication working

**Configuration:**

- [ ] Environment variables set (.env complete)
- [ ] Database credentials configured
- [ ] API keys generated and secured
- [ ] Server registration completed
- [ ] Schema isolation verified
- [ ] Rate limiting configured
- [ ] Cache TTLs optimized

**Security:**

- [ ] SSH key-based authentication only
- [ ] Firewall rules restrictive (deny by default)
- [ ] TLS encryption enabled for gRPC
- [ ] Database passwords strong (32+ characters)
- [ ] API keys rotated quarterly (policy established)
- [ ] Sensitive files have correct permissions (600)
- [ ] Fail2Ban configured for SSH

**Monitoring:**

- [ ] Prometheus installed and configured
- [ ] Grafana dashboards created
- [ ] Health check endpoints verified
- [ ] Log rotation configured
- [ ] Alert notifications configured
- [ ] Uptime monitoring setup

**Backups:**

- [ ] Automated daily backups configured
- [ ] Backup integrity tested (restore test passed)
- [ ] Off-site backup configured (optional)
- [ ] Backup retention policy set (30 days)
- [ ] Disaster recovery plan documented

**Testing:**

- [ ] Integration tests passed (see [`INTEGRATION_TESTING.md`](rathena-ai-world-sidecar-server/INTEGRATION_TESTING.md))
- [ ] Load testing completed (100+ concurrent users)
- [ ] Failover testing successful
- [ ] Multi-tenant isolation verified
- [ ] Performance benchmarks met

### 11.2 Launch Day Checklist

**Pre-Launch (T-2 hours):**

- [ ] All systems healthy (health checks green)
- [ ] Recent backup completed successfully
- [ ] Resource usage normal (CPU <30%, RAM <40%, GPU <50%)
- [ ] No errors in logs from past 24 hours
- [ ] Monitoring dashboards accessible
- [ ] On-call team notified and ready
- [ ] Rollback plan prepared

**Launch (T-0):**

- [ ] Enable AI NPCs gradually (start with 10-20 NPCs)
- [ ] Monitor response times closely
- [ ] Watch error logs in real-time
- [ ] Monitor resource usage
- [ ] Collect player feedback

**Post-Launch (T+2 hours):**

- [ ] No critical errors reported
- [ ] Response times within targets (<150ms avg)
- [ ] Resource usage stable
- [ ] Player feedback positive
- [ ] Ready to scale to more AI NPCs

### 11.3 Scaling Plan

**Gradual AI NPC Rollout:**

```yaml
Week 1 (Launch):
  - AI NPCs: 20 (essential quest givers)
  - Monitor: 24/7 for first 3 days
  - Expected load: Low (<20% capacity)

Week 2:
  - AI NPCs: 50 (add merchants, guards)
  - Monitor: Daily checks
  - Expected load: Light (20-40% capacity)

Month 1:
  - AI NPCs: 200 (major towns)
  - Monitor: Daily checks
  - Expected load: Medium (40-60% capacity)

Month 3:
  - AI NPCs: 500 (all towns and dungeons)
  - Monitor: Weekly checks
  - Expected load: Medium-Heavy (60-80% capacity)

Month 6:
  - AI NPCs: 1000+ (full world coverage)
  - Monitor: Weekly checks
  - Expected load: Heavy (70-90% capacity)
  - Consider: Additional AI Sidecar instance if >80% consistently
```

---

## 12. Cost Summary

### 12.1 Initial Investment

**Self-Hosted Deployment:**

| Item | Cost | Notes |
|------|------|-------|
| Dell PowerEdge R730 (used) | $800-1,200 | AI Sidecar server |
| NVIDIA RTX 3060 12GB | $300-400 | ML acceleration |
| NVMe SSD 1TB | $100-150 | Fast storage |
| **Machine 2 Total** | **$1,200-1,750** | **One-time** |
| Machine 1 (rAthena) | $300-600 | Used PC or new budget build |
| Network equipment | $50-200 | Cables, switch (if needed) |
| **Grand Total** | **$1,550-2,550** | **Initial investment** |

**Cloud Deployment:**

| Item | Monthly Cost | Notes |
|------|--------------|-------|
| Machine 1 (rAthena VPS) | $20-50 | 4-8 cores, 8-16GB RAM |
| Machine 2 (GPU instance) | $200-400 | 32 cores, 192GB RAM, RTX 3060 |
| DeepSeek API | $100-250 | 21 agents, optimized |
| Backups (S3 storage) | $10-30 | 100-500GB |
| **Total Monthly** | **$330-730** | **Cloud deployment** |

### 12.2 Ongoing Costs

**Self-Hosted:**

| Item | Monthly Cost | Annual Cost |
|------|--------------|-------------|
| Electricity (420W avg) | $46 | $552 |
| Internet | $50-100 | $600-1,200 |
| DeepSeek API | $100-250 | $1,200-3,000 |
| Maintenance | $0-50 | $0-600 |
| **Total** | **$196-446** | **$2,352-5,352** |

**Total Cost of Ownership (3 years, self-hosted):**
- Initial: $1,550-2,550
- Operating: $7,056-16,056 (3 years)
- **Total 3-year TCO:** $8,606-18,606
- **Average per month:** $239-517

**Cloud Deployment:**
- Monthly: $330-730
- Annual: $3,960-8,760
- 3-year: $11,880-26,280

**Breakeven Analysis:**
- Self-hosted breaks even vs cloud after: **4-8 months**

---

## 13. Appendix

### A. Quick Reference Commands

**AI Sidecar Server:**

```bash
# Service management
sudo systemctl start ai-sidecar
sudo systemctl stop ai-sidecar
sudo systemctl restart ai-sidecar
sudo systemctl status ai-sidecar

# Logs
sudo journalctl -u ai-sidecar -f
tail -f /var/log/ai-sidecar/app.log

# Health check
curl http://localhost:8000/api/v1/health

# Database
sudo -u postgres psql -d ai_world

# GPU monitoring
nvidia-smi -l 1

# Cache
redis-cli -a "$REDIS_PASSWORD" info
```

**rAthena Server:**

```bash
# Service management
sudo systemctl start rathena-map
sudo systemctl stop rathena-map
sudo systemctl status rathena-map

# Logs
tail -f /opt/rathena-server/log/map-server.log

# Test AI connection
./test_ai_client 192.168.1.100:50051 server-production-001

# Database
mysql -u rathena -p rathena
```

### B. Emergency Contacts

```yaml
Technical Lead: name@email.com
DevOps Team: devops@email.com
Database Admin: dba@email.com
Security Team: security@email.com

On-Call Rotation:
  - Week 1: Person A
  - Week 2: Person B
  - Week 3: Person C
  - Week 4: Person D

Escalation:
  - Level 1: On-call engineer (15 min response)
  - Level 2: Technical lead (30 min response)
  - Level 3: CTO/VP Engineering (1 hour response)
```

### C. Change Management

**Production Change Process:**

1. **Change Request:** Document proposed change
2. **Impact Analysis:** Assess risks and benefits
3. **Testing:** Test in staging environment
4. **Approval:** Get sign-off from technical lead
5. **Maintenance Window:** Schedule downtime (if needed)
6. **Backup:** Create pre-change backup
7. **Execute:** Implement change
8. **Verify:** Run integration tests
9. **Monitor:** Watch metrics for 1-2 hours
10. **Document:** Update runbook with any issues

**Emergency Changes:**
- Can skip approval for critical security fixes
- Must document change within 24 hours
- Post-mortem required within 1 week

---

## Conclusion

This deployment guide provides step-by-step instructions for deploying the rAthena AI World System to production. Follow all steps in sequence, verify each component before proceeding, and maintain comprehensive documentation of your deployment.

**Deployment Summary:**

✅ **Machine 2 (AI Sidecar):** 
- 4-6 hours setup time
- All 21 agents and 28 models operational
- Multi-tenant support with schema isolation
- Production-grade security and monitoring

✅ **Machine 1 (rAthena):**
- 2-3 hours setup time
- gRPC client integrated
- Automatic fallback to legacy NPCs
- Minimal changes to existing rAthena code

✅ **Total Deployment Time:** 8-12 hours (experienced admin)

**Next Steps After Deployment:**

1. Complete integration testing (see [`INTEGRATION_TESTING.md`](rathena-ai-world-sidecar-server/INTEGRATION_TESTING.md))
2. Run load tests with expected player count
3. Monitor system for first 48 hours closely
4. Collect player feedback on AI NPCs
5. Iterate and optimize based on metrics
6. Gradually increase AI NPC count
7. Plan for scaling (additional servers or instances)

**Support Resources:**

- Integration Testing: [`rathena-ai-world-sidecar-server/INTEGRATION_TESTING.md`](rathena-ai-world-sidecar-server/INTEGRATION_TESTING.md)
- AI Sidecar README: [`rathena-ai-world-sidecar-server/README.md`](rathena-ai-world-sidecar-server/README.md)
- Architecture Documentation: [`plans/rathena-ai-sidecar-system-architecture.md`](plans/rathena-ai-sidecar-system-architecture.md)
- Quick Start Guide: [`QUICK_START.md`](QUICK_START.md)

---

**Document Version:** 1.0.0  
**Last Updated:** 2026-01-03  
**Status:** Production Deployment Procedures  
**Maintainer:** rAthena AI Team

---

**END OF DEPLOYMENT GUIDE**
