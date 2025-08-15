#!/usr/bin/env bash
# capture.sh - Phase 4 ログ運用方針準拠
#  - 出力: logs/<mode>/<YYYY-MM-DD>/<role>.log
#  - 行形式: "YYYY-MM-DD HH:MM:SS\trole\tmessage"
#  - マスキング: keys/tokens/emails
set -euo pipefail
cd "$(dirname "$0")/.."

YAML="config/topology.yaml"
MODE="${UCOMM_MODE:-COUNCIL}"   # 既定は COUNCIL
: "${UCOMM_TZ:=Asia/Tokyo}"
STAMP="$(TZ="$UCOMM_TZ" date +%F)"
OUT_DIR="logs/${MODE}/${STAMP}"
mkdir -p "$OUT_DIR"

mask(){
  sed -E '
    s/(api|key|token|secret|password)[=: ]+[A-Za-z0-9_\-]{8,}/\1=[REDACTED]/Ig;
    s/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,7}/[REDACTED_EMAIL]/g;
  '
}

yq -r '
  .sessions[] as $s
  | $s.windows[] as $w
  | ($w.panes | to_entries[])
  | "\(.value.role)|\($s.name)|\($w.name)|\(.key)"
' "$YAML" | while IFS='|' read -r role sess win idx; do
  pane_id="$(tmux list-panes -t "${sess}:${win}" -F '#{pane_index} #{pane_id}' 2>/dev/null | awk -v i="$idx" '$1==i{print $2; exit}')"
  if [[ -z "${pane_id:-}" ]]; then
    echo "[warn] skip ${role}: pane not found"
    continue
  fi

  tmp="$(mktemp)"
  tmux capture-pane -epJ -t "$pane_id" > "$tmp" || true

  while IFS='' read -r line || [[ -n "$line" ]]; do
    ts="$(TZ="$UCOMM_TZ" date '+%F %T')"
    printf "%s\t%s\t%s\n" "$ts" "$role" "$line"
  done < "$tmp" | mask > "${OUT_DIR}/${role}.log"

  rm -f "$tmp"
  echo "[ok] captured: ${OUT_DIR}/${role}.log"
done
