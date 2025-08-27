#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p logs/mcp

for endpoint in ready health; do
    ts_start=$(date +%s%3N)
    code=$(curl -fsS -o /dev/null -w "%{http_code}" "http://127.0.0.1:39200/$endpoint" --max-time 6 || echo "000")
    ts_end=$(date +%s%3N)
    lat=$((ts_end - ts_start))
    echo "$(date -Iseconds) endpoint=/$endpoint code=$code latency_ms=$lat" | tee -a logs/mcp/latency_local.log
done
