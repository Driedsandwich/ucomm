# CHANGELOG

## [v0.2.1] - 2025-08-11
- Phase2完了：保険再送・health・capture実装
- health.sh に --json 追加
- send.sh に retry/interval 対応
- PM承認済

## [v0.3.0] - 2025-08-11
- Phase3完了：モード意味論（HIERARCHY/COUNCIL）確立
- モード別プロンプト追加
- send.sh に MODE優先順位対応
- PM承認済

## [v0.5.0] - 2025-08-27 - Phase 4 Complete
### 🎯 Phase 4: 仕上げ＆クロージング
- **MCP Profile & Startup Script Enhancements**
  - Implemented exponential backoff retry (1s, 2s, 4s delays) for MCP HTTP stub
  - Added graceful shutdown with MCP_TERM_GRACE_SEC environment variable support
  - Enhanced log separation (stdout/stderr) and process management
  - Added restart command and improved error handling

- **CLI Adapters & Startup Order Verification**
  - Verified support for Phase 4 CLI commands: gemini, codex, claude
  - Confirmed director→team startup order through topology validation
  - Enhanced timeout/retry policies in send.sh (default: 1 retry, 2s interval)

- **Health Judgment Strictness Improvements**
  - Replaced stub health check with comprehensive system validation
  - Added real MCP endpoint checking with latency measurement (60-93ms typical)
  - Implemented CLI binary availability verification from config
  - Support multiple status levels: ok, degraded, unknown
  - Added SECURE_MODE awareness (production vs development behavior)

- **Cross-OS Supplementation & Platform Logging**
  - Created platform-utils.sh for Windows/macOS/Ubuntu detection
  - Enhanced capture.sh with platform-specific artifact collection
  - Added comprehensive platform logging (OS info, tools, environment)
  - Implemented platform-specific artifact directories (artifacts-windows, etc.)
  - Graceful tmux handling across all platforms with proper fallbacks

- **CI Smoke Testing Refinements**
  - Integrated enhanced cross-platform capture into GitHub Actions
  - Platform-aware artifact collection with detailed reporting
  - Enhanced Step Summary with platform information and file status
  - Comprehensive error handling across Windows/macOS/Ubuntu CI environments
  - Support for both SECURE_MODE=0 (development) and SECURE_MODE=1 (production)

### 🔧 Technical Improvements
- **MCP**: Exponential backoff, graceful shutdown, separated logs
- **Health**: Strict judgment, real endpoint checking, status levels
- **Platform**: Cross-OS detection, logging, artifact management
- **CI**: Enhanced workflows, platform-specific handling, robust testing

### 📊 Verification
- All Phase 4 smoke tests passing across Ubuntu/macOS/Windows
- MCP response times: 60-93ms (well under 5s requirement)
- Health status properly reports degraded/unknown instead of hardcoded "ok"
- Platform-specific artifacts generated correctly for each OS
- PM승認済 - Phase 4 완료

