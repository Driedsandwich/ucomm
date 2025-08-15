#!/usr/bin/env bash
# ucomm-launch.sh - Phase 4 対応版
# - 起動順: MCP -> MCP /health 待ち合わせ -> tmux構築 -> CLI起動 -> 初期投入
# - missing CLI は placeholder で維持（ただし SECURE_MODE=1 は即停止）
# - topology.yaml / cli_adapters.yaml を参照
set -euo pipefail
cd "$(dirname "$0")/.."

YAML_TOPO="config/topology.yaml"
YAML_ADAPTERS="config/cli_adapters.yaml"

: "${UCOMM_FAIL_ON_MISSING_CLI:=0}"
: "${UCOMM_SECURE_MODE:=0}"
: "${MCP_BIND:=127.0.0.1}"
: "${MCP_PORT:=39200}"
: "${UCOMM_MCP_WAIT_MS:=6000}"     # MCP /health の待ち時間上限（ms）
: "${UCOMM_MCP_WAIT_STEP_MS:=200}" # ポーリング間隔（ms）

have(){ command -v "$1" >/dev/null 2>&1; }

# 前提コマンド（curlは待ち合わせで使用。無い場合は警告してスキップ）
for c in tmux yq awk sed; do
  if ! have "$c"; then
    echo "[err] missing dep: $c" >&2; exit 1
  fi
done

# YAML存在チェック（早期に失敗させる）
[[ -f "$YAML_TOPO" ]] || { echo "[err] missing file: $YAML_TOPO"; exit 1; }
[[ -f "$YAML_ADAPTERS" ]] || { echo "[err] missing file: $YAML_ADAPTERS"; exit 1; }

wait_mcp(){
  if ! have curl; then
    echo "[warn] curl not found; skip MCP readiness wait"; return 0
  fi
  local waited=0 step=${UCOMM_MCP_WAIT_STEP_MS}
  while (( waited < UCOMM_MCP_WAIT_MS )); do
    if curl -sSf "http://${MCP_BIND}:${MCP_PORT}/health" -m 1 >/dev/null 2>&1; then
      echo "[info] MCP is up (${waited}ms)"
      return 0
    fi
    # step(ms) -> seconds
    sleep "$(awk "BEGIN{print ${step}/1000}")"
    (( waited += step ))
  done
  echo "[warn] MCP health not confirmed within ${UCOMM_MCP_WAIT_MS}ms; continuing"
  return 0
}

# 1) MCP 起動（HTTP固定・127.0.0.1:39200）
echo "[info] starting MCP..."
scripts/mcp-launch.sh & disown
wait_mcp

# 2) tmux セッション/ウィンドウ/ペイン構築
echo "[info] building tmux topology..."
while read -r sname; do
  tmux has-session -t "$sname" 2>/dev/null || tmux new-session -d -s "$sname" -n main
done < <(yq -r '.sessions[].name' "$YAML_TOPO")

# ウィンドウ作成
yq -r '
  .sessions[] as $s
  | $s.windows[] as $w
  | "\($s.name)|\($w.name)"
' "$YAML_TOPO" | while IFS='|' read -r sname wname; do
  if ! tmux list-windows -t "$sname" -F '#{window_name}' | grep -qx "$wname"; then
    tmux new-window -t "$sname" -n "$wname"
  fi
done

# 3) ペイン作成 & CLI起動
yq -r '
  .sessions[] as $s
  | $s.windows[] as $w
  | ($w.panes | to_entries[])
  | "\($s.name)|\($w.name)|\(.key)|\(.value.role)|\(.value.cli)|\(.value.init_file // "")|\(.value.mcp_profile // "default")"
' "$YAML_TOPO" | while IFS='|' read -r sname wname pidx role cli init_file mcp_profile; do
  # 既存 pane 数確認し、不足分 split
  current=$(tmux list-panes -t "${sname}:${wname}" 2>/dev/null | wc -l | awk '{print $1}')
  want=$((pidx+1))
  while [[ "$current" -lt "$want" ]]; do
    tmux split-pane -t "${sname}:${wname}" -h
    tmux select-layout -t "${sname}:${wname}" tiled >/dev/null 2>&1 || true
    current=$((current+1))
  done

  # pane_id 解決
  pane_id="$(tmux list-panes -t "${sname}:${wname}" -F '#{pane_index} #{pane_id}' | awk -v i="$pidx" '$1==i{print $2; exit}')"
  [[ -n "${pane_id:-}" ]] || { echo "[err] pane id not found ${sname}:${wname}[$pidx]"; exit 1; }

  # CLI アダプタ引き当て（※ adapters 直下キー運用を想定していない構造。トップレベルに CLI 名が並ぶ前提）
  cmd="$(yq -r --arg c "$cli" '.[$c].cmd // ""' "$YAML_ADAPTERS" 2>/dev/null || true)"
  init_mode="$(yq -r --arg c "$cli" '.[$c].init_mode // "stdin"' "$YAML_ADAPTERS" 2>/dev/null || echo stdin)"
  wait_sec="$(yq -r --arg c "$cli" '.[$c].wait_sec // 0' "$YAML_ADAPTERS" 2>/dev/null || echo 0)"
  paste_mode="$(yq -r --arg c "$cli" '.[$c].paste_mode // "tmux-buffer"' "$YAML_ADAPTERS" 2>/dev/null || echo tmux-buffer)"

  # wait_sec 数値正規化（非数/空/null → 0）
  if [[ ! "$wait_sec" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    wait_sec=0
  fi

  # CLI 実体チェック
  bin_ok=0
  if [[ -n "$cmd" ]]; then
    bin="$(echo "$cmd" | awk '{print $1}')"
    if command -v "$bin" >/dev/null 2>&1; then bin_ok=1; fi
  fi

  title="${role}"
  if [[ "$bin_ok" -eq 1 ]]; then
    tmux send-keys -t "$pane_id" C-c "clear" Enter
    tmux send-keys -t "$pane_id" "$cmd" Enter
    # wait_sec > 0 のみ遅延
    if (( $(awk "BEGIN{print ($wait_sec>0)}") )); then
      sleep "$wait_sec"
    fi
  else
    # placeholder か即停止（SECURE_MODE優先）
    title="${role}(missing)"
    msg="${UCOMM_PLACEHOLDER_MSG:-[WARN] ${cli} not found (placeholder mode)}"
    if [[ "$UCOMM_SECURE_MODE" == "1" ]]; then
      echo "[err] SECURE_MODE=1 & missing CLI detected -> abort"; exit 1
    fi
    if [[ "$UCOMM_FAIL_ON_MISSING_CLI" == "1" ]]; then
      echo "[err] FAIL_ON_MISSING_CLI=1 & ${cli} missing -> abort"; exit 1
    fi
    tmux send-keys -t "$pane_id" C-c "clear" Enter
    tmux send-keys -t "$pane_id" "echo '$msg'; tail -f /dev/null" Enter
  fi
  tmux select-pane -T "$title" -t "$pane_id"

  # 初期投入
  if [[ -n "$init_file" && -f "$init_file" && "$bin_ok" -eq 1 ]]; then
    case "$init_mode" in
      stdin)
        if [[ "$paste_mode" == "tmux-buffer" ]]; then
          tmux load-buffer "$init_file"
          tmux paste-buffer -t "$pane_id"
        else
          tmux send-keys -t "$pane_id" "cat \"$init_file\"" Enter
        fi
        ;;
      file)  # 将来: CLIにファイルパスを渡す運用
        tmux send-keys -t "$pane_id" "echo 'init file: $init_file'" Enter
        ;;
      none|*)
        : ;;
    esac
  fi
done

echo "[ok] ucomm-launch completed."
