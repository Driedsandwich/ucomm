# 1-Page Operational Handoff - ucomm v0.5.0

**Framework**: ucomm Multi-Agent Communication Framework  
**Version**: v0.5.0 (Production Ready)  
**Handoff Date**: 2025-08-28

## 🚀 Quick Start (New Deployment)

```bash
# 1. Clone and setup
git clone https://github.com/Driedsandwich/ucomm.git
cd ucomm && git checkout v0.5.0

# 2. Development mode startup
export UCOMM_SECURE_MODE=0
./scripts/ucomm-launch.sh start

# 3. Verify health
./scripts/health.sh --json
```

**Expected Result**: JSON with `"status": "degraded"` (normal - CLI tools not installed)

## 🔥 Emergency Troubleshooting (Most Common Issues)

### Issue 1: "Port 39200 already in use"
```bash
# Solution: Change port or stop existing process
export MCP_PORT=39201
./scripts/mcp-launch.sh restart
```

### Issue 2: "health.sh returns no output"  
```bash  
# Debug: Run with verbose output
bash -x scripts/health.sh --json 2>&1 | head -20
```

### Issue 3: "CLI adapters missing"
```bash
# Normal behavior - graceful degradation enabled
export UCOMM_FAIL_ON_MISSING_CLI=0  # Default: warnings only
export UCOMM_FAIL_ON_MISSING_CLI=1  # Strict: exit on missing CLI
```

## 📊 Health Status Interpretation

| Status | Meaning | Action Required |
|--------|---------|-----------------|
| `"ok"` | All systems operational | None |
| `"degraded"` | Some components unavailable | Review logs, may be normal |
| `"unknown"` | Multiple issues detected | Investigate immediately |

## 📚 Documentation Quick Reference

| Document | Use Case |
|----------|----------|
| `docs/PLATFORMS.md` | Cross-platform compatibility issues |
| `docs/DECISIONS_LOG.md` | Architecture questions and rationale |
| `docs/OPERATIONS.md` | Detailed operational procedures |
| `CHANGELOG.md` | Feature changes and migration notes |

## 🆘 FAQ & Common Scenarios

**Q: System shows "degraded" status - is this bad?**  
A: Often normal. Check `missing_bins` and `pane_issues` counts. Non-zero values indicate missing CLI tools (expected in basic setup).

**Q: Production deployment checklist?**  
A: 1) Set SECURE_MODE=1, 2) Review configs, 3) Manual verification, 4) Gradual rollout

---

**Release Info**: https://github.com/Driedsandwich/ucomm/releases/tag/v0.5.0
