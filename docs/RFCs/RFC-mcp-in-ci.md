# RFC: MCP Server Execution in CI Environments

**Status:** Draft  
**Created:** 2025-08-28  
**Author:** Claude Code  
**Scope:** Phase 4 CI Hardening - MCP Integration Feasibility  

## Abstract

This RFC analyzes the feasibility, constraints, and implementation approaches for executing MCP (Model Context Protocol) servers within GitHub Actions CI environments. Based on Phase 4 CI hardening efforts that achieved a 35.0% success rate improvement (from 22.2% baseline), this document outlines the technical requirements, security considerations, and operational constraints for MCP-in-CI deployment.

## Background

### Current State

The ucomm multi-agent framework currently operates MCP stub servers in development environments with the following characteristics:

- **Development Mode (`UCOMM_SECURE_MODE=0`)**: MCP HTTP server expected on localhost:39200
- **Production Mode (`UCOMM_SECURE_MODE=1`)**: MCP server disabled, health checks expect failure
- **CI Health Stability**: Enhanced from 22.2% to 35.0% success rate through hardened health checks

### Problem Statement

Current CI workflows disable MCP servers (`UCOMM_SECURE_MODE=1`) to avoid GitHub Actions limitations, but this prevents testing of MCP-dependent functionality. We need to evaluate whether full MCP server execution in CI is feasible and under what constraints.

## Requirements Analysis

### Functional Requirements

- **F1**: Execute lightweight MCP HTTP server within GitHub Actions runners
- **F2**: Provide `/ready` and `/health` endpoints for CI health validation  
- **F3**: Support cross-platform execution (Ubuntu, macOS, Windows)
- **F4**: Maintain CI job execution time under 5-minute timeout limits
- **F5**: Enable testing of MCP-dependent workflows in CI environment

### Non-Functional Requirements

- **NF1**: **Security**: No persistent external network access or data storage
- **NF2**: **Performance**: Server startup time < 30 seconds
- **NF3**: **Reliability**: CI success rate impact < 5% degradation
- **NF4**: **Resource Usage**: Memory < 256MB, CPU < 1 core
- **NF5**: **Isolation**: No interference with parallel CI jobs

## Technical Approach

### Option 1: Minimal HTTP Stub Server

**Implementation**: Lightweight HTTP server providing only health check endpoints.

**Pros**:
- Minimal resource usage
- Fast startup (<5 seconds)
- Cross-platform compatible
- No external dependencies

**Cons**:
- Limited functionality (health checks only)
- Does not test actual MCP protocol behavior

### Option 2: Containerized MCP Server

**Implementation**: Docker-based MCP server with CI-specific configuration.

**Pros**:
- Full MCP protocol support
- Resource limits enforced
- Isolated execution environment
- Reproducible across runners

**Cons**:
- Docker dependency (not available on all runner types)
- Longer startup time (30-60 seconds)
- Additional complexity in CI configuration

### Option 3: Process-Based MCP Server

**Implementation**: Native process execution with timeout controls.

**Pros**:
- Full MCP functionality
- Fine-grained resource control  
- Native performance
- Platform-specific optimizations

**Cons**:
- Platform-specific implementation complexity
- Resource monitoring overhead
- Potential conflicts with runner environment

## Security Considerations

### Isolation Requirements

1. **Network Isolation**: MCP server bound only to localhost (127.0.0.1)
2. **Filesystem Access**: Read-only access to project files, no external writes
3. **Process Isolation**: Terminated automatically on CI job completion
4. **Resource Limits**: Enforced memory and CPU constraints

### Risk Assessment

| Risk | Impact | Probability | Mitigation |
|------|---------|-------------|------------|
| Resource exhaustion | High | Medium | Resource limits + monitoring |
| Network exposure | High | Low | Localhost binding + firewall |
| Process persistence | Medium | Low | Explicit cleanup + timeout |
| Secret exposure | High | Low | No secret access in MCP context |

## Implementation Phases

### Phase 1: Proof of Concept (1-2 days)
- Implement Option 1 (Minimal HTTP Stub)
- Integrate with existing CI health checks
- Validate cross-platform compatibility
- Measure impact on CI success rates

### Phase 2: Enhanced Stub (3-5 days)
- Add basic MCP protocol endpoints
- Implement request routing simulation
- Add configuration-based response generation
- Performance optimization and monitoring

### Phase 3: Full Integration (1-2 weeks)
- Deploy Option 2 or 3 based on Phase 1/2 results
- Comprehensive testing of MCP-dependent workflows
- Production-ready monitoring and alerting
- Documentation and operational procedures

## Success Metrics

### Performance Targets

- **CI Success Rate**: Maintain >= 70% (Phase 4 target)
- **Server Startup Time**: < 30 seconds average
- **Memory Usage**: < 256MB peak
- **Job Duration Impact**: < 10% increase over baseline

### Quality Gates

1. **Reliability**: 95% successful MCP server starts in CI
2. **Stability**: No CI job failures attributed to MCP server issues
3. **Resource Efficiency**: Resource usage within runner limits
4. **Security Compliance**: All security controls validated

## Risks and Mitigation

### Technical Risks

1. **GitHub Actions Limitations**
   - Risk: Runner resource constraints
   - Mitigation: Lightweight implementation + resource monitoring

2. **Cross-Platform Compatibility**
   - Risk: Platform-specific failures
   - Mitigation: Platform-specific testing + fallback implementations

3. **Network Port Conflicts**
   - Risk: Port 39200 already in use
   - Mitigation: Dynamic port assignment + environment configuration

### Operational Risks

1. **CI Pipeline Stability**
   - Risk: MCP server failures breaking CI
   - Mitigation: Graceful degradation + fallback modes

2. **Maintenance Overhead**
   - Risk: Additional complexity requiring ongoing maintenance
   - Mitigation: Comprehensive documentation + automation

## Recommendations

### Immediate Actions (Phase 4.3)

1. **Implement Option 1 (Minimal HTTP Stub)** as immediate proof of concept
2. **Add CI environment variable `UCOMM_MCP_CI_MODE`** to enable MCP-in-CI selectively
3. **Enhance existing CI success rate monitoring** to track MCP-specific metrics
4. **Create comprehensive test suite** for MCP-in-CI scenarios

### Long-term Strategy

1. **Conditional MCP Deployment**: Enable MCP-in-CI only for specific test scenarios
2. **Graduated Rollout**: Start with stub server, evolve to full MCP as needed
3. **Performance Monitoring**: Continuous monitoring of resource usage and CI impact
4. **Security Auditing**: Regular security reviews of MCP-in-CI implementation

## Conclusion

MCP server execution in CI environments is **technically feasible** with appropriate constraints and implementation approach. The recommended path is:

1. **Start with minimal HTTP stub** (Option 1) for immediate CI health validation
2. **Measure impact on CI success rates** and resource usage
3. **Evolve to full MCP implementation** (Option 2 or 3) based on requirements and results

The key success factors are:
- **Resource constraints** enforcement
- **Security isolation** implementation  
- **Graceful degradation** when MCP unavailable
- **Comprehensive monitoring** of CI impact

This approach aligns with Phase 4 goals of CI hardening while enabling future MCP-dependent testing capabilities.

---

**Next Steps**: Implement Phase 1 proof of concept and gather performance data for final implementation decision.
