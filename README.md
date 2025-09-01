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

## SSOT Documentation (docs/)

Single Source of Truth documentation for comprehensive project understanding:

### Quick Intake
`git clone` → read `docs/PHASE_MAP.txt` → run Link Check (`Actions > link-check.yml`) → confirm success → review Issues #21/#22.

### Core Documentation
- [PHASE_MAP.txt](docs/PHASE_MAP.txt) - 7th generation project roadmap with Phase 4.3 completion status
- [SPEC_ucomm_v0.5.x.md](docs/SPEC_ucomm_v0.5.x.md) - System architecture and component specifications
- [REQUIREMENTS_v0.5.x.md](docs/REQUIREMENTS_v0.5.x.md) - Traceability matrix with DOD and test methods

### Operational Documentation  
- [OPERATIONS.md](docs/OPERATIONS.md) - Security operations manual with write gates and approval flows
- [ENV.md](docs/ENV.md) - Environment variables with priority cascade and security settings
- [MCP_PROFILE.md](docs/MCP_PROFILE.md) - MCP configuration profiles with minimum privilege principles

### Development Documentation
- [CI/SMOKE.md](docs/CI/SMOKE.md) - CI design documentation with triage system integration
- [DECISIONS_LOG.md](docs/DECISIONS_LOG.md) - Phase 4.3 completion decisions and workspace migration approval

### Reports and Analysis
- [Reports Index](docs/reports/README.md) - Latest triage links and automated CI failure analysis

## Contributing

Ensure all changes maintain the CI Step Summary contract:
- Health status reporting must remain functional
- MCP integration must show appropriate status (up/down)
- Both SECURE_MODE=0 and SECURE_MODE=1 must result in successful CI runs
