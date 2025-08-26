# Supported Platforms & CI Matrix

This project validates smoke tests on GitHub Actions across:
- **Ubuntu (ubuntu-latest)**
- **macOS (macos-latest)**
- **Windows (windows-latest)**

## Invariants (All OS)
- Step Summary **must include** both lines:
  - `- Health: **{status}**`
  - `- MCP: **{status}** (/ready: {ready}, /health: {health})`
- `yq` is installed cross-OS and used for JSON parsing (no jq dependency).
- `SECURE_MODE=0/1` must both succeed (CI-friendly, MCP may be **down**).

## OS-Specific Notes
- **Ubuntu**: tmux info is captured.
- **macOS/Windows**: tmux capture is skipped.
- **MCP**: CI typically has no Node runtime; MCP endpoints are expected to be `failed/down`. This is OK.

