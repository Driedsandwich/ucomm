# ucomm - Multi-agent Communication Framework

![Smoke Tests](https://github.com/Driedsandwich/ucomm/workflows/smoke/badge.svg)
[![Link Check](https://github.com/Driedsandwich/ucomm/actions/workflows/link-check.yml/badge.svg)](https://github.com/Driedsandwich/ucomm/actions/workflows/link-check.yml)

A unified communication framework supporting multi-agent interactions with health monitoring and MCP (Model Context Protocol) integration.

## Features

- Multi-agent communication with Director/Manager/Specialist roles
- Health monitoring with JSON output
- MCP HTTP endpoint integration for external services
- CI/CD integration with comprehensive smoke testing

## CI/CD Smoke Testing

The project includes automated smoke testing via GitHub Actions that validates both system health and MCP integration across multiple operating systems (Ubuntu/macOS/Windows) with full SECURE_MODE (0/1) support.

### Smoke Test Expectations

The CI Step Summary **MUST** always contain both of the following lines (regression test requirement):

1. **Health status line**: `- Health: **{status}**`
   - Expected values: `ok`, `degraded`, or `unknown`
   - Indicates overall system health including tmux sessions and log generation

2. **MCP status line**: `- MCP: **{status}** (/ready: {ready}, /health: {health})`
   - Expected status: `up` (local with Node.js) or `down` (CI environment)
   - Shows MCP HTTP endpoint verification results

### SECURE_MODE Behavior

- **SECURE_MODE=0** (Development/Testing): MCP HTTP stub is enabled for testing
- **SECURE_MODE=1** (Production): MCP HTTP stub is disabled with message "SECURE_MODE=1: HTTP stub disabled (production mode)"

Both modes should result in successful CI runs with proper artifact generation.

### Generated Artifacts

Each CI run produces the following artifacts in the `artifacts/` directory:

- `health.json`: System health status with tmux and component information
- `mcp_ready.json`: MCP /ready endpoint response or error information
- `mcp_health.json`: MCP /health endpoint response or error information
- `tmux_*.txt`: Tmux session and pane information
- `topology.yaml`: Current system configuration
- `MODE`: Active operation mode

### Running Smoke Tests

```bash
# Trigger smoke test with development mode (MCP stub enabled)
gh workflow run smoke.yml --ref main -f secure_mode=0 -f run_capture=true

# Trigger smoke test with production mode (MCP stub disabled)
gh workflow run smoke.yml --ref main -f secure_mode=1 -f run_capture=true
```

### Local Development

Start MCP HTTP stub locally:

```bash
./scripts/mcp-launch.sh start
curl http://127.0.0.1:39200/ready   # Should return {"status":"ok",...}
curl http://127.0.0.1:39200/health  # Should return {"status":"ok",...}
./scripts/mcp-launch.sh status      # Should show "MCP: up"
```

## Architecture

- **Director**: Main coordination agent
- **Manager**: Task management and delegation
- **Specialist1-3**: Specialized task execution agents
- **MCP Integration**: External service communication via HTTP endpoints

## Contributing

Ensure all changes maintain the CI Step Summary contract:
- Health status reporting must remain functional
- MCP integration must show appropriate status (up/down)
- Both SECURE_MODE=0 and SECURE_MODE=1 must result in successful CI runs
