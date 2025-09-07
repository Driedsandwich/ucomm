# RFC-001: MCP-in-CI

**Status**: Adopted
**Date**: 2025-09-07

## Summary

Integration of Model Control Protocol (MCP) servers into CI/CD pipeline for secure, controlled API boundary testing.

## Stages

- **Stage A**: Static validation (ci-mcp-validate) ✅ Complete
- **Stage B**: Ephemeral server testing ✅ Complete  
- **Stage C**: API boundary verification ✅ Complete

## Implementation

All stages implemented and validated through PR #59, #60, #66, #67, #72, #73.

## Security Considerations

- Read-only mode enforced
- Token masking implemented
- Allowlist-based restrictions
- Schema validation required

---

*This RFC documents the complete MCP-in-CI framework as implemented in the ucomm project.*