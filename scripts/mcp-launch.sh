#!/usr/bin/env bash
# scripts/mcp-launch.sh - MCP HTTP stub with noise reduction
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MCP_HOST="${MCP_HOST:-127.0.0.1}"
MCP_PORT="${MCP_PORT:-39200}"
MCP_PID_FILE="$ROOT/.mcp.pid"
MCP_LOG_FILE="$ROOT/logs/mcp/server.log"

check_mcp_http() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsS "http://$MCP_HOST:$MCP_PORT/ready"  --max-time 2 >/dev/null 2>&1 && \
    curl -fsS "http://$MCP_HOST:$MCP_PORT/health" --max-time 2 >/dev/null 2>&1
  else
    return 1
  fi
}

case "${1:-help}" in
  start)
    # SECURE_MODE=1: スタブ抑止（本番想定）
    if [[ "${UCOMM_SECURE_MODE:-0}" == "1" ]]; then
      echo "SECURE_MODE=1: HTTP stub disabled (production mode)"; exit 0
    fi
    # 既にHTTP upなら何もしない
    if check_mcp_http; then
      echo "MCP already up (HTTP 200 OK)"; exit 0
    fi
    # ステールPID整理
    if [[ -f "$MCP_PID_FILE" ]]; then
      old_pid="$(cat "$MCP_PID_FILE" 2>/dev/null || true)"
      if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
        echo "MCP stub running (PID=$old_pid)"; exit 0
      else
        rm -f "$MCP_PID_FILE"
      fi
    fi
    # HTTPスタブ起動
    mkdir -p "$(dirname "$MCP_LOG_FILE")"
    cat > /tmp/mcp-stub.js << 'NODEEOF'
const http = require('http');
const host = process.argv[2] || '127.0.0.1';
const port = parseInt(process.argv[3] || '39200');
const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  if (req.url === '/ready' || req.url === '/health') {
    res.statusCode = 200;
    res.end(JSON.stringify({ status: 'ok', timestamp: new Date().toISOString(), version: '1.0.0-stub' }));
  } else {
    res.statusCode = 404;
    res.end(JSON.stringify({ error: 'Not Found', message: 'This is a minimal MCP HTTP stub' }));
  }
});
server.listen(port, host, () => { console.log(`MCP HTTP stub listening on ${host}:${port}`); });
process.on('SIGTERM', () => { console.log('MCP stub shutting down...'); server.close(() => { process.exit(0); }); });
NODEEOF
    node /tmp/mcp-stub.js "$MCP_HOST" "$MCP_PORT" >> "$MCP_LOG_FILE" 2>&1 &
    echo $! > "$MCP_PID_FILE"
    rm -f /tmp/mcp-stub.js
    sleep 1
    if check_mcp_http; then echo "MCP HTTP endpoints verified"; else echo "Warning: MCP endpoints not ready yet"; fi
    ;;
  stop)
    stopped=false
    if [[ -f "$MCP_PID_FILE" ]]; then
      pid="$(cat "$MCP_PID_FILE" 2>/dev/null || true)"
      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null && stopped=true
        sleep 1
        kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null && stopped=true
      fi
      rm -f "$MCP_PID_FILE"
    fi
    if ! $stopped && command -v lsof >/dev/null 2>&1; then
      port_pid=$(lsof -ti :$MCP_PORT 2>/dev/null | head -1 || true)
      [[ -n "$port_pid" ]] && kill -TERM "$port_pid" 2>/dev/null && stopped=true
    fi
    $stopped && echo "MCP stopped" || echo "MCP not running"
    ;;
  status)
    if check_mcp_http; then
      echo "MCP: up (HTTP endpoints responding)"
      [[ -f "$MCP_PID_FILE" ]] && pid="$(cat "$MCP_PID_FILE" 2>/dev/null || true)" && [[ -n "$pid" ]] && echo "PID: $pid" || true
    else
      echo "MCP: down (HTTP endpoints not responding)"
      if [[ -f "$MCP_PID_FILE" ]]; then
        pid="$(cat "$MCP_PID_FILE" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
          echo "Warning: process alive (PID=$pid) but HTTP down"
        else
          rm -f "$MCP_PID_FILE"
        fi
      fi
    fi
    ;;
  *)
    echo "Usage: $0 {start|stop|status}"
    echo "Env: MCP_HOST=$MCP_HOST MCP_PORT=$MCP_PORT  Logs: $MCP_LOG_FILE"
    exit 1
    ;;
esac
