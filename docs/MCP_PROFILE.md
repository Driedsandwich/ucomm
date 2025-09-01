# ucomm MCP Profile Configuration

## Overview

MCP (Model Context Protocol) profile configuration with minimum privilege and read-only default operation.

## MCP Profile Principles

- **原則read-only**: 最小権限・原則RO、プロファイルJSONで規定。
- **profiles/mcp/default/mcp.json を正とする**（差分時はPRで承認）。
- **必要最小限のツールのみ許可**。

## Profile Configuration

### Default Profile Location
```
profiles/mcp/default/mcp.json
```

### Profile Structure
```json
{
  "name": "ucomm-default",
  "version": "0.5.x",
  "security": {
    "mode": "read_only",
    "allowed_operations": [
      "file_read",
      "directory_list", 
      "process_status",
      "health_check"
    ],
    "denied_operations": [
      "file_write",
      "file_delete",
      "process_execute",
      "system_modify"
    ]
  },
  "tools": {
    "minimal_set": [
      "health",
      "status",
      "list",
      "read"
    ]
  }
}
```

## Security Configuration

### Read-Only Enforcement
- All write operations blocked by default
- File system modifications prohibited
- System changes require explicit approval
- Process execution limited to status checks

### Minimum Privilege Access
```json
{
  "permissions": {
    "file_system": {
      "read": true,
      "write": false,
      "execute": false,
      "delete": false
    },
    "network": {
      "read": true,
      "write": false
    },
    "system": {
      "read": true,
      "write": false
    }
  }
}
```

## Profile Management

### Profile Updates
- All changes require PR approval
- Configuration schema validation required
- Security review mandatory for permission changes
- Backward compatibility testing

### Approval Process
1. Create PR with profile changes
2. Security team review
3. Schema validation
4. Integration testing
5. Approval and merge

## Configuration Validation

### Schema Verification
```bash
# Validate profile configuration
./scripts/mcp-profile-validate.sh profiles/mcp/default/mcp.json

# Test profile permissions
./scripts/mcp-profile-test.sh --profile default --operation read
```

### Security Audit
```bash
# Audit current profile permissions
./scripts/mcp-security-audit.sh

# Generate compliance report
./scripts/mcp-compliance-report.sh
```

## Tool Access Control

### Approved Tools
- **health**: System health monitoring
- **status**: Component status checks
- **list**: Directory and file listing
- **read**: File content reading

### Restricted Tools
- **write**: File modification operations
- **execute**: Process execution
- **delete**: File and directory removal
- **modify**: System configuration changes

## Profile Override

### Emergency Override
```bash
# Temporary override for authorized operations
export MCP_PROFILE_OVERRIDE=emergency
export MCP_OVERRIDE_JUSTIFICATION="Security incident response"
```

### Override Audit
- All overrides logged with justification
- Automatic reversion after 1 hour
- Security team notification
- Compliance report generation

## Integration with Write Gates

### Combined Security Model
```bash
# Profile enforces read-only at MCP level
# Write gates enforce at system level
# Both must be satisfied for write operations

# MCP profile: read_only = true
# Write gate: UCOMM_ENABLE_WRITES = 0
# Result: Double protection against unauthorized writes
```

## Development and Testing

### Development Profile
```json
{
  "name": "ucomm-development", 
  "security": {
    "mode": "development",
    "allowed_operations": ["file_read", "file_write", "process_execute"],
    "test_mode": true
  }
}
```

### Testing Framework
```bash
# Test profile restrictions
./scripts/test-mcp-profile.sh --profile default

# Verify read-only enforcement
./scripts/test-write-protection.sh

# Validate tool access controls
./scripts/test-tool-access.sh
```

## Monitoring and Compliance

### Access Monitoring
- Real-time permission usage tracking
- Unauthorized access attempt logging
- Profile compliance reporting
- Security event alerting

### Compliance Reporting
```bash
# Generate monthly compliance report
./scripts/mcp-compliance-monthly.sh

# Audit profile usage patterns
./scripts/mcp-usage-audit.sh

# Security metrics dashboard
./scripts/mcp-security-metrics.sh
```

## Profile Evolution

### Version Management
- Semantic versioning for profile changes
- Migration path documentation
- Rollback procedures
- Compatibility matrix

### Future Enhancements
- Dynamic permission adjustment
- Role-based access control (RBAC)
- Integration with external identity providers
- Advanced audit and monitoring capabilities