#!/usr/bin/env bash
export UCOMM_SECURE_MODE=0
export MCP_PORT=39205  
export MCP_TIMEOUT=2

# Remove existing files
rm -f artifacts/health/secure0_down.json

# Run without set -e to allow completion
set +e
bash scripts/health.sh --json
exit_code=$?
echo "Exit code: $exit_code" >&2
set -e
