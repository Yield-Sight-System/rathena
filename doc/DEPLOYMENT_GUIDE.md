# rathena Multi-Threading Production Deployment Guide

## Executive Summary

This guide provides step-by-step instructions for deploying multi-threading support to production rathena servers. Following this guide ensures a safe, reversible rollout with minimal risk to your live server.

**Estimated Deployment Time**: 4 weeks (test → beta → production)  
**Risk Level**: Low (with proper testing)  
**Rollback Time**: <5 minutes  
**Expected Benefit**: 2.5-4× performance improvement

---

## Table of Contents

1. [Pre-Deployment Requirements](#pre-deployment-requirements)
2. [Compilation and Build](#compilation-and-build)
3. [Deployment Phases](#deployment-phases)
4. [Configuration](#configuration)
5. [Rollback Procedures](#rollback-procedures)
6. [Monitoring and Validation](#monitoring-and-validation)
7. [Troubleshooting](#troubleshooting)
8. [Production Checklist](#production-checklist)

---

## Pre-Deployment Requirements

### System Requirements

#### Minimum Hardware
- ✅ **CPU**: 4+ physical cores (8+ recommended)
- ✅ **RAM**: 4GB minimum (8GB+ recommended)
- ✅ **Storage**: SSD recommended for database
- ✅ **OS**: Linux (Ubuntu 20.04+), Windows Server 2019+, or macOS 10.15+

#### Minimum Software
- ✅ **Compiler**: 
  - GCC 7+ (recommended: GCC 9+)
  - Clang 5+ (recommended: Clang 10+)
  - MSVC 2017+ (recommended: MSVC 2019+)
- ✅ **C++ Standard**: C++17 support required
- ✅ **Database**: MySQL 5.7+ or MariaDB 10.3+
- ✅ **Build Tools**: CMake 3.10+ or GNU Make

#### Verify System Compatibility

```bash
# Check CPU core count
lscpu | grep "^CPU(s):"
# Should show 4+

# Check GCC version
gcc --version
# Should be 7.0.0 or higher

# Check available RAM
free -h
# Should show 4GB+ available

# Check C++17 support
echo '#if __cplusplus >= 201703L
#error "C++17 supported"
#endif' | g++ -x c++ -std=c++17 -c - 2>&1 | grep "C++17 supported"
# Should output error (meaning C++17 is supported)
```

### Backup Requirements

Before proceeding, create complete backups:

✅ **Database Backup**
```bash
# Full database dump
mysqldump -u root -p --all-databases --single-transaction \
  --quick --lock-tables=false > rathena_backup_$(date +%Y%m%d).sql

# Verify backup
ls -lh rathena_backup_*.sql
```

✅ **Server Files Backup**
```bash
# Backup entire rathena directory
cd /path/to
tar -czf rathena_backup_$(date +%Y%m%d).tar.gz rathena/

# Verify backup
tar -tzf rathena_backup_*.tar.gz | head
```

✅ **Configuration Backup**
```bash
# Backup configuration files
cp -r rathena/conf rathena/conf.backup_$(date +%Y%m%d)

# Verify backup
ls -la rathena/conf.backup_*
```

### Pre-Deployment Testing Environment

**CRITICAL**: Never deploy directly to production. Set up isolated test environment:

```bash
# Clone production environment
rsync -av --exclude='logs/' production_server:/opt/rathena/ /opt/rathena_test/

# Use separate database
mysql -u root -p -e "CREATE DATABASE rathena_test;"
mysql -u root -p rathena_test < rathena_backup_latest.sql

# Update test server config to use test database
nano /opt/rathena_test/conf/inter_conf.yml
# Change database: rathena → rathena_test
```

---

## Compilation and Build

### Linux (Ubuntu/Debian)

#### Step 1: Install Dependencies
```bash
# Update package list
sudo apt update

# Install build tools
sudo apt install -y git build-essential cmake libmysqlclient-dev \
  zlib1g-dev libpcre3-dev libssl-dev

# Verify installation
gcc --version
cmake --version
```

#### Step 2: Pull Latest Code
```bash
cd /path/to/rathena

# Stash local changes
git stash

# Pull latest multi-threading code
git pull origin master

# Verify threading support
grep -r "enable_threading" conf/battle/threading.conf
```

#### Step 3: Compile with Threading Support
```bash
# Clean previous build
make clean

# Configure with optimizations
./configure --enable-lto --enable-optimization

# Compile (use all CPU cores)
make -j$(nproc)

# Verify successful compilation
ls -lh map-server char-server login-server
```

#### Step 4: Verify Threading Support
```bash
# Check for threading symbols
nm map-server | grep -i thread
# Should show ThreadPool, threading symbols

# Verify configuration file exists
ls -lh conf/battle/threading.conf

# Check binary version
./map-server --version
# Should show "Threading: Enabled" or similar
```

### Windows (Visual Studio)

#### Step 1: Open Solution
```
1. Open rAthena.sln in Visual Studio 2019+
2. Select "Release" configuration
3. Select "x64" platform
```

#### Step 2: Clean and Rebuild
```
Build → Clean Solution
Build → Rebuild Solution

Verify output in Build Output window:
"Build succeeded"
```

#### Step 3: Verify Binaries
```cmd
# Check compiled binaries
dir /B *.exe
# Should list: map-server.exe, char-server.exe, login-server.exe

# Verify threading support
map-server.exe --version
```

### macOS

#### Step 1: Install Dependencies
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install cmake mysql-client openssl zlib pcre

# Set environment variables
export PKG_CONFIG_PATH="/usr/local/opt/mysql-client/lib/pkgconfig"
```

#### Step 2: Compile
```bash
cd /path/to/rathena

# Configure
./configure

# Compile
make -j$(sysctl -n hw.ncpu)

# Verify
./map-server --version
```

---

## Deployment Phases

### Phase 1: Test Server Deployment (Week 1)

**Objective**: Validate compilation and basic functionality in isolated environment.

#### Step 1: Deploy to Test Environment
```bash
# Stop test server
cd /opt/rathena_test
./athena-start stop

# Backup current binaries
mv map-server map-server.old
mv char-server char-server.old
mv login-server login-server.old

# Copy new binaries
cp /path/to/compiled/map-server .
cp /path/to/compiled/char-server .
cp /path/to/compiled/login-server .

# Set executable permissions
chmod +x map-server char-server login-server
```

#### Step 2: Configure Conservative Settings
```bash
nano conf/battle/threading.conf
```

```conf
// Conservative test configuration
enable_threading: yes
cpu_worker_threads: 4      // Start small
db_worker_threads: 2       // Start small
enable_mob_threading: yes
enable_pathfinding_threading: yes
enable_db_async: yes
verbose_threading: yes     // Enable for debugging
task_queue_limit: 10000
```

#### Step 3: Start and Monitor
```bash
# Start server
./athena-start start

# Monitor console output
tail -f log/map-server.log

# Look for:
# "[Threading] Thread pool initialized with 4 workers"
# "[Threading] DB worker pool initialized with 2 workers"
# "[Threading] Threading enabled successfully"
```

#### Step 4: Run Automated Tests
```bash
# Test login
./test_login.sh

# Test character creation
./test_char_creation.sh

# Test basic gameplay
./test_gameplay.sh

# Test database operations
./test_database.sh
```

#### Step 5: Monitor for 7 Days
```bash
# Daily checks
- Check logs for threading errors
- Monitor CPU usage (should be distributed)
- Verify TPS remains 19-20
- Check memory usage (should be stable)
- Review player reports (if any test players)
```

**Success Criteria:**
- ✅ Server starts without errors
- ✅ Threading pools initialize successfully
- ✅ No threading-related crashes
- ✅ TPS stable at 19-20
- ✅ CPU usage distributed across cores
- ✅ No memory leaks detected

**If any criteria fail**: Stop here, debug issues, do not proceed to Phase 2.

---

### Phase 2: Beta Server Deployment (Week 2-3)

**Objective**: Stress test with real players in controlled environment.

#### Step 1: Announce Beta Testing
```
Subject: Beta Test - Performance Upgrade

We're testing a major performance upgrade that will:
- Improve server responsiveness
- Reduce lag during WoE
- Eliminate database lag spikes

Beta server details:
- Address: beta.yourserver.com:6121
- Duration: 2 weeks
- Rewards: Exclusive beta tester title

Expected issues: Minor bugs possible
How to report: #beta-feedback Discord channel
```

#### Step 2: Deploy to Beta Server
```bash
# Same process as Phase 1, but on beta server
cd /opt/rathena_beta
./athena-start stop

# Backup
tar -czf binaries_backup_$(date +%Y%m%d).tar.gz *-server

# Deploy new binaries
cp /path/to/compiled/*-server .
chmod +x *-server

# Update configuration
nano conf/battle/threading.conf
```

#### Step 3: Increase Worker Counts
```conf
// Beta configuration (more aggressive)
enable_threading: yes
cpu_worker_threads: 8      // Increased from 4
db_worker_threads: 4       // Increased from 2
enable_mob_threading: yes
enable_pathfinding_threading: yes
enable_db_async: yes
verbose_threading: no      // Reduce log spam
task_queue_limit: 10000
```

#### Step 4: Stress Testing Events

**Week 2-3 Testing Schedule:**

**Day 1-3: Normal Gameplay**
```
- Monitor regular gameplay
- Collect baseline performance metrics
- Gather player feedback
```

**Day 4-5: Mob Spawn Event**
```bash
# Spawn mass mobs for stress test
@monster prontera Poring 500
@monster geffen Lunatic 500

# Monitor server performance
- TPS should remain 18-20
- CPU usage balanced across cores
- No lag reports from players
```

**Day 6-7: High Player Count Test**
```
- Advertise special event (2x EXP weekend)
- Target: 200+ concurrent players
- Monitor database performance
- Track autosave lag (should be eliminated)
```

**Day 8-10: WoE Simulation**
```bash
# Schedule test WoE event
# Target: 150+ players in castle siege

# Monitor during event:
- TPS during combat
- Skill cast responsiveness
- Player lag reports
- CPU/memory usage
```

**Day 11-14: Marathon Testing**
```
- Let server run continuously
- Monitor for memory leaks
- Check long-term stability
- Collect comprehensive logs
```

#### Step 5: Collect Metrics

```bash
# Generate performance report
./scripts/generate_performance_report.sh

# Metrics to collect:
- Average TPS over 2 weeks
- CPU utilization patterns
- Memory usage trends
- Database query performance
- Player feedback summary
- Crash count (should be 0)
- Threading error count (should be 0)
```

**Success Criteria:**
- ✅ No crashes during 2-week period
- ✅ Average TPS: 18-20
- ✅ Positive player feedback (>80%)
- ✅ No threading-related errors
- ✅ Memory usage stable (<5% increase)
- ✅ WoE performance improved vs. old version

**If any criteria fail**: Extend beta testing, debug issues, do not proceed to Phase 3.

---

### Phase 3: Production Rollout (Week 4)

**Objective**: Deploy to live production server with minimal downtime.

#### Pre-Rollout Announcement
```
Subject: Server Maintenance - Performance Upgrade

Date: [Schedule maintenance during low-traffic time]
Duration: 30 minutes
Downtime: 10 minutes

What's changing:
- Major performance upgrade (multi-threading)
- 2-4× faster mob AI processing
- Elimination of database lag spikes
- Better WoE performance

What to expect:
- Smoother gameplay
- No more lag during autosave
- Better performance during events

Tested for 3 weeks in beta environment.
Rollback plan ready if issues occur.
```

#### Deployment Procedure

**T-24 hours: Final Preparations**
```bash
# Complete database backup
mysqldump -u root -p rathena > rathena_pre_threading_$(date +%Y%m%d).sql

# Backup server files
tar -czf rathena_pre_threading_$(date +%Y%m%d).tar.gz /opt/rathena/

# Test database restore (on test server)
mysql -u root -p rathena_test < rathena_pre_threading_$(date +%Y%m%d).sql

# Verify backup integrity
echo "Backup verified: $(date)" >> deployment_log.txt
```

**T-1 hour: Pre-Maintenance Notifications**
```
Broadcast in-game:
@kami [Maintenance in 1 hour] Server will restart for performance upgrade. Please save and log out safely.

Repeat at:
- T-30 minutes
- T-15 minutes
- T-5 minutes
```

**T-0: Begin Maintenance**

```bash
# 1. Announce maintenance start
@kami [MAINTENANCE STARTING] Logging out all players in 1 minute...

# 2. Wait 1 minute
sleep 60

# 3. Kick all players
@kickall

# 4. Stop server gracefully
cd /opt/rathena
./athena-start stop

# 5. Wait for clean shutdown (max 30 seconds)
sleep 10

# 6. Verify processes stopped
ps aux | grep -E "(map|char|login)-server"
# Should return no results

# 7. Backup current binaries
mkdir -p backups/$(date +%Y%m%d)
cp map-server char-server login-server backups/$(date +%Y%m%d)/

# 8. Deploy new binaries
cp /path/to/compiled/map-server .
cp /path/to/compiled/char-server .
cp /path/to/compiled/login-server .
chmod +x *-server

# 9. Verify threading configuration
cat conf/battle/threading.conf

# 10. Start server
./athena-start start

# 11. Monitor startup logs
tail -f log/map-server.log
```

**T+2 minutes: Verify Startup**

```bash
# Check processes running
ps aux | grep -E "(map|char|login)-server"

# Check logs for threading messages
grep -i "thread pool initialized" log/map-server.log
grep -i "threading enabled" log/map-server.log

# Verify no errors
grep -i "error\|warning" log/map-server.log | grep -i thread

# Test login (automated)
./scripts/test_login.sh
```

**T+5 minutes: Open Server**
```
Broadcast:
@kami [MAINTENANCE COMPLETE] Performance upgrade successful! Server is now open. Enjoy improved performance!

# Monitor for first 30 minutes
- Watch log files continuously
- Check Discord/forums for player reports
- Monitor CPU usage
- Verify TPS stable
```

#### Post-Deployment Monitoring

**First Hour:**
```bash
# Monitor logs in real-time
tail -f log/map-server.log log/char-server.log

# Check system resources every 5 minutes
watch -n 300 'ps aux | grep server; free -h; uptime'

# Monitor player count
watch -n 60 './scripts/get_online_count.sh'
```

**First 24 Hours:**
```
- Check logs every hour
- Monitor Discord/forums for player feedback
- Track crash reports (should be 0)
- Verify TPS remains 19-20
- Check CPU utilization (should be distributed)
- Review threading statistics (if verbose enabled)
```

**First Week:**
```
Daily tasks:
- Review previous 24h logs
- Check for threading warnings
- Monitor system resources
- Collect player feedback
- Compare performance vs. pre-threading baseline
```

**Success Criteria:**
- ✅ Server starts successfully
- ✅ No crashes in first 24 hours
- ✅ TPS stable at 19-20
- ✅ Positive player feedback
- ✅ No rollback required
- ✅ Performance improvements measurable

---

## Configuration

### Recommended Settings by Server Size

#### Small Server (50-200 players)

```conf
# conf/battle/threading.conf
enable_threading: yes
cpu_worker_threads: 4
db_worker_threads: 2
enable_mob_threading: yes
enable_pathfinding_threading: yes
enable_db_async: yes
task_queue_limit: 10000
verbose_threading: no
```

**Expected Performance:**
- TPS: 19-20
- CPU Usage: 30-40%
- Database Latency: <5ms

---

#### Medium Server (200-800 players)

```conf
# conf/battle/threading.conf
enable_threading: yes
cpu_worker_threads: 8
db_worker_threads: 4
enable_mob_threading: yes
enable_pathfinding_threading: yes
enable_db_async: yes
task_queue_limit: 10000
verbose_threading: no
```

**Expected Performance:**
- TPS: 18-20
- CPU Usage: 50-65%
- Database Latency: <5ms

---

#### Large Server (800-2000 players)

```conf
# conf/battle/threading.conf
enable_threading: yes
cpu_worker_threads: 0  # Auto-detect (recommended)
db_worker_threads: 8
enable_mob_threading: yes
enable_pathfinding_threading: yes
enable_db_async: yes
task_queue_limit: 20000
verbose_threading: no
```

**Expected Performance:**
- TPS: 18-20
- CPU Usage: 60-75%
- Database Latency: <10ms

---

#### Enterprise Server (2000+ players, dedicated hardware)

```conf
# conf/battle/threading.conf
enable_threading: yes
cpu_worker_threads: 0  # Auto-detect (16-32 cores)
db_worker_threads: 16
enable_mob_threading: yes
enable_pathfinding_threading: yes
enable_db_async: yes
task_queue_limit: 50000
verbose_threading: no
```

**Additional Recommendations:**
- Use dedicated database server
- RAID 10 SSD storage
- 10GbE network
- Consider NUMA optimizations

---

## Rollback Procedures

### Emergency Rollback (Issues Detected)

**When to Rollback:**
- Server crashes within first hour
- TPS drops below 15
- Widespread player complaints
- Threading errors in logs
- Database corruption detected

#### Quick Rollback (5 minutes)

```bash
# 1. Stop server immediately
cd /opt/rathena
./athena-start stop

# 2. Disable threading
nano conf/battle/threading.conf
# Set: enable_threading: no

# 3. Restore old binaries (optional, for critical issues)
cp backups/$(date +%Y%m%d)/map-server .
cp backups/$(date +%Y%m%d)/char-server .
cp backups/$(date +%Y%m%d)/login-server .

# 4. Restart server
./athena-start start

# 5. Verify working
tail -f log/map-server.log

# 6. Announce rollback
@kami [ROLLBACK COMPLETE] Server restored to previous version. Investigating issues.
```

#### Full Rollback (Database Restore)

**Only if database corruption suspected:**

```bash
# 1. Stop server
./athena-start stop

# 2. Backup potentially corrupted database
mysqldump -u root -p rathena > rathena_corrupted_$(date +%Y%m%d_%H%M).sql

# 3. Restore from pre-deployment backup
mysql -u root -p rathena < rathena_pre_threading_$(date +%Y%m%d).sql

# 4. Restore old binaries
cp backups/$(date +%Y%m%d)/*-server .

# 5. Verify configuration
cat conf/battle/threading.conf
# Should have enable_threading: no

# 6. Start server
./athena-start start

# 7. Verify integrity
./scripts/verify_database_integrity.sh
```

---

## Monitoring and Validation

### Real-Time Monitoring

#### Console Monitoring
```bash
# Terminal 1: Map server logs
tail -f log/map-server.log

# Terminal 2: System resources
watch -n 5 'uptime; ps aux | grep -E "(map|char|login)-server"; free -h'

# Terminal 3: Network connections
watch -n 10 'netstat -an | grep :6121 | wc -l'
```

#### CPU Monitoring
```bash
# Check CPU distribution
top -H -p $(pgrep map-server)

# Expected: Multiple threads with balanced CPU usage
```

#### Memory Monitoring
```bash
# Check for memory leaks
while true; do
  ps aux | grep map-server | awk '{print $6, $11}'
  sleep 300  # Check every 5 minutes
done
```

### Performance Metrics

#### TPS Monitoring
```bash
# Enable TPS logging in map-server
# Add to map-server.cpp:

// Log TPS every minute
if (gettick() % 60000 == 0) {
    ShowInfo("Current TPS: %d\n", current_tps);
}
```

#### Database Query Monitoring
```sql
-- Enable MySQL slow query log
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 0.1;  -- 100ms threshold

-- Monitor slow queries
tail -f /var/log/mysql/slow-query.log
```

#### Threading Statistics

With `verbose_threading: yes`:
```bash
grep -i "thread" log/map-server.log | tail -20

# Example output:
# [Threading] Processing 847 mobs using 8 worker threads
# [Threading] Completed processing 847 mobs
# [Async DB] Submitted query: INSERT INTO picklog...
# [Async DB] Query completed in 23ms (affected: 1 rows)
```

---

## Troubleshooting

### Common Issues

#### Issue 1: Server Won't Start After Upgrade

**Symptoms:**
- Server crashes immediately on startup
- "Threading initialization failed" error

**Diagnosis:**
```bash
# Check console output
./map-server

# Check system limits
ulimit -a

# Check library dependencies
ldd map-server
```

**Solution:**
```bash
# Increase thread limit if too low
ulimit -u 4096

# Disable threading temporarily
nano conf/battle/threading.conf
# Set: enable_threading: no

# Restart and investigate
./athena-start start
```

---

#### Issue 2: High CPU Usage on Single Core

**Symptoms:**
- One core at 100%, others idle
- TPS drops
- Threading appears not working

**Diagnosis:**
```bash
# Verify threading is enabled
grep "enable_threading" conf/battle/threading.conf

# Check logs for initialization
grep "Thread pool initialized" log/map-server.log

# Check if binary has threading support
nm map-server | grep ThreadPool
```

**Solution:**
```bash
# Verify configuration loaded
cat conf/battle/threading.conf

# Ensure battle_athena.conf imports threading.conf
grep "threading.conf" conf/battle_athena.conf

# Rebuild if necessary
make clean && make -j$(nproc)
```

---

#### Issue 3: Race Condition Warnings

**Symptoms:**
- "[Threading] Warning: Race condition detected" in logs
- Occasional crashes or data inconsistencies

**Diagnosis:**
```bash
# Collect detailed logs
nano conf/battle/threading.conf
# Set: verbose_threading: yes

# Restart and reproduce
./athena-start restart

# Analyze logs
grep -A 10 "Race condition" log/map-server.log
```

**Solution:**
```bash
# Disable specific feature temporarily
nano conf/battle/threading.conf
# Try: enable_mob_threading: no
# Or: enable_db_async: no

# Restart and test
./athena-start restart

# Report issue to developers with logs
```

---

#### Issue 4: Database Corruption

**Symptoms:**
- Character data inconsistent
- Item duplication
- Database errors in logs

**Diagnosis:**
```bash
# Check for database errors
grep -i "database error" log/map-server.log

# Check MySQL error log
sudo tail -f /var/log/mysql/error.log

# Run database integrity check
mysqlcheck -u root -p --check --all-databases
```

**Solution:**
```bash
# IMMEDIATE: Stop server
./athena-start stop

# Disable async database
nano conf/battle/threading.conf
# Set: enable_db_async: no

# Restore from backup
mysql -u root -p rathena < rathena_backup_latest.sql

# Restart with threading disabled
# Set: enable_threading: no
./athena-start start

# Report issue with detailed logs
```

---

#### Issue 5: Performance Regression

**Symptoms:**
- Server slower after threading enabled
- TPS lower than before
- Player reports increased lag

**Diagnosis:**
```bash
# Check CPU usage pattern
top -H -p $(pgrep map-server)

# Check for lock contention
# Enable verbose threading
nano conf/battle/threading.conf
# Set: verbose_threading: yes

# Analyze thread pool stats
grep "Thread pool" log/map-server.log
```

**Solution:**
```conf
# Reduce worker count (may be too high)
cpu_worker_threads: 4  # Instead of 8 or auto

# Disable specific features
enable_mob_threading: no  # Test each feature
enable_db_async: no

# Monitor and compare performance
```

---

### Debug Mode

#### Enable Maximum Debugging

```conf
# conf/battle/threading.conf
enable_threading: yes
verbose_threading: yes
task_queue_limit: 10000

# Also enable in src/config/core.hpp (requires recompile)
#define DEBUG_THREADING 1
#define SHOW_DEBUG_MSG 1
```

#### Collect Debug Information

```bash
# Comprehensive log collection
tar -czf debug_logs_$(date +%Y%m%d_%H%M).tar.gz \
  log/*.log \
  conf/battle/threading.conf \
  conf/battle_athena.conf

# System information
uname -a > sysinfo.txt
lscpu >> sysinfo.txt
free -h >> sysinfo.txt
ps aux | grep server >> sysinfo.txt

# Send to developers for analysis
```

---

## Production Checklist

### Pre-Deployment Checklist

Before deploying to production, verify all items:

#### Infrastructure
- [ ] Test environment validated (7+ days)
- [ ] Beta testing completed (2+ weeks)
- [ ] Complete database backup created
- [ ] Complete server files backup created
- [ ] Backup restoration tested successfully
- [ ] Rollback procedure documented
- [ ] Emergency contact list prepared

#### Technical
- [ ] Binaries compiled with threading support
- [ ] Configuration file reviewed and tested
- [ ] System meets minimum requirements (4+ cores, 8GB RAM)
- [ ] Database server optimized
- [ ] Compiler version verified (GCC 7+)
- [ ] Threading support verified in binary

#### Team Readiness
- [ ] Team trained on troubleshooting procedures
- [ ] Monitoring tools configured
- [ ] Communication channels prepared (Discord, forums)
- [ ] Maintenance window scheduled
- [ ] Player announcement prepared
- [ ] 24-hour support coverage arranged

#### Documentation
- [ ] Deployment runbook reviewed
- [ ] Rollback procedure understood
- [ ] Troubleshooting guide accessible
- [ ] Performance baseline documented
- [ ] Success criteria defined

### Post-Deployment Checklist

After deployment, verify all items:

#### Immediate (0-30 minutes)
- [ ] Server started successfully
- [ ] Threading initialized correctly
- [ ] No errors in startup logs
- [ ] Players can login
- [ ] TPS stable at 19-20
- [ ] CPU usage distributed across cores

#### First Hour
- [ ] No crashes occurred
- [ ] Player feedback monitored
- [ ] System resources normal
- [ ] Database queries functioning
- [ ] No threading warnings in logs

#### First Day
- [ ] Performance metrics collected
- [ ] Player satisfaction positive (>80%)
- [ ] No rollback required
- [ ] Long-term stability confirmed
- [ ] Memory usage stable

#### First Week
- [ ] Daily log reviews completed
- [ ] Performance improvements measurable
- [ ] No threading-related issues
- [ ] Team trained on new system
- [ ] Documentation updated with production notes

---

## Maintenance Procedures

### Regular Maintenance

#### Daily
```bash
# Check logs for threading issues
grep -i "thread.*error\|thread.*warning" log/map-server.log

# Verify TPS stable
tail -100 log/map-server.log | grep TPS

# Monitor system resources
ps aux | grep server
free -h
```

#### Weekly
```bash
# Analyze performance trends
./scripts/weekly_performance_report.sh

# Review player feedback
# Check Discord, forums, in-game reports

# Check for memory leaks
ps aux | grep map-server | awk '{print $5}' >> memory_usage.log
```

#### Monthly
```bash
# Comprehensive performance analysis
./scripts/monthly_performance_analysis.sh

# Update documentation with lessons learned

# Review and optimize thread counts if needed

# Consider updates to threading configuration
```

### Configuration Tuning

#### When to Increase Worker Threads
- CPU usage <50% across all cores
- TPS consistently <19
- Player count increased significantly
- Mob-heavy maps showing lag

#### When to Decrease Worker Threads
- High context switching overhead
- Memory usage too high
- Lock contention detected
- Performance regression observed

#### Tuning Process
```bash
# 1. Baseline metrics
Record: Current TPS, CPU usage, memory

# 2. Modify configuration
nano conf/battle/threading.conf
# Adjust cpu_worker_threads: X

# 3. Restart
./athena-start restart

# 4. Monitor for 24 hours
Collect: TPS, CPU usage, memory, player feedback

# 5. Compare and decide
If improved: Keep new setting
If worse: Revert to previous setting
```

---

## Success Metrics

### Performance Targets

✅ **Primary Metrics:**
- TPS: 19-20 (consistent)
- CPU Usage: <70% peak
- Database Latency: <50ms
- Zero crashes in first week
- Zero data corruption incidents

✅ **Secondary Metrics:**
- Player satisfaction: >80%
- Lag complaints: <5 per week
- WoE performance: 18+ TPS with 200 players
- Autosave impact: Not noticeable

### Measuring Success

```bash
# TPS measurement
grep "Current TPS" log/map-server.log | awk '{sum+=$4; count++} END {print sum/count}'
# Target: >19

# CPU distribution
top -b -n 1 | grep map-server
# Target: Load distributed across multiple cores

# Database latency
# Check MySQL slow query log
wc -l /var/log/mysql/slow-query.log
# Target: <10 queries per hour

# Player feedback
# Survey results: Gameplay smoother? Yes/No
# Target: >80% Yes
```

---

## Support and Resources

### Getting Help

#### Community Resources
- **GitHub Issues**: https://github.com/rathena/rathena/issues
- **Discord**: rathena community server (#threading-support)
- **Forums**: https://rathena.org/forums/

#### Reporting Issues

When reporting threading issues, include:
```bash
1. Server configuration (threading.conf)
2. Hardware specifications
3. Console output with verbose_threading: yes
4. Steps to reproduce
5. Debug logs (last 100 lines)
6. Player count at time of issue
7. System resource usage

# Generate bug report
./scripts/generate_bug_report.sh > bug_report.txt
```

#### Documentation
- [`threading.md`](threading.md) - Technical documentation
- [`PERFORMANCE_TESTING.md`](PERFORMANCE_TESTING.md) - Benchmark results
- [`MULTITHREADING_SUMMARY.md`](MULTITHREADING_SUMMARY.md) - Executive summary

---

## Conclusion

Multi-threading deployment is a **significant upgrade** that requires careful planning and execution. Following this guide ensures:

✅ **Safe Deployment**: Phased rollout minimizes risk  
✅ **Reversibility**: Rollback procedures ready if needed  
✅ **Performance Gains**: 2.5-4× improvement in key operations  
✅ **Production Stability**: Tested and validated before production  

**Final Recommendation**: Complete all three phases (Test → Beta → Production) before deploying to live server. The 4-week timeline ensures a stable, well-tested deployment.

---

**Document Version**: 1.0  
**Last Updated**: January 2026  
**Status**: Production-Ready  
**Maintenance**: Update after each major deployment
