#!/usr/bin/env bash
set -euo pipefail

os=$(uname -s | tr '[:upper:]' '[:lower:]')
d=$(date +%Y%m%d)
out="logs/platform/${os}_${d}.log"

# Create logs/platform directory if it doesn't exist
mkdir -p logs/platform

# Test MCP health endpoint and measure latency
code=$(curl -fsS -o /dev/null -w "%{http_code}" http://127.0.0.1:39200/health --max-time 6 2>/dev/null || echo "000")

# Measure latency
t0=$(date +%s%3N)
curl -fsS -o /dev/null http://127.0.0.1:39200/health --max-time 6 2>/dev/null || true
t1=$(date +%s%3N)

# Log the results
echo "$(date -Iseconds) os=$os health_http=$code latency_ms=$((t1-t0)) secure_mode=${UCOMM_SECURE_MODE:-0}" | tee "$out"

exit 0
