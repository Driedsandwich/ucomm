# MCP Stage C Design: GitHub GET API Boundary Testing

## Overview
Stage C implements boundary testing for GitHub GET API operations through MCP, comparing anonymous vs authenticated access patterns while maintaining read-only constraints.

## Requirements
- Test GitHub GET APIs through MCP git/fetch tools
- Compare anonymous vs token-authenticated behavior 
- Validate read-only boundaries (no write operations)
- Integrate with existing ci-mcp-ephemeral workflow
- Support SECURE_MODE=1 for fail-fast on violations

## Test Scenarios

### Scenario 1: Public Repository Access
- **Endpoint**: GitHub API v4 (GraphQL) - repository query
- **Anonymous**: Should succeed for public repos
- **Authenticated**: Should succeed with higher rate limits
- **Boundary**: Verify no write mutations attempted

### Scenario 2: Rate Limit Comparison  
- **Anonymous**: ~60 requests/hour
- **Authenticated**: ~5000 requests/hour  
- **Test**: Make multiple requests and compare rate limit headers

### Scenario 3: Private Repository Access
- **Anonymous**: Should return 404/403
- **Authenticated**: Should succeed if token has access
- **Boundary**: Verify no unauthorized access attempts

## Implementation Plan

### Phase 1: MCP Profile Extension
Create `profiles/mcp/stage-c/mcp.json` with:
- GitHub API v4 GraphQL endpoint access
- GitHub REST API v3 read-only endpoints
- Enhanced logging for API call tracking

### Phase 2: Test Script Development
Create `scripts/mcp-stage-c-test.js`:
- GraphQL query execution via MCP
- Rate limit header parsing
- Response comparison logic
- Boundary violation detection

### Phase 3: CI Integration
Extend `.github/workflows/ci-mcp-ephemeral.yml`:
- Add Stage C test step
- Environment variable management (GITHUB_TOKEN optional)
- Artifact collection for API responses

### Phase 4: Boundary Validation
Implement security checks:
- Verify only GET/POST (GraphQL query) methods used
- Validate no mutations in GraphQL queries
- Check allowlist compliance for GitHub domains

## Success Criteria
1. Anonymous access works for public API calls
2. Authenticated access shows increased rate limits
3. Private repo access fails appropriately for anonymous
4. No boundary violations detected in secure mode
5. All tests pass in CI environment

## Security Constraints
- GitHub token permissions: read-only (repo, public_repo scopes only)
- No write operations (mutations, POST to write endpoints)
- API responses logged with sensitive data masked
- Rate limit respect to avoid GitHub API abuse

## Files to Create/Modify
1. `docs/CI/MCP_STAGE_C_DESIGN.md` (this file)
2. `profiles/mcp/stage-c/mcp.json` (new profile)
3. `scripts/mcp-stage-c-test.js` (test implementation)
4. `.github/workflows/ci-mcp-ephemeral.yml` (CI integration)
5. `docs/CI/MCP_EPHEMERAL_STAGE_C.md` (documentation)