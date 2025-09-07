# Stage C Extended: GitHub API Boundary Test

- Token: built-in `GITHUB_TOKEN` (least privileges, repo-scoped)  
- Allowed: safe GET calls (e.g., `/repos/:owner/:repo`)
- Denied: state-changing calls (POST/DELETE/PUT/PATCH) -> expect 403/404
- CI: `.github/workflows/ci-mcp-api-boundary-extended.yml` (non-required extended test)
- Profile: supports both GET and POST methods (POST expected to fail)
- DoD:
  - Workflow passes with GET=200 and POST denied (403/404)
  - No secrets or PII in logs
  - Extended testing beyond the minimal Stage C harness
  - Safe observation mode with expected failures