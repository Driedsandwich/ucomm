#!/usr/bin/env bash
# mcp-launch.sh (Phase4 最終版)
set -euo pipefail
cd "$(dirname "$0")/.."

: "${MCP_PROFILE:=default}"
: "${MCP_PORT:=39200}"
: "${MCP_TERM_GRACE_SEC:=5}"
: "${MCP_BIND:=127.0.0.1}"
: "${MCP_LOG_DIR:=logs/mcp}"

CONFIG="profiles/mcp/${MCP_PROFILE}/mcp.json"
BIN="node ./node_modules/.bin/mcp-server-node"
PIDFILE=".run/mcp.pid"
RESTART_MAX=3

mkdir -p "$(dirname "$PIDFILE")" "$MCP_LOG_DIR"
: >"$MCP_LOG_DIR/server-stdout.log"
: >"$MCP_LOG_DIR/server-stderr.log"

# Node >= 20 チェック
if ! command -v node >/dev/null 2>&1; then
  echo "[mcp] node not found"; exit 1
fi
NODE_MAJ="$(node -v | sed -E 's/^v([0-9]+).*/\1/')"
if [ "${NODE_MAJ:-0}" -lt 20 ]; then
  echo "[mcp] Node >= 20 required (found v$(node -v))"; exit 1
fi

shutdown() {
  echo "[mcp] shutdown requested (trap). giving ${MCP_TERM_GRACE_SEC}s grace"
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill -TERM "$(cat "$PIDFILE")" 2>/dev/null || true
    sleep "$MCP_TERM_GRACE_SEC"
    kill -KILL "$(cat "$PIDFILE")" 2>/dev/null || true
  fi
  exit 0
}
trap shutdown INT TERM

restarts=0
while true; do
  if [[ ! -f "$CONFIG" ]]; then
    echo "[mcp] config not found: $CONFIG"; exit 1
  fi
  echo "[mcp] start ${MCP_PROFILE} on ${MCP_BIND}:${MCP_PORT}"
  set +e
  $BIN \
    --config "$CONFIG" \
    --port "$MCP_PORT" \
    --bind "$MCP_BIND" \
    --grace "$MCP_TERM_GRACE_SEC" \
    >>"$MCP_LOG_DIR/server-stdout.log" 2>>"$MCP_LOG_DIR/server-stderr.log" &
  pid=$!; echo $pid > "$PIDFILE"
  wait $pid; code=$?
  set -e
  echo "[mcp] exited code=$code"

  if [[ "${UCOMM_SECURE_MODE:-0}" == "1" ]]; then
    echo "[mcp] SECURE_MODE=1 -> stop on failure"; exit 1
  fi
  ((restarts+=1))
  if ((restarts > RESTART_MAX)); then
    echo "[mcp] restart limit exceeded (${RESTART_MAX})"; exit 1
  fi
  sleep $((2**(restarts-1)))  # 1 -> 2 -> 4s
  echo "[mcp] restarting (${restarts}/${RESTART_MAX})"
done
