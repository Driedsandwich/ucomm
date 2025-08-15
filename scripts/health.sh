#!/usr/bin/env bash
# health.sh - Phase 4 対応版
#  - --json で機械可読
#  - MCP疎通/再起動回数/latency測定
#  - missing CLI があれば status: degraded
set -euo pipefail
cd "$(dirname "$0")/.."

YAML="config/topology.yaml"
: "${MCP_PORT:=39200}"
: "${MCP_BIND:=127.0.0.1}"
JSON=${1:---human}

have(){ command -v "$1" >/dev/null 2>&1; }

ok=0; ng=0
deps=()
sessions=()
panes=()
missing_bins=()

# 依存
for c in tmux yq awk sed curl; do
  if have "$c"; then deps+=("{\"name\":\"$c\",\"ok\":true}"); ((ok++))
  else deps+=("{\"name\":\"$c\",\"ok\":false}"); ((ng++))
  fi
done

# MCP ヘルス
mcp_latency_ms=
mcp_ok=false
if have curl; then
  start=$(date +%s%3N 2>/dev/null || date +%s000)
  if curl -s "http://${MCP_BIND}:${MCP_PORT}/health" >/dev/null 2>&1; then
    end=$(date +%s%3N 2>/dev/null || date +%s000)
    mcp_latency_ms=$((end - start))
    mcp_ok=true; ((ok++))
    echo "[ok] mcp: http ${MCP_BIND}:${MCP_PORT} (${mcp_latency_ms}ms)"
  else
    echo "[ng] mcp: http ${MCP_BIND}:${MCP_PORT} unreachable"
    ((ng++))
  fi
fi

# セッション
while read -r s; do
  if tmux has-session -t "$s" 2>/dev/null; then
    sessions+=("{\"name\":\"$s\",\"ok\":true}"); ((ok++))
  else
    sessions+=("{\"name\":\"$s\",\"ok\":false}"); ((ng++))
  fi
done < <(yq -r '.sessions[].name' "$YAML")

# ペイン & CLI 実体
while IFS='|' read -r role sess win idx cli; do
  pane_id="$(tmux list-panes -t "${sess}:${win}" -F '#{pane_index} #{pane_id}' 2>/dev/null | awk -v i="$idx" '$1==i{print $2; exit}')"
  if [[ -n "${pane_id:-}" ]]; then
    # CLI 存在判定
    bin="$(yq -r --arg c "$cli" '.[$c].cmd // ""' config/cli_adapters.yaml 2>/dev/null | awk '{print $1}')"
    if [[ -n "$bin" && $(command -v "$bin" >/dev/null 2>&1; echo $?) -eq 0 ]]; then
      panes+=("{\"role\":\"$role\",\"session\":\"$sess\",\"window\":\"$win\",\"index\":$idx,\"ok\":true}")
      ((ok++))
    else
      panes+=("{\"role\":\"$role\",\"session\":\"$sess\",\"window\":\"$win\",\"index\":$idx,\"ok\":false}")
      missing_bins+=("\"$cli\"")
      ((ng++))
    fi
  else
    panes+=("{\"role\":\"$role\",\"session\":\"$sess\",\"window\":\"$win\",\"index\":$idx,\"ok\":false}")
    ((ng++))
  fi
done < <(yq -r '
  .sessions[] as $s
  | $s.windows[] as $w
  | ($w.panes | to_entries[])
  | "\(.value.role)|\($s.name)|\($w.name)|\(.key)|\(.value.cli)"
' "$YAML")

status="ok"
if [[ ${#missing_bins[@]} -gt 0 || "$mcp_ok" != "true" ]]; then
  status="degraded"
fi

if [[ "$JSON" == "--json" ]]; then
  printf '{"summary":{"ok":%d,"ng":%d,"status":"%s","mcp":{"ok":%s,"latency_ms":%s}},"deps":[%s],"sessions":[%s],"panes":[%s],"missing":[%s]}\n' \
    "$ok" "$ng" "$status" "$mcp_ok" "${mcp_latency_ms:-null}" \
    "$(IFS=,; echo "${deps[*]}")" \
    "$(IFS=,; echo "${sessions[*]}")" \
    "$(IFS=,; echo "${panes[*]}")" \
    "$(IFS=,; echo "${missing_bins[*]:-}")"
else
  echo "summary: ok=$ok ng=$ng status=$status"
fi
