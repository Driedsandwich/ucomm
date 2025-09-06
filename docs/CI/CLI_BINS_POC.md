# CLI Bins PoC (Phase 5 / Issue #12)

## Scope
- Provide minimal, cross-OS wrappers for `/health` to standardize execution.
- This PoC does NOT change business logic; it's a harness for later integration.

## CI
- Workflow: .github/workflows/ci-cli-bins.yml
- Jobs: health-linux, health-windows, health-macos
- Artifacts: health-*.json

## Next
- Replace emulated outputs with real adapters once RFC (#13) aligns.
- Add latency measurement + SLO gates (<= 6000ms) once real endpoints exist.