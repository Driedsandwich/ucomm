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
