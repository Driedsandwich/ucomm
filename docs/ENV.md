# Environment Configuration

This document describes environment variables and configuration requirements for the ucomm system.

## UCOMM_SECURE_MODE Specification

The UCOMM_SECURE_MODE environment variable controls the security and operational behavior of the system.

### Mode Values

#### SECURE_MODE=0 (Development/Testing)
- Purpose: Development and testing environment
- MCP HTTP Stub: ✅ ENABLED - Full HTTP stub functionality
- Endpoint Behavior: /ready and /health endpoints return success responses
- Local Testing: Ideal for local development and verification
- CI Testing: Used for development-mode smoke testing

Usage:
```bash
export UCOMM_SECURE_MODE=0
./ucomm.sh start 0
```

#### SECURE_MODE=1 (Production)  
- Purpose: Production and security-hardened environments
- MCP HTTP Stub: ❌ DISABLED - HTTP stub explicitly disabled
- Endpoint Behavior: No HTTP endpoints available
- Security Message: Displays "SECURE_MODE=1: HTTP stub disabled (production mode)"
- CI Testing: Used for production-mode smoke testing

Usage:
```bash
export UCOMM_SECURE_MODE=1
./ucomm.sh start 1
```

### CI Environment Behavior

#### Expected CI Results (Both Modes)
- Health Status: ✅ "status": "ok" - System components function normally
- MCP Endpoints: ❌ {"error":"endpoint_unreachable"} - This is expected behavior
- Overall Result: ✅ SUCCESS - CI passes with proper error handling

#### Why MCP Endpoints Fail in CI
1. No Node.js Runtime: CI environments typically don't have Node.js pre-installed
2. Network Isolation: CI runners may have restricted network access
3. Service Unavailability: HTTP stub service cannot start without proper runtime
4. Expected Behavior: This is normal and correct - the system handles these failures gracefully

### Environment Variable Precedence

The system uses the following precedence order:

1. Workflow Input: inputs.secure_mode (GitHub Actions)
2. Repository Variable: vars.UCOMM_SECURE_MODE (GitHub Settings)  
3. Environment Variable: UCOMM_SECURE_MODE (Local/Shell)
4. Default Fallback: '0' (Development mode)

GitHub Actions Example:
```yaml
env:
  UCOMM_SECURE_MODE: ${{ inputs.secure_mode || vars.UCOMM_SECURE_MODE || '0' }}
```

## CLI Commands Configuration

### Supported CLI Adapters (Phase 4)
- Gemini CLI: gemini
- Codex CLI: codex  
- Claude Code: claude

Note: Legacy names (claudecode, codex-cli, cursor[-cli]) are not supported.
All config/cli_adapters.yaml and config/topology.yaml entries must use the above 3 commands only.

### Verification Commands
```bash
# Check CLI availability
which gemini || echo "gemini not found"
which codex  || echo "codex not found"  
which claude || echo "claude not found"

# Verify SECURE_MODE setting
echo "Current SECURE_MODE: ${UCOMM_SECURE_MODE:-0}"

# Test MCP availability (local only)
curl -f http://127.0.0.1:39200/ready 2>/dev/null && echo "MCP: Available" || echo "MCP: Unavailable (expected in CI)"
```

## Configuration Files

### Core Configuration Locations
- config/topology.yaml: System topology and component definitions
- config/cli_adapters.yaml: CLI command mappings and configurations
- .github/workflows/smoke.yml: CI/CD pipeline with SECURE_MODE matrix

### Environment-Specific Behavior
- Local Development: Full functionality with MCP HTTP stub (SECURE_MODE=0 recommended)
- CI Testing: Limited functionality, graceful MCP endpoint failures (both SECURE_MODE values tested)
- Production Deployment: Security-hardened mode with disabled HTTP stub (SECURE_MODE=1)

## Troubleshooting Environment Issues

### Common Problems

1. MCP endpoints failing locally
   ```bash
   # Check SECURE_MODE setting
   echo $UCOMM_SECURE_MODE
   # Should be 0 for local development
   export UCOMM_SECURE_MODE=0
   ```

2. CI tests failing unexpectedly
   ```bash
   # MCP endpoint failures are EXPECTED in CI
   # Check that health status still reports "ok"
   # Verify Step Summary contains both Health and MCP lines
   ```

3. Wrong CLI command errors
   ```bash
   # Ensure only supported CLI commands are configured
   grep -r "claudecode\|codex-cli\|cursor" config/ && echo "Found legacy CLI names - update required"
   ```

## Security Considerations

- SECURE_MODE=1 should be used in all production deployments
- HTTP stub should never be enabled in production environments
- Environment variables containing sensitive data should not be logged
- CI artifacts are safe to inspect - they contain only diagnostic information, no secrets

## Phase 4 Enhanced Environment Variables

### MCP HTTP Stub Configuration

#### MCP_TERM_GRACE_SEC
Controls graceful shutdown timeout for MCP HTTP stub.

```bash
# Default: 5 seconds
export MCP_TERM_GRACE_SEC=5

# Extended grace period for development
export MCP_TERM_GRACE_SEC=10

# Quick shutdown for testing
export MCP_TERM_GRACE_SEC=1
```

**Usage**: When stopping MCP stub, SIGTERM is sent first, followed by waiting up to `MCP_TERM_GRACE_SEC` seconds before force-killing with SIGKILL.

#### MCP_TIMEOUT
Sets timeout for MCP endpoint health checks.

```bash
# Default: 6 seconds (compatible with CI environments)
export MCP_TIMEOUT=6

# Shorter timeout for local development
export MCP_TIMEOUT=2

# Extended timeout for slow environments
export MCP_TIMEOUT=10
```

**Usage**: Used by health checks and endpoint verification scripts when testing MCP /ready and /health endpoints.

### Health Check Configuration

Enhanced health checking now supports additional environment variables:

```bash
# Enable detailed health logging
export HEALTH_DEBUG=1

# Override health check timeout
export HEALTH_TIMEOUT=10
```

### Platform-Specific Variables

#### Platform Detection Override

```bash
# Force platform detection (for testing)
export FORCE_PLATFORM=windows  # windows | macos | ubuntu | linux

# Disable platform-specific features
export DISABLE_PLATFORM_DETECTION=1
```

### Cross-Platform Tool Configuration

#### Tool Binary Overrides

```bash
# Override specific tool paths
export YQ_BIN=/usr/local/bin/yq
export TMUX_BIN=/usr/local/bin/tmux

# Disable specific tools for testing
export DISABLE_TMUX=1
export DISABLE_YQ=1
```

## Enhanced SECURE_MODE Behavior

### Development Mode (SECURE_MODE=0)
```bash
export UCOMM_SECURE_MODE=0
```

**Enhanced Behavior (Phase 4)**:
- MCP HTTP stub enabled with exponential backoff retry
- Health checks expect MCP endpoints to be available
- Strict health judgment: `degraded` status if MCP endpoints fail
- Enhanced artifact collection with platform detection
- Comprehensive platform logging enabled

### Production Mode (SECURE_MODE=1)
```bash
export UCOMM_SECURE_MODE=1
```

**Enhanced Behavior (Phase 4)**:
- MCP HTTP stub explicitly disabled with message
- Health checks accommodate disabled MCP (expected behavior)
- Platform logging still enabled for diagnostics
- Artifact collection continues without MCP data
- Enhanced security logging and monitoring

### Environment Variable Precedence (Updated)

The enhanced system uses the following precedence order:

1. **Workflow Input**: `inputs.secure_mode` (GitHub Actions)
2. **Repository Variable**: `vars.UCOMM_SECURE_MODE` (GitHub Settings)  
3. **Environment Variable**: `UCOMM_SECURE_MODE` (Local/Shell)
4. **Default Fallback**: `'0'` (Development mode)

Additional override variables:
- `MCP_*` variables override MCP-specific behavior
- `HEALTH_*` variables override health check behavior  
- `FORCE_*` variables override automatic detection

## Configuration File Integration

### Enhanced Config File Support

Phase 4 improvements automatically detect and use:

```bash
# Primary configuration files
config/topology.yaml        # System topology and component definitions
config/cli_adapters.yaml    # CLI command mappings and configurations

# MCP configuration
profiles/mcp/default/mcp.json  # MCP server configuration with security policies
```

### Platform-Specific Configuration

```bash
# Platform detection affects:
artifacts-windows/          # Windows-specific artifacts
artifacts-macos/           # macOS-specific artifacts  
artifacts/                 # Linux/Ubuntu artifacts (default)

# Platform logging includes:
platform.log              # Comprehensive platform information
platform_detected.txt     # Simple platform name for CI
```

### Tool Availability Matrix

Enhanced platform detection automatically identifies available tools:

| Tool | Ubuntu | macOS | Windows | CI Environment |
|------|--------|--------|---------|----------------|
| tmux | ✅ | ❓ | ❌ | ❌ (expected) |
| yq | ✅ | ✅ | ✅ | ✅ (installed) |
| curl | ✅ | ✅ | ✅ | ✅ (available) |
| git | ✅ | ✅ | ✅ | ✅ (available) |
| node | ✅ | ✅ | ✅ | ❓ (varies) |

**Legend**: ✅ Available, ❌ Not available, ❓ May vary

## Debugging Environment Issues

### Enhanced Debugging Commands

```bash
# Check all environment variables
./scripts/platform-utils.sh platform-log debug.log
cat debug.log | grep "Environment Variables" -A 10

# Verify configuration
echo "SECURE_MODE: ${UCOMM_SECURE_MODE:-0}"
echo "MCP_TIMEOUT: ${MCP_TIMEOUT:-6}"  
echo "MCP_TERM_GRACE_SEC: ${MCP_TERM_GRACE_SEC:-5}"

# Test platform detection
./scripts/platform-utils.sh detect-platform
./scripts/platform-utils.sh artifact-dir

# Validate health configuration
./scripts/health.sh --json | yq '.summary.secure_mode'
./scripts/health.sh --json | yq '.summary.mcp'
```

### Common Configuration Issues

#### MCP Timeout Issues
```bash
# If MCP health checks are timing out
export MCP_TIMEOUT=10
./scripts/health.sh --json
```

#### Platform Detection Issues
```bash
# Force specific platform for testing
export FORCE_PLATFORM=windows
./scripts/platform-utils.sh detect-platform

# Check available tools
./scripts/platform-utils.sh check-command tmux
./scripts/platform-utils.sh check-command yq
```

#### CI Environment Issues
```bash
# CI environments may need specific settings
export UCOMM_SECURE_MODE=0     # For development testing
export MCP_TIMEOUT=6           # CI-compatible timeout
export DISABLE_TMUX=1          # For Windows CI
```

