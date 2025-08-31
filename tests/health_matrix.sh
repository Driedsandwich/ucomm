#!/usr/bin/env bash
# tests/health_matrix.sh - 4-quadrant health testing
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p artifacts/health

echo "Testing 4-quadrant health matrix..."

# Test SECURE_MODE=0 + MCP UP
echo "1/4: SECURE_MODE=0 + MCP UP"
export UCOMM_SECURE_MODE=0
export MCP_PORT=39200
scripts/mcp-launch.sh start >/dev/null 2>&1 || true
sleep 2
scripts/health.sh --json > artifacts/health/secure0_up.json
if grep -q '"status"[[:space:]]*:[[:space:]]*"[^"]*"' artifacts/health/secure0_up.json && 
   grep -q '"secure_mode"[[:space:]]*:[[:space:]]*"0"' artifacts/health/secure0_up.json; then
    echo "✓ secure0_up.json generated successfully"
else
    echo "✗ secure0_up.json validation failed"
    exit 1
fi

# Test SECURE_MODE=0 + MCP DOWN  
echo "2/4: SECURE_MODE=0 + MCP DOWN"
export UCOMM_SECURE_MODE=0
export MCP_PORT=39205  # Different port to ensure MCP is down
scripts/mcp-launch.sh stop >/dev/null 2>&1 || true
scripts/health.sh --json > artifacts/health/secure0_down.json
if grep -q '"status"[[:space:]]*:[[:space:]]*"degraded"' artifacts/health/secure0_down.json &&
   grep -q '"ok"[[:space:]]*:[[:space:]]*false' artifacts/health/secure0_down.json &&
   grep -q '"secure_mode"[[:space:]]*:[[:space:]]*"0"' artifacts/health/secure0_down.json; then
    echo "✓ secure0_down.json generated successfully"
else
    echo "✗ secure0_down.json validation failed"
    exit 1
fi

# Test SECURE_MODE=1 + MCP UP (should treat as disabled)
echo "3/4: SECURE_MODE=1 + MCP UP"
export UCOMM_SECURE_MODE=1
export MCP_PORT=39200
# MCP might be running, but in production mode it should be treated as disabled
scripts/health.sh --json > artifacts/health/secure1_up.json
if grep -q '"status"[[:space:]]*:[[:space:]]*"[^"]*"' artifacts/health/secure1_up.json && 
   grep -q '"secure_mode"[[:space:]]*:[[:space:]]*"1"' artifacts/health/secure1_up.json; then
    echo "✓ secure1_up.json generated successfully"
else
    echo "✗ secure1_up.json validation failed"
    exit 1
fi

# Test SECURE_MODE=1 + MCP DOWN
echo "4/4: SECURE_MODE=1 + MCP DOWN"
export UCOMM_SECURE_MODE=1
export MCP_PORT=39205  # Different port to ensure MCP is down
scripts/health.sh --json > artifacts/health/secure1_down.json
if grep -q '"status"[[:space:]]*:[[:space:]]*"degraded"' artifacts/health/secure1_down.json &&
   grep -q '"ok"[[:space:]]*:[[:space:]]*false' artifacts/health/secure1_down.json &&
   grep -q '"secure_mode"[[:space:]]*:[[:space:]]*"1"' artifacts/health/secure1_down.json; then
    echo "✓ secure1_down.json generated successfully"
else
    echo "✗ secure1_down.json validation failed"
    exit 1
fi

echo "All 4 health matrix files generated successfully:"
ls -la artifacts/health/secure*.json | awk '{print "  " $9 " (" $5 " bytes)"}'

echo "Basic content validation:"
for file in artifacts/health/secure{0,1}_{up,down}.json; do
    if [[ -s "$file" ]]; then
        status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$file" | head -1 | cut -d'"' -f4)
        secure=$(grep -o '"secure_mode"[[:space:]]*:[[:space:]]*"[^"]*"' "$file" | head -1 | cut -d'"' -f4)
        echo "  $(basename "$file"): status=$status, secure_mode=$secure"
    else
        echo "  $(basename "$file"): EMPTY OR MISSING"
        exit 1
    fi
done
