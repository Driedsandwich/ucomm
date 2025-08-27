# Supported Platforms & CI Matrix

This project validates smoke tests on GitHub Actions across:
- **Ubuntu (ubuntu-latest)**
- **macOS (macos-latest)**
- **Windows (windows-latest)**

## Invariants (All OS)
- Step Summary **must include** both lines:
  - `- Health: **{status}**` (Expected: `ok`, `degraded`, or `unknown`)
  - `- MCP: **{status}** (/ready: {ready}, /health: {health})` (Expected: `down` in CI, `up` locally)
- `yq` is installed cross-OS and used for JSON parsing (no jq dependency).
- `SECURE_MODE=0/1` must both succeed (CI-friendly, MCP may be **down**).

## OS-Specific Notes
- **Ubuntu**: tmux info is captured; missing sessions are tolerated and do not cause failures
- **macOS/Windows**: tmux capture is skipped.
- **Error Handling**: All platforms include proper fallbacks and tolerance for CI-specific limitations
- **MCP**: CI typically has no Node runtime; MCP endpoints are expected to be `failed/down`. This is OK.


## Expected Results by Platform
- **Ubuntu (ubuntu-latest)**: ✅ SUCCESS - Full tmux collection, all endpoints verified
- **macOS (macos-latest)**: ✅ SUCCESS - Core functionality verified, tmux skipped  
- **Windows (windows-latest)**: ✅ SUCCESS - Cross-platform compatibility verified

## Recent Verification
- **Phase 4.1 Achievement**: 100% success rate (6/6 jobs) across both SECURE_MODE values
- **Run Examples**: 
  - SECURE_MODE=0: Run 17253106383 ✅ (Ubuntu: 34s, macOS: 28s, Windows: 52s)  
  - SECURE_MODE=1: Run 17253201693 ✅ (Ubuntu: 31s, macOS: 26s, Windows: 49s)
