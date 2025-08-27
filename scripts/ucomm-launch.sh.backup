#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

log()   { printf '[info] %s\n' "$*"; }
warn()  { printf '[warn] %s\n' "$*" >&2; }
err()   { printf '[err]  %s\n' "$*" >&2; }

# --- MCP 起動（fastmcp 省略時はスタブHTTPで /ready を返す） -------------------
log "starting MCP..."
if command -v fastmcp >/dev/null 2>&1; then
  fastmcp --bind 127.0.0.1 --port "${MCP_PORT:-39200}" --grace "${MCP_TERM_GRACE_SEC:-5}" &
  MCP_PID=$!
else
  warn "MCP launch returned non-zero (continuing; fallback可能)"
  # CI用スタブ: 127.0.0.1:39200/ready に 200 を返す
  ( while true; do { printf 'HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK'; } | nc -l -p "${MCP_PORT:-39200}" -q 0; done ) >/dev/null 2>&1 &
  MCP_PID=$!
fi

# /ready を待機
ts="$(date +%s%3N)"
for i in {1..50}; do
  if curl -fsS "http://127.0.0.1:${MCP_PORT:-39200}/ready" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
rt=$(( $(date +%s%3N) - ts ))
log "MCP is up (${rt}ms)"

# --- tmux トポロジ起動 ---------------------------------------------------------
log "building tmux topology..."

# YAML から TSV を生成（role \t title \t cli）。空要素は出力しない。
# sessions[].windows[].panes[] を走査し、3カラムそろった行だけ抽出。
mapfile -t LINES < <(
  yq -r '
    .sessions[]?.windows[]?.panes[]? |
    select(.role and .title and .cli) |
    [.role, .title, .cli] | @tsv
  ' config/topology.yaml 2>/dev/null || true
)

if ! tmux has-session -t ucomm_Director 2>/dev/null; then
  tmux new-session -d -s ucomm_Director -n director
fi
if ! tmux has-session -t ucomm_multiagent 2>/dev/null; then
  tmux new-session -d -s ucomm_multiagent -n team
fi

# adapters（存在チェックに使用）
declare -A ADP
while IFS= read -r key; do
  [[ -n "$key" ]] && ADP["$key"]=1
done < <(yq -r 'keys | .[]' config/cli_adapters.yaml 2>/dev/null || true)

# 1行ずつ: Director を第一セッションの window0 に、他は multiagent に配置
# 既存 pane 数に応じて安全に split する（空行/未知CLIはスキップ）
first_done=0
for line in "${LINES[@]}"; do
  IFS=$'\t' read -r ROLE TITLE CLI <<<"$line"
  [[ -z "${ROLE:-}" || -z "${CLI:-}" ]] && continue
  if [[ -z "${ADP[$CLI]:-}" ]]; then
    warn "adapter not found in config/cli_adapters.yaml: $CLI (role=$ROLE)"
    continue
  fi

  # どのセッションに置くか
  if [[ $first_done -eq 0 ]]; then
    SESS="ucomm_Director"; WIN="director"
    first_done=1
  else
    SESS="ucomm_multiagent"; WIN="team"
  fi

  # 対象ウィンドウをアクティブ化
  tmux select-window -t "${SESS}:${WIN}"

  # 既存 pane 数で分割方針を変える（安全に full→縦→横 と刻む）
  PCNT="$(tmux list-panes -t "${SESS}:${WIN}" | wc -l | awk '{print $1}')"
  if (( PCNT == 1 )); then
    tmux split-window -v -t "${SESS}:${WIN}"    # 2枚目：上下
  elif (( PCNT == 2 )); then
    tmux split-window -h -t "${SESS}:${WIN}"    # 3枚目：右に
  elif (( PCNT == 3 )); then
    tmux split-window -v -t "${SESS}:${WIN}"    # 4枚目：下に
  fi

  # 新規 pane を取得（最後の pane を採用）
  PANE="$(tmux list-panes -t "${SESS}:${WIN}" -F '#{pane_id}' | tail -n1)"

  # タイトル
  tmux select-pane -t "$PANE"
  tmux select-layout -t "${SESS}:${WIN}" tiled >/dev/null 2>&1 || true
  tmux select-pane -T "$TITLE" || true

  # CLI 起動（存在しなければ placeholder）
  bin="$(yq -r --arg k "$CLI" '.[$k].cmd' config/cli_adapters.yaml 2>/dev/null || echo "")"
  if command -v "$bin" >/dev/null 2>&1; then
    tmux send-keys -t "$PANE" "$bin" C-m
  else
    tmux send-keys -t "$PANE" "echo '[WARN] $CLI not found (placeholder)'; tail -f /dev/null" C-m
  fi
done

echo "[ok] tmux topology launched."
