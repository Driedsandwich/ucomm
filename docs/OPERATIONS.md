# UCOMM Operations Manual

**バージョン**: v0.5.x  
**最終更新**: 2025-08-31  
**対象**: Phase 4.3 完了, Phase 5+ 運用準備

## 概要

本ドキュメントは UCOMM システムの運用手順、セキュリティ設定、書き込みゲート機能について定義します。安全な運用と段階的な機能展開を実現するための運用指針を提供します。

## セキュリティ運用

### 書き込みゲート機能

#### 1. UCOMM_ENABLE_WRITES (基本制御)
```bash
# 書き込み機能を無効化 (デフォルト: 安全側)
export UCOMM_ENABLE_WRITES=0

# 書き込み機能を有効化 (開発・テスト時)
export UCOMM_ENABLE_WRITES=1
```

**動作仕様**:
- `0`: 全ての書き込み操作を拒否
- `1`: 書き込み操作を許可 (CONFIRM_WRITE の影響を受ける)
- 未設定: デフォルトで `0` (安全側に倒す)

#### 2. UCOMM_CONFIRM_WRITE (確認プロンプト)
```bash
# 書き込み前に確認プロンプトを表示
export UCOMM_CONFIRM_WRITE=1

# 確認プロンプトなし (自動実行)
export UCOMM_CONFIRM_WRITE=0
```

**動作仕様**:
- `1`: 書き込み操作前に「実行しますか？ (y/N)」を表示
- `0`: 確認なしで書き込み操作を実行
- 未設定: デフォルトで `1` (確認を求める)

#### 3. セキュアモード強制
```bash
# セキュアモード: 書き込み全面禁止
export UCOMM_SECURE_MODE=1
```

**動作仕様**:
- `1`: ENABLE_WRITES の設定に関係なく書き込み全面禁止
- `0`: 通常モード (ENABLE_WRITES の設定に従う)
- 未設定: デフォルトで `0`

### セキュリティモード組み合わせ

| SECURE_MODE | ENABLE_WRITES | CONFIRM_WRITE | 結果 |
|-------------|---------------|---------------|------|
| 1 | * | * | 🚫 全書き込み禁止 |
| 0 | 0 | * | 🚫 書き込み禁止 |
| 0 | 1 | 1 | ⚠️ 確認後に書き込み許可 |
| 0 | 1 | 0 | ✅ 書き込み自動実行 |

### 承認フロー (二段階認証)

## Local Verification Procedures

### MCP HTTP Stub Verification

Start and verify MCP HTTP stub locally:

```bash
# Start MCP HTTP stub
./scripts/mcp-launch.sh start

# Verify endpoints
curl http://127.0.0.1:39200/ready   # Should return {"status":"ok",...}
curl http://127.0.0.1:39200/health  # Should return {"status":"ok",...}

# Check status
./scripts/mcp-launch.sh status      # Should show "MCP: up"

# Stop when done
./scripts/mcp-launch.sh stop
```

### Full System Health Check

```bash
# Set development mode
export UCOMM_SECURE_MODE=0

# Clean environment
tmux kill-server 2>/dev/null || true

# Make scripts executable
chmod +x scripts/*.sh

# Launch system
./ucomm.sh start 0

# Wait for startup
sleep 3

# Run health check
scripts/health.sh --json | yq -r '.summary.status'   # Expected: "ok"

# Capture artifacts
scripts/capture.sh --once

# Check generated artifacts
ls -la artifacts/

# Cleanup
./ucomm.sh stop
```

## CI Manual Execution

### Trigger Smoke Tests

```bash
# Development mode (MCP stub enabled)
gh workflow run smoke.yml --ref main -f secure_mode=0 -f run_capture=true

# Production mode (MCP stub disabled)  
gh workflow run smoke.yml --ref main -f secure_mode=1 -f run_capture=true
```

### Monitor CI Execution

```bash
# List recent runs
gh run list --limit 5

# View specific run details
gh run view <RUN_ID>

# View job details
gh run view --job=<JOB_ID>

# Download artifacts
gh run download <RUN_ID> --name smoke-<RUN_ID>-<OS>
```

## Generated Artifacts Reference

### Core Artifacts (All Platforms)

#### health.json
System health status with component information:
```json
{
  "summary": {
    "status": "ok",               // Overall status: ok/degraded/unknown
    "mcp": {"ok": true, "latency_ms": 42, "path": "/ready"},
    "missing_bins": []
  },
  "panes": [
    {"role": "Director", "cli": "gemini", "status": "ok"},
    // ... other components
  ]
}
```

#### mcp_ready.json & mcp_health.json 
MCP HTTP endpoint verification results:
- Success (local): {"status":"ok","timestamp":"..."}
- Expected failure (CI): {"error":"endpoint_unreachable","timestamp":"..."}

#### MODE
Active operation mode:
```
MODE=HIERARCHY
```

#### topology.yaml
Current system configuration (system topology and component definitions)

### Platform-Specific Artifacts  

#### Ubuntu: tmux_*.txt
- tmux_windows.txt: Active tmux session information or "No tmux sessions found"
- tmux_director_panes.txt: Director session pane details
- tmux_team_panes.txt: Multi-agent team session panes

#### macOS/Windows
- Tmux artifacts are not generated (platform limitation in CI)

## Expected Behaviors by Mode

### SECURE_MODE=0 (Development)
- MCP: HTTP stub enabled, endpoints return success locally
- Health: All components report "ok" status
- CI Behavior: MCP endpoints fail (expected), system health remains "ok"

### SECURE_MODE=1 (Production)  
- MCP: HTTP stub disabled with message "SECURE_MODE=1: HTTP stub disabled (production mode)"
- Health: System components report "ok", MCP unavailable (expected)
- CI Behavior: Same as SECURE_MODE=0 in CI environment

## Troubleshooting

### Common Issues

1. MCP endpoints unreachable locally
   ```bash
   # Check if Node.js is available
   node --version
   # Restart MCP stub
   ./scripts/mcp-launch.sh restart
   ```

2. Health check returns "degraded"
   ```bash
   # Check detailed health output
   scripts/health.sh --json | yq '.'
   # Verify tmux sessions
   tmux list-sessions
   ```

3. CI smoke tests failing
   ```bash
   # Check recent runs
   gh run list --status failure --limit 3
   # View detailed logs
   gh run view --log <FAILED_RUN_ID>
   ```

### Performance Benchmarks
- Local MCP response: ≤5s for /health endpoint
- CI MCP timeout: ≤6s with proper error handling
- Typical CI job duration:
  - Ubuntu: 30-35s
  - macOS: 25-30s  
  - Windows: 45-55s

## Phase 4 Enhanced Operations

### Cross-Platform Support

#### Platform Detection and Utilities

Check current platform and available tools:

```bash
# Detect current platform
./scripts/platform-utils.sh detect-platform
# Returns: windows | macos | ubuntu | linux

# Get platform-specific artifact directory
./scripts/platform-utils.sh artifact-dir artifacts
# Returns: artifacts-windows | artifacts-macos | artifacts

# Check command availability (platform-aware)
./scripts/platform-utils.sh check-command tmux
./scripts/platform-utils.sh check-command yq
./scripts/platform-utils.sh check-command gemini

# Generate comprehensive platform log
./scripts/platform-utils.sh platform-log platform.log
```

#### Enhanced MCP Operations

The MCP HTTP stub now includes exponential backoff retry and graceful shutdown:

```bash
# Start with enhanced retry (3 attempts: 1s, 2s, 4s delays)
./scripts/mcp-launch.sh start

# Restart command (stop + start)
./scripts/mcp-launch.sh restart

# Stop with graceful shutdown (configurable grace period)
MCP_TERM_GRACE_SEC=10 ./scripts/mcp-launch.sh stop

# Check detailed status
./scripts/mcp-launch.sh status
# Shows: PID, HTTP status, latency information
```

**Environment Variables**:
- `MCP_TERM_GRACE_SEC`: Graceful shutdown timeout (default: 5 seconds)
- `MCP_HOST`: MCP server host (default: 127.0.0.1)
- `MCP_PORT`: MCP server port (default: 39200)
- `MCP_TIMEOUT`: Health check timeout (default: 6 seconds)

#### Strict Health Monitoring

Enhanced health checking with comprehensive validation:

```bash
# Run strict health check
./scripts/health.sh --json
# Returns: {"summary":{"status":"ok|degraded|unknown",...}}

# Development mode (expects MCP endpoints)
UCOMM_SECURE_MODE=0 ./scripts/health.sh --json

# Production mode (MCP disabled expected)
UCOMM_SECURE_MODE=1 ./scripts/health.sh --json
```

**Health Status Levels**:
- `ok`: All components healthy and functioning
- `degraded`: Some components missing/unhealthy but system functional
- `unknown`: Critical failures, system state uncertain

**Health Check Components**:
- MCP endpoint availability and latency measurement
- CLI binary availability (from config/cli_adapters.yaml)
- Tmux session and pane validation
- Platform-specific tool detection

#### Enhanced Artifact Collection

Cross-platform artifact collection with platform-specific handling:

```bash
# Run enhanced capture (platform-aware)
./scripts/capture.sh
# Automatically detects platform and creates appropriate artifacts

# Generated artifacts by platform:
# - artifacts/         (Ubuntu/Linux)
# - artifacts-macos/   (macOS)
# - artifacts-windows/ (Windows)

# Verify generated artifacts
ls -la artifacts*/
# Shows: health.json, mcp_*.json, platform.log, tmux_*.txt, topology.yaml
```

**Generated Artifacts**:
- `health.json`: Comprehensive health status with component details
- `mcp_ready.json`, `mcp_health.json`: MCP endpoint responses with timestamps
- `platform.log`: Detailed platform information (OS, tools, environment)
- `tmux_*.txt`: Tmux session info or platform-specific placeholders
- `topology.yaml`: System configuration backup
- `MODE`: Current operation mode

### Troubleshooting Enhanced Features

#### MCP Issues

```bash
# Check MCP logs (separated stdout/stderr)
tail -f logs/mcp/server-stdout.log
tail -f logs/mcp/server-stderr.log

# Verify MCP process
cat logs/mcp/server.pid
ps aux | grep $(cat logs/mcp/server.pid)

# Test MCP latency
time curl http://127.0.0.1:39200/health
# Should respond in <100ms typically
```

#### Health Check Issues

```bash
# Debug health check components
./scripts/health.sh --json | yq '.summary'
./scripts/health.sh --json | yq '.panes[] | select(.status != "ok")'

# Check missing CLI binaries
./scripts/health.sh --json | yq '.summary.missing_bins[]'

# Verify SECURE_MODE behavior
echo "Current SECURE_MODE: ${UCOMM_SECURE_MODE:-0}"
```

#### Platform Issues

```bash
# Check platform detection
./scripts/platform-utils.sh detect-platform

# Verify tool availability
for tool in tmux yq curl git node python3; do
  ./scripts/platform-utils.sh check-command $tool
done

# Generate diagnostic platform log
./scripts/platform-utils.sh platform-log diagnostic.log
cat diagnostic.log
```

### CI/CD Operations

#### Manual CI Triggering

```bash
# Trigger smoke test with specific SECURE_MODE
gh workflow run smoke.yml --ref main -f secure_mode=0 -f run_capture=true
gh workflow run smoke.yml --ref main -f secure_mode=1 -f run_capture=true

# Monitor runs
gh run list --limit 5
gh run watch <RUN_ID>

# Download platform-specific artifacts
gh run download <RUN_ID> --name smoke-<RUN_ID>-ubuntu-latest
gh run download <RUN_ID> --name smoke-<RUN_ID>-macos-latest
gh run download <RUN_ID> --name smoke-<RUN_ID>-windows-latest
```

#### CI Artifact Analysis

Each CI run generates comprehensive artifacts:

```bash
# Core artifacts (all platforms)
artifacts/health.json           # Health status with platform info
artifacts/mcp_ready.json        # MCP /ready endpoint response
artifacts/mcp_health.json       # MCP /health endpoint response
artifacts/platform.log          # Platform diagnostic information
artifacts/MODE                  # Operation mode (HIERARCHY)
artifacts/topology.yaml         # System configuration

# Platform-specific artifacts
artifacts/tmux_windows.txt       # Tmux session info or "not available"
artifacts/tmux_director_panes.txt # Director session panes
artifacts/tmux_team_panes.txt    # Team session panes
artifacts/platform_detected.txt # Detected platform name
```

### Performance Monitoring

#### MCP Performance

- **Target Response Time**: <5 seconds
- **Typical Performance**: 60-93ms (well under target)
- **Monitoring**: Latency included in health.json

#### CI Performance

- **Typical Durations**:
  - Ubuntu: 30-35 seconds
  - macOS: 25-30 seconds  
  - Windows: 45-55 seconds
- **Success Rate**: 100% (Phase 4 target achieved)

