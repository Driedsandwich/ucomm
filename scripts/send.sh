#!/usr/bin/env bash
# send.sh v1.0 (yq v4 only, no awk, title-independent)
# - YAML -> 一覧を yq で出力（role, session, window, index）
# - 役割解決は Bash 側で小文字比較
# - tmux pane は pane_index から pane_id を取得して送信
set -euo pipefail
cd "$(dirname "$0")/.."

YAML="config/topology.yaml"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "[send] missing: $1"; exit 1; }; }
need tmux
need yq

usage(){ cat <<USAGE
Usage:
  send.sh --to <role> --text "message"
  send.sh --to <role> --file path.md
  send.sh --broadcast "<substring>" --text "message"
  send.sh --to <role> --resend
Notes:
  - <role> は YAML の role 名（例: Manager, Specialist2）。大文字小文字は無視。
  - broadcast は role 名の部分一致（例: "Specialist"）。
USAGE
exit 1; }

# --- 引数
TO=""; TEXT=""; FILE=""; BCAST=""; RESEND="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --to) TO="$2"; shift 2;;
    --text) TEXT="$2"; shift 2;;
    --file) FILE="$2"; shift 2;;
    --broadcast) BCAST="$2"; shift 2;;
    --resend) RESEND="true"; shift 1;;
    -h|--help) usage;;
    *) echo "[send] unknown arg: $1"; usage;;
  esac
done

# --- 一覧を yq で出す（タブ区切り）
# 出力: role \t session \t window \t index
list_all() {
  yq -r '
    .sessions[] as $s
    | $s.windows[] as $w
    | ($w.panes | to_entries[])
    | "\(.value.role)|\($s.name)|\($w.name)|\(.key)"
  ' "$YAML"
}

# --- pane_index から pane_id を取得
pane_id_from(){ # $1=session $2=window $3=index
  tmux list-panes -t "$1:$2" -F '#{pane_index} #{pane_id}' \
    | while read -r idx pid; do
        [[ "$idx" == "$3" ]] && { echo "$pid"; break; }
      done
}

send_text(){ tmux set-buffer -- "$2"; tmux paste-buffer -t "$1"; tmux send-keys -t "$1" Enter; }
send_file(){ tmux load-buffer -- "$2"; tmux paste-buffer -t "$1"; tmux send-keys -t "$1" Enter; }

mkdir -p state
lower(){ printf "%s" "$1" | tr '[:upper:]' '[:lower:]'; }

# --- Broadcast: role名 部分一致（Bashで小文字比較）
if [[ -n "$BCAST" ]]; then
  sub_lc="$(lower "$BCAST")"
  while IFS='|' read -r role sess win idx; do
    [[ -n "$role" ]] || continue
    role_lc="$(lower "$role")"
    [[ "$role_lc" == *"$sub_lc"* ]] || continue
    pid="$(pane_id_from "$sess" "$win" "$idx" || true)"
    [[ -n "$pid" ]] || { echo "[send] pane not found for $role"; continue; }
    if [[ "$RESEND" == "true" ]]; then
      [[ -f "state/last_$pid.txt" ]] || { echo "[send] no last message for $role"; continue; }
      send_text "$pid" "$(cat "state/last_$pid.txt")"; echo "[resent] $role"; continue
    fi
    if   [[ -n "$FILE" ]] ; then send_file "$pid" "$FILE"; echo "[file] $FILE -> $role"
    elif [[ -n "$TEXT" ]] ; then echo "$TEXT" > "state/last_$pid.txt"; send_text "$pid" "$TEXT"; echo "[text] -> $role"
    else echo "[send] nothing to send"; exit 1; fi
  done < <(list_all)
  exit 0
fi

# --- 単一宛先: role名 完全一致（Bashで小文字比較）
[[ -n "$TO" ]] || usage
want_lc="$(lower "$TO")"
line=""
while IFS='|' read -r role sess win idx; do
  [[ -n "$role" ]] || continue
  role_lc="$(lower "$role")"
  if [[ "$role_lc" == "$want_lc" ]]; then
    line="${role}|${sess}|${win}|${idx}"
    break
  fi
done < <(list_all)

[[ -n "$line" ]] || { echo "[send] unknown role: $TO"; exit 1; }

role="$(printf "%s" "$line" | cut -d'|' -f1)"
sess="$(printf "%s" "$line" | cut -d'|' -f2)"
win="$( printf "%s" "$line" | cut -d'|' -f3)"
idx="$( printf "%s" "$line" | cut -d'|' -f4)"

pid="$(pane_id_from "$sess" "$win" "$idx" || true)"
[[ -n "$pid" ]] || { echo "[send] pane not found for role '$TO'"; exit 1; }

if [[ "$RESEND" == "true" ]]; then
  [[ -f "state/last_$pid.txt" ]] || { echo "[send] no last message for $TO"; exit 1; }
  send_text "$pid" "$(cat "state/last_$pid.txt")"; echo "[resent] $TO"; exit 0
fi

if   [[ -n "$FILE" ]] ; then send_file "$pid" "$FILE"; echo "[file] $FILE -> $TO"
elif [[ -n "$TEXT" ]] ; then echo "$TEXT" > "state/last_$pid.txt"; send_text "$pid" "$TEXT"; echo "[text] -> $TO"
else echo "[send] nothing to send"; exit 1; fi
