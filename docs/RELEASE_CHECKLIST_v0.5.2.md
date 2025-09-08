# Release Checklist v0.5.2

## Pre-Release Verification

### CI/CD Infrastructure  
- [ ] smoke.yml のOSマトリクス定義確認（ubuntu/macos/windows）
- [ ] SECURE_MODE=0/1 の両Runが SUCCESS（3/3 OS）
- [ ] Step Summary に「Health」「MCP」の2行が出力
- [ ] アーティファクト（health.json, mcp_ready.json, mcp_health.json, MODE, tmux_*）生成

### Documentation Updates
- [ ] README/PLATFORMS/OPERATIONS/ENV 更新反映済み
- [ ] GitHub Actions badge表示確認
- [ ] OS matrix support説明追加確認
- [ ] UCOMM_SECURE_MODE仕様書完成

## Phase 4.1 Achievements Verification

### Success Rate Requirements
- [ ] 3 OS成功率 ≥95% (Target: 100%)
  - [ ] SECURE_MODE=0: All 3 OS SUCCESS
  - [ ] SECURE_MODE=1: All 3 OS SUCCESS

### Performance Benchmarks
- [ ] /health 初回応答: ローカル ≤5s / CI ≤6s
- [ ] CI job duration within expected ranges:
  - [ ] Ubuntu: 30-40s
  - [ ] macOS: 25-35s  
  - [ ] Windows: 45-60s

### Feature Completeness
- [ ] Cross-OS yq installation working (Ubuntu/macOS/Windows)
- [ ] Ubuntu tmux collection tolerance (missing sessions handled gracefully)
- [ ] MCP HTTP stub integration (SECURE_MODE=0/1 both functional)
- [ ] Step Summary contract fulfillment (Health + MCP lines on all platforms)

## Technical Verification

### Workflow Configuration
- [ ] .github/workflows/smoke.yml contains proper OS matrix
- [ ] workflow_dispatch inputs configured (secure_mode, run_capture)
- [ ] Environment variable precedence working correctly
- [ ] Concurrency control and cancel-in-progress functionality

### Error Handling & Tolerance
- [ ] Ubuntu: tmux session tolerance verified
- [ ] macOS/Windows: tmux capture appropriately skipped
- [ ] CI: MCP endpoint failures handled gracefully
- [ ] All platforms: Proper fallback mechanisms in place

### Artifact Generation
- [ ] health.json: Contains complete system status
- [ ] mcp_*.json: Proper endpoint verification results  
- [ ] MODE file: Correct operational mode
- [ ] topology.yaml: System configuration preserved
- [ ] Platform-specific tmux info (Ubuntu only)

## Quality Assurance

### Code Quality
- [ ] No secrets or sensitive information in committed files
- [ ] All shell scripts have proper error handling (set -Eeuo pipefail where applicable)  
- [ ] Cross-platform compatibility verified
- [ ] Configuration files use supported CLI commands only (gemini/codex/claude)

### Documentation Quality
- [ ] All documentation uses consistent formatting
- [ ] Code examples are tested and functional
- [ ] Troubleshooting sections include common scenarios
- [ ] Performance benchmarks reflect actual measurements

## Release Preparation

### Version Tagging
- [ ] Create v0.5.2-rc1 tag with appropriate message
- [ ] GitHub Release draft created with comprehensive notes
- [ ] Release notes include Phase 4.1 achievements
- [ ] Breaking changes documented (if any)

### Final Verification
- [ ] One final smoke test (SECURE_MODE=0) successful
- [ ] All documentation links functional
- [ ] Repository clean (no uncommitted changes)
- [ ] CI pipeline green on main branch

## Post-Release Tasks

### Monitoring
- [ ] Monitor initial adoption feedback
- [ ] Watch for CI failures in dependent projects
- [ ] Track performance metrics for regressions

### Documentation Maintenance  
- [ ] Update any external documentation references
- [ ] Verify all example commands work as documented
- [ ] Confirm troubleshooting guides remain accurate

---

## Completion Criteria

This release (v0.5.2) is ready when:

1. **All checklist items above are completed** ✅
2. **Phase 4.1 DOD fully achieved**: 100% success rate across all OS platforms 
3. **Documentation ecosystem complete**: README, PLATFORMS, OPERATIONS, ENV all current
4. **CI pipeline robust**: Handles both SECURE_MODE values across all platforms
5. **User experience enhanced**: Clear operational procedures and troubleshooting guides

## Sign-off

- [ ] Technical Lead Approval
- [ ] Quality Assurance Verification  
- [ ] Documentation Review Complete
- [ ] Release Notes Approved

**Release Date Target**: TBD  
**Phase 4.1 Achievement Date**: 2025-08-27 (100% CI success rate achieved)
