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

## Latest Measurements (main)
| Date | OS | latency_ms |
|------|----|------------|
| 2025-09-06 | Linux | 23 |
| 2025-09-06 | Windows | 67 |
| 2025-09-06 | macOS | 43 |
| 2025-09-06 | AVG | 44 |
| 2025-09-06 | MAX | 67 |
| 2025-09-06 | MIN | 23 |

(Artifacts: `docs/reports/data/2025-09-06/mcp-ephemeral-main/`)