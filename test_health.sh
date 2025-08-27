#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Testing health.sh with MCP down..."

# Ensure MCP is down on test port
MCP_PORT=39205 scripts/mcp-launch.sh stop || true

# Test SECURE_MODE=0 + MCP DOWN  
export UCOMM_SECURE_MODE=0
export MCP_PORT=39205
export MCP_TIMEOUT=2

echo "Running health.sh for secure0_down..."
set +e
scripts/health.sh --json > artifacts/health/secure0_down.json 2> logs/health_secure0_down.stderr
echo "Exit code: $?"
set -e

# Test SECURE_MODE=1 + MCP DOWN
export UCOMM_SECURE_MODE=1
echo "Running health.sh for secure1_down..."
set +e
scripts/health.sh --json > artifacts/health/secure1_down.json 2> logs/health_secure1_down.stderr
echo "Exit code: $?"
set -e

echo "Checking results..."
for file in artifacts/health/secure{0,1}_down.json; do
    if [[ -s "$file" ]]; then
        echo "$file: $(cat "$file" | jq -r '.summary.status' 2>/dev/null || echo 'JSON parse failed')"
    else
        echo "$file: Empty or missing"
    fi
done
