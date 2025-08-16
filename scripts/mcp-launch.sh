#!/usr/bin/env bash
set -Eeuo pipefail

PORT="${MCP_PORT:-39200}"
BIND="127.0.0.1"
PROFILE="${MCP_PROFILE:-default}"
GRACE="${MCP_TERM_GRACE_SEC:-5}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/mcp"
STDOUT_LOG="$LOG_DIR/server-stdout.log"
STDERR_LOG="$LOG_DIR/server-stderr.log"
PID_FILE="$LOG_DIR/server.pid"
MAX_RESTARTS=3

mkdir -p "$LOG_DIR"

# SECURE_MODE=1 なのに実サーバ不在なら停止（スタブ禁止）
if [[ "${UCOMM_SECURE_MODE:-0}" = "1" ]]; then
  if ! command -v node >/dev/null 2>&1; then
    echo "[mcp] SECURE_MODE=1 かつ node未検出 → 停止" | tee -a "$STDERR_LOG"
    exit 1
  fi
fi

_use_fastmcp() {
  [[ -x "$ROOT/node_modules/.bin/fastmcp" ]]
}

start_server() {
  if _use_fastmcp; then
    echo "[mcp] starting fastmcp on ${BIND}:${PORT} profile=${PROFILE}" | tee -a "$STDOUT_LOG"
    "$ROOT/node_modules/.bin/fastmcp" serve \
      --host "$BIND" --port "$PORT" \
      --grace "$GRACE" \
      --quiet >>"$STDOUT_LOG" 2>>"$STDERR_LOG" &
  else
    if [[ "${UCOMM_SECURE_MODE:-0}" = "1" ]]; then
      echo "[mcp] SECURE_MODE=1 で実サーバ不在 → 起動中止" | tee -a "$STDERR_LOG"
      return 2
    fi
    echo "[mcp] fastmcp未検出 → CI用スタブHTTPを起動 (${BIND}:${PORT})" | tee -a "$STDOUT_LOG"
    # /ready と /health に200を返す最小スタブ（CI専用）
    node -e "require('http').createServer((req,res)=>{res.statusCode= (req.url==='/ready'||req.url==='/health')?200:404;res.end('ok');}).listen(${PORT},'${BIND}');" \
      >>"$STDOUT_LOG" 2>>"$STDERR_LOG" &
  fi
  echo $! > "$PID_FILE"
}

stop_server() {
  if [[ -f "$PID_FILE" ]]; then
    local pid="$(cat "$PID_FILE" || true)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "[mcp] SIGTERM to ${pid} (grace=${GRACE}s)" | tee -a "$STDOUT_LOG"
      kill -TERM "$pid" || true
      timeout "${GRACE}" bash -c "while kill -0 $pid 2>/dev/null; do sleep 0.1; done" || true
      if kill -0 "$pid" 2>/dev/null; then
        echo "[mcp] SIGKILL to ${pid}" | tee -a "$STDERR_LOG"
        kill -KILL "$pid" || true
      fi
    fi
    rm -f "$PID_FILE"
  fi
}

trap 'stop_server' EXIT INT TERM

restarts=0
while :; do
  start_server || exit 1
  wait $! || true
  if (( restarts >= MAX_RESTARTS )); then
    echo "[mcp] crashed: exceeded max restarts (${MAX_RESTARTS})." | tee -a "$STDERR_LOG"
    exit 1
  fi
  restarts=$((restarts+1))
  backoff=$((2**(restarts-1))) # 1,2,4
  echo "[mcp] crashed: restart #${restarts} in ${backoff}s" | tee -a "$STDERR_LOG"
  sleep "${backoff}"
done
