#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# ==== 設定・共通 ====
YQ="${YQ_BIN:-yq}"
TMUX="${TMUX_BIN:-tmux}"
DATE_DIR="$(date +%F)"

# modes.active を YAML から取得（なければ HIERARCHY）
MODE="$($YQ -r '.modes.active // "HIERARCHY"' config/topology.yaml 2>/dev/null || echo HIERARCHY)"
OUT_DIR="$ROOT/logs/${MODE}/${DATE_DIR}"
mkdir -p "$OUT_DIR"

# 役割名と CLI をトポロジから抽出（全 panes）
# 出力: role<TAB>session<TAB>window<TAB>title<TAB>cli
mapfile -t ROWS < <(
  $YQ -r '
    .sessions[] as $s |
    $s.name as $sname |
    $s.windows[] as $w |
    $w.name as $wname |
    $w.panes[] |
    .role as $role |
    .title as $title |
    .cli as $cli |
    [$role, $sname, $wname, ($title // ""), $cli] | @tsv
  ' config/topology.yaml
)

# tmuxセッションが無ければ終了
if ! $TMUX ls >/dev/null 2>&1; then
  echo "[warn] no tmux session found; nothing to capture" >&2
  exit 0
fi

ok=0; skip=0
for row in "${ROWS[@]}"; do
  IFS=$'\t' read -r role sname wname title cli <<<"$row"

  # 対象ウィンドウの pane_id を取得（該当セッション/ウィンドウが無い場合はskip）
  if ! $TMUX list-windows -t "$sname" >/dev/null 2>&1; then
    echo "[warn] skip $role: session not found ($sname)"
    ((skip++)) || true
    continue
  fi
  # window index を探す（名前一致）
  widx="$($TMUX list-windows -t "$sname" -F '#{window_index} #{window_name}' | awk -v W="$wname" '$2==W{print $1; exit}')"
  if [[ -z "${widx:-}" ]]; then
    echo "[warn] skip $role: window not found ($sname/$wname)"
    ((skip++)) || true
    continue
  fi
  # 最初のpane idを取得（複数paneでも代表1つをキャプチャ対象にする）
  pane_id="$($TMUX list-panes -t "${sname}:${widx}" -F '#{pane_id}' | head -n1)"
  if [[ -z "${pane_id:-}" ]]; then
    echo "[warn] skip $role: pane not found ($sname/$wname)"
    ((skip++)) || true
    continue
  fi

  # ログ採取（tmux capture-pane）
  out="$OUT_DIR/${role}.log"
  if $TMUX capture-pane -p -t "$pane_id" > "$out" 2>/dev/null; then
    echo "[ok] captured: $out"
    ((ok++)) || true
  else
    echo "[warn] skip $role: capture-pane failed ($pane_id)"
    ((skip++)) || true
  fi
done

# 統計
if (( ok > 0 )); then
  exit 0
else
  exit 2
fi
