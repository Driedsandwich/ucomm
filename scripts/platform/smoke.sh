#!/usr/bin/env bash
# scripts/platform/smoke.sh - Platform smoke test and logging
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

echo "=== Platform Smoke Test ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
echo ""

echo "=== OS Information ==="
echo "OS: $(uname -s 2>/dev/null || echo 'Unknown')"
echo "Kernel: $(uname -r 2>/dev/null || echo 'Unknown')"
echo "Architecture: $(uname -m 2>/dev/null || echo 'Unknown')"
echo "Platform: $(uname -a 2>/dev/null || echo 'Unknown')"
echo ""

echo "=== Environment ==="
echo "Shell: ${SHELL:-Unknown}"
echo "User: ${USER:-${USERNAME:-Unknown}}"
echo "Home: ${HOME:-Unknown}"
echo "PWD: $PWD"
echo "SECURE_MODE: ${UCOMM_SECURE_MODE:-0}"
echo ""

echo "=== Command Availability ==="
commands=("curl" "git" "node" "python3" "tmux" "yq" "jq")
for cmd in "${commands[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    version=$(${cmd} --version 2>/dev/null | head -1 2>/dev/null || echo "available")
    echo "✓ $cmd: $version"
  else
    echo "✗ $cmd: not found"
  fi
done
echo ""

echo "=== MCP Connectivity Test ==="
if command -v curl >/dev/null 2>&1; then
  for endpoint in "ready" "health"; do
    echo -n "MCP /$endpoint: "
    start_time=$(date +%s%3N)
    if response=$(curl -fsS "http://127.0.0.1:39200/$endpoint" --max-time 3 2>/dev/null); then
      end_time=$(date +%s%3N)
      latency=$((end_time - start_time))
      echo "OK (${latency}ms)"
      echo "  Response: $response" | head -c 100
      echo ""
    else
      echo "FAILED or UNREACHABLE"
    fi
  done
else
  echo "curl not available - skipping MCP test"
fi
echo ""

echo "=== System Resources ==="
if command -v df >/dev/null 2>&1; then
  echo "Disk Usage:"
  df -h . 2>/dev/null | head -2 || echo "df command failed"
fi

if command -v free >/dev/null 2>&1; then
  echo "Memory Usage:"
  free -h 2>/dev/null | head -2 || echo "free command not available"
elif [[ "$(uname -s)" == "Darwin" ]]; then
  echo "Memory Usage (macOS):"
  vm_stat 2>/dev/null | head -5 || echo "vm_stat command failed"
fi
echo ""

echo "=== File System Check ==="
echo "Config files:"
for file in "config/topology.yaml" "config/cli_adapters.yaml" "profiles/mcp/default/mcp.json"; do
  if [[ -f "$file" ]]; then
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "?")
    echo "✓ $file (${size} bytes)"
  else
    echo "✗ $file (missing)"
  fi
done
echo ""

echo "Script directories:"
for dir in "scripts" "logs" "profiles"; do
  if [[ -d "$dir" ]]; then
    count=$(ls -1 "$dir" 2>/dev/null | wc -l || echo "0")
    echo "✓ $dir/ ($count items)"
  else
    echo "✗ $dir/ (missing)"
  fi
done
echo ""

echo "=== Health Check Integration ==="
if [[ -x "scripts/health.sh" ]]; then
  echo "Running health check..."
  health_output=$(./scripts/health.sh --json 2>/dev/null || echo '{"error":"health_check_failed"}')
  status=$(echo "$health_output" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || echo "unknown")
  echo "Health Status: $status"
  
  if [[ "$status" != "ok" ]]; then
    echo "Health Issues Detected:"
    missing_bins=$(echo "$health_output" | grep -o '"missing_bins":\[[^\]]*\]' 2>/dev/null || echo "[]")
    pane_issues=$(echo "$health_output" | grep -o '"pane_issues":[0-9]*' | cut -d':' -f2 2>/dev/null || echo "0")
    echo "  Missing binaries: $missing_bins"
    echo "  Pane issues: $pane_issues"
  fi
else
  echo "Health script not executable"
fi
echo ""

echo "=== Platform Smoke Test Complete ==="
echo "Summary: $(uname -s) platform validated at $(date -u +%H:%M:%S)"
