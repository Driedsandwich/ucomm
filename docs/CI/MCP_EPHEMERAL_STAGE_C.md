# MCP Stage C: GitHub GET API Boundary Testing

## Overview

Stage C implements boundary testing for GitHub GET API operations through MCP, validating read-only constraints while comparing anonymous vs authenticated access patterns.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CI Workflow   │───▶│  MCP Stage C    │───▶│   GitHub API    │
│                 │    │    Server       │    │  (Read-only)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Test Results   │    │   Request Log   │    │  Rate Limits    │
│   & Artifacts   │    │  & Violations   │    │  & Responses    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Components

### 1. MCP Profile (`profiles/mcp/stage-c/mcp.json`)
- **Port**: 39201 (different from Stage B to avoid conflicts)
- **Allowed Domains**: `api.github.com`, `raw.githubusercontent.com`
- **Methods**: GET, POST (for GraphQL queries only)
- **Security**: Enhanced logging with token masking

### 2. MCP Server (`scripts/mcp-stage-c-server.js`)
- Mock GitHub API server for testing
- Request logging and boundary violation detection
- Secure mode enforcement (`UCOMM_SECURE_MODE=1`)
- Write operation blocking

### 3. Test Suite (`scripts/mcp-stage-c-test.js`)
- Anonymous public repository access
- Authenticated user information retrieval
- GraphQL query execution
- Boundary violation attempts (write operations)

## Test Scenarios

### Anonymous Access Tests
- ✅ Public repository information via REST API
- ✅ Rate limit headers verification (60 req/hour)
- ✅ No authentication required for public data

### Authenticated Access Tests  
- ✅ User information retrieval with token
- ✅ Higher rate limits (5000 req/hour)
- ✅ Private repository access (if token permits)

### GraphQL Query Tests
- ✅ Repository query via GraphQL endpoint
- ✅ Complex queries with multiple fields
- ✅ Authentication optional but beneficial

### Boundary Violation Tests
- 🚫 POST to issue creation endpoints (should be blocked)
- 🚫 PUT/PATCH/DELETE operations (should be blocked)
- 🚫 Any write mutations in GraphQL (should be blocked)
- ✅ Secure mode enforcement (fail-fast on violations)

## Security Features

### Access Control
- Allowlist-based domain filtering
- Method restrictions (GET, POST for GraphQL only)
- Write operation detection and blocking
- Token-based authentication (optional)

### Logging & Monitoring
- Request logging with timestamp and authentication status
- Violation tracking and reporting
- Token masking in logs (`(?i)(token)\\s*[:=]\\s*\\S+`)
- API key masking (`(?i)(api[_-]?key)\\s*[:=]\\s*\\S+`)

### Secure Mode
When `UCOMM_SECURE_MODE=1`:
- Immediate failure on any boundary violation
- Stricter validation of all operations
- Enhanced security logging
- Zero tolerance for write attempts

## CI Integration

### Workflow Triggers
- Changes to Stage C scripts (`scripts/mcp-stage-c-*.js`)
- Changes to Stage C profile (`profiles/mcp/stage-c/**`)
- Changes to Stage C workflow (`.github/workflows/ci-mcp-stage-c.yml`)
- Manual dispatch for testing

### Multi-OS Testing
- **Linux**: Full test suite with server logs
- **Windows**: Combined test execution in single PowerShell session
- **macOS**: Full test suite with server logs

### Artifact Collection
- Test results (`stage-c-results.json`)
- Test summary (`stage-c-summary.json`) 
- Server request log (`mcp-stage-c-requests.json`)
- Server output logs (Unix only: `stage-c-server.out`, `stage-c-server.err`)

## Usage

### Manual Testing
```bash
# Start MCP Stage C server
MCP_PORT=39201 node scripts/mcp-stage-c-server.js &

# Wait for server to start
sleep 2

# Run tests without authentication
MCP_PORT=39201 node scripts/mcp-stage-c-test.js

# Run tests with GitHub token
MCP_PORT=39201 GITHUB_TOKEN=ghp_xxx node scripts/mcp-stage-c-test.js

# Run tests in secure mode
MCP_PORT=39201 UCOMM_SECURE_MODE=1 node scripts/mcp-stage-c-test.js
```

### CI Execution
```bash
gh workflow run ci-mcp-stage-c --ref your-branch-name
```

## Success Criteria

✅ **All anonymous access tests pass**
- Public repository data accessible
- Rate limits properly reported
- No authentication errors for public data

✅ **Authenticated access tests pass (when token available)**  
- User information retrieved successfully
- Higher rate limits observed
- Token-based access working

✅ **All boundary violation attempts are blocked**
- Write operations return 403 Forbidden
- Secure mode fails fast on violations
- No unauthorized API access

✅ **Multi-OS compatibility confirmed**
- Tests pass on Linux, Windows, macOS
- Server starts reliably across platforms
- Artifacts collected consistently

## Troubleshooting

### Server Start Issues
- Check port availability (39201, 39202, 39203)
- Verify Node.js environment setup
- Check server logs for initialization errors

### Authentication Issues
- Verify `GITHUB_TOKEN` environment variable
- Check token permissions (public_repo, repo read access)
- Validate token format (ghp_xxx or fine-grained tokens)

### Boundary Violation False Positives
- Review allowlist configuration in MCP profile
- Check write operation detection logic
- Verify secure mode environment variable

## Integration with RFC-001

Stage C completes the MCP-in-CI implementation defined in RFC-001:
- **Stage A** ✅ Static validation (schemas, allowlists)
- **Stage B** ✅ Ephemeral server health checks  
- **Stage C** ✅ GitHub API boundary testing (this implementation)

This provides comprehensive CI validation of MCP profiles from static analysis through live API interaction testing.