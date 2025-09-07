# Stage C: GitHub API Boundary Test (Draft)

- Token: built-in `GITHUB_TOKEN` (least privileges, repo-scoped)
- Allowed: safe GET calls (e.g., `/repos/:owner/:repo`)
- Denied: state-changing calls (POST/DELETE/PUT/PATCH) -> expect 403/404
- CI: `.github/workflows/ci-mcp-api-boundary.yml` (not required check yet)
- DoD:
  - Workflow passes with GET=200 and POST denied (403/404)
  - No secrets or PII in logs
  - This PR only introduces the harness; adding endpoints matrix comes next.