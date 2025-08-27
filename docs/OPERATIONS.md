# Operations Guide

This document provides operational procedures for local development and CI/CD management.

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
