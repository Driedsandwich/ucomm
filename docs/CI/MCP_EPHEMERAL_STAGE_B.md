# MCP Stage B: Ephemeral reference server in CI

## Scope
- Start a minimal HTTP server in CI (localhost:39200).
- Validate /health returns 200 within 6000ms.
- Check deny path returns 403 (boundary behavior).

## Workflows
- .github/workflows/ci-mcp-ephemeral.yml

## Notes
- No external packages required. Node 20 via setup-node.
- Stability確認後、Branch Protectionの必須チェック候補に追加。