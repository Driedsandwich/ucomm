#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG="$ROOT/config/topology.yaml"

json_escape() {
  python3 - <<'PY' "$1"
import json,sys
print(json.dumps(sys.argv[1]))
PY
}

# --- MCP /ready → /health の順で応答時間計測 -------------------------------
PORT="${MCP_PORT:-39200}"
READY_URL="http://127.0.0.1:${PORT}/ready"
HEALTH_URL="http://127.0.0.1:${PORT}/health"
mcp_ok=false; mcp_ms=0; mcp_path=""

measure() {
  local url="$1"
  local t0 t1 diff
  t0=$(python3 - <<'PY'
import time; print(int(time.time_ns()))
PY
)
  if curl -fsS "$url" >/dev/null 2>&1; then
    t1=$(python3 - <<'PY'
import time; print(int(time.time_ns()))
PY
)
    diff=$(( (t1 - t0) / 1000000 ))
    echo "$diff"
    return 0
  else
    echo "NA"; return 1
  fi
}

lat="$(measure "$READY_URL")"
if [[ "$lat" != "NA" ]]; then
  mcp_ok=true; mcp_ms="$lat"; mcp_path="/ready"
else
  lat2="$(measure "$HEALTH_URL")"
  if [[ "$lat2" != "NA" ]]; then
    mcp_ok=true; mcp_ms="$lat2"; mcp_path="/health"
  fi
fi

# --- topology から (role, cli) を列挙 --------------------------------------
mapfile -t ROLECLI < <(
  yq -r '
    . as $r
    | .sessions[]
    |   .windows[]
    |     .panes[]
    |       [ .role, (.cli // $r.default_cli) ] | @tsv
  ' "$CFG"
)

missing_bins=()
panes_json=""

for line in "${ROLECLI[@]}"; do
  IFS=$'\t' read -r ROLE CLI <<<"$line"
  status="ok"
  if ! command -v "$CLI" >/dev/null 2>&1; then
    status="missing"
    missing_bins+=( "$(printf '%s\t%s' "$ROLE" "$CLI")" )
  fi

  pj=$(cat <<JSON
{"role":$(json_escape "$ROLE"),"cli":$(json_escape "$CLI"),"status":$(json_escape "$status")}
JSON
)
  if [[ -z "$panes_json" ]]; then panes_json="$pj"; else panes_json="$panes_json,$pj"; fi
done

summary_status="ok"
if [[ "${#missing_bins[@]}" -gt 0 || "$mcp_ok" != true ]]; then
  summary_status="degraded"
fi

mb_json=""
for mb in "${missing_bins[@]}"; do
  mb_json="$mb_json,$(json_escape "$mb")"
done
mb_json="[${mb_json#,}]"

cat <<JSON
{
  "summary": {
    "status": "$summary_status",
    "mcp": { "ok": $mcp_ok, "latency_ms": $mcp_ms, "path": $(json_escape "$mcp_path") },
    "missing_bins": $mb_json
  },
  "panes": [ $panes_json ]
}
JSON
