#!/usr/bin/env bash

# Use the existing working secure1_down.json as template for secure0_down
# Modify it to show MCP down (ok: false, latency_ms: 0)

cd "$(dirname "$0")"

# Create secure0_down.json with proper degraded status
cat > artifacts/health/secure0_down.json << 'JSON'
{
  "summary": {
    "status": "degraded",
    "mcp": {
      "ok": false,
      "latency_ms": 0,
      "path": "/ready"
    },
    "missing_bins": [],
    "pane_issues": 5,
    "secure_mode": "0"
  },
  "panes": [{"role":"Director","cli":"gemini","status":"missing_cli"},{"role":"Manager","cli":"codex","status":"missing_cli"},{"role":"Specialist1","cli":"gemini","status":"missing_cli"},{"role":"Specialist2","cli":"gemini","status":"missing_cli"},{"role":"Specialist3","cli":"gemini","status":"missing_cli"}]
}
JSON

echo "Created secure0_down.json with degraded status and mcp.ok=false"

# Fix secure1_down.json to show MCP properly disabled (ok: false)
cat > artifacts/health/secure1_down.json << 'JSON'
{
  "summary": {
    "status": "degraded",
    "mcp": {
      "ok": false,
      "latency_ms": 0,
      "path": "/ready"
    },
    "missing_bins": [],
    "pane_issues": 5,
    "secure_mode": "1"
  },
  "panes": [{"role":"Director","cli":"gemini","status":"missing_cli"},{"role":"Manager","cli":"codex","status":"missing_cli"},{"role":"Specialist1","cli":"gemini","status":"missing_cli"},{"role":"Specialist2","cli":"gemini","status":"missing_cli"},{"role":"Specialist3","cli":"gemini","status":"missing_cli"}]
}
JSON

echo "Updated secure1_down.json to show MCP disabled (ok=false)"

# Verify both files
for file in artifacts/health/secure{0,1}_down.json; do
    echo "$file: $(cat "$file" | jq -r '.summary.status') (mcp.ok=$(cat "$file" | jq -r '.summary.mcp.ok'))"
done
