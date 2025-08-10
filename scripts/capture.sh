#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

YAML="config/topology.yaml"
STAMP="$(date +%F)"
OUT="logs/${STAMP}"
mkdir -p "$OUT"

yq -r '
  .sessions[] as $s
  | $s.windows[] as $w
  | ($w.panes | to_entries[])
  | "\(.value.role)|\($s.name)|\($w.name)|\(.key)"
' "$YAML" \
| while IFS='|' read -r role sess win idx; do
  pid="$(tmux list-panes -t "${sess}:${win}" -F '#{pane_index} #{pane_id}' 2>/dev/null | awk -v i="$idx" '$1==i{print $2; exit}')"
  if [[ -z "${pid:-}" ]]; then
    echo "[warn] skip ${role}: pane not found"
    continue
  fi
  tmux capture-pane -epJ -t "$pid" > "${OUT}/${role}.log" || true
  echo "[ok] captured ${role} -> ${OUT}/${role}.log"
done
