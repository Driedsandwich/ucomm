#!/usr/bin/env bash
# send.sh v1.2 (yq v4 only, no awk, title-independent)
# - YAML -> 一覧を yq で出力（role, session, window, index）
# - 役割解決は Bash 側で小文字比較
# - tmux pane は pane_index から pane_id を取得して送信
# - retry/interval で保険再送（単一宛先・broadcast 両対応）
# - MODE 解決の優先順位: --mode > env MODE > topology.yaml:modes.active
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
Options:
  --retry <N>            # 既定: 1（失敗時に再送1回）
  --interval <SEC>       # 既定: 2秒
  --mode <HIERARCHY|COUNCIL>
  --quiet                # [mode] 表示を抑止
Notes:
  - <role> は YAML の role 名（例: Manager, Specialist2）。大文字小文字は無視。
  - broadcast は role 名の部分一致（例: "Specialist"）。
  - MODE は --mode > 環境変数 MODE > YAML .modes.active の順で決定。
USAGE
exit 1; }

# --- 引数
TO=""; TEXT=""; FILE=""; BCAST=""; RESEND="false"
RETRY=1
INTERVAL=2
MODE_ARG=""
QUIET="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --to) TO="$2"; shift 2;;
    --text) TEXT="$2"; shift 2;;
    --file) FILE="$2"; shift 2;;
    --broadcast) BCAST="$2"; shift 2;;
    --resend) RESEND="true"; shift 1;;
    --retry) RETRY="$2"; shift 2;;
    --interval) INTERVAL="$2"; shift 2;;
    --mode) MODE_ARG="$2"; shift 2;;
    --quiet) QUIET="true"; shift 1;;
    -h|--help) usage;;
    *) echo "[send] unknown arg: $1"; usage;;
  esac
done

# --- MODE 解決
mode_from_yaml() {
  yq -r '.modes.active // "HIERARCHY"' "$YAML" 2>/dev/null || echo "HIERARCHY"
}
MODE_ACTIVE="$(mode_from_yaml)"
if [[ -n "${MODE:-}" ]]; then MODE_ACTIVE="$MODE"; fi
if [[ -n "$MODE_ARG" ]]; then MODE_ACTIVE="$MODE_ARG"; fi

# 許容モードが YAML にあれば検証（任意）
if yq -e '.modes.allowed' "$YAML" >/dev/null 2>&1; then
  if ! yq -e --arg m "$MODE_ACTIVE" '.modes.allowed[] | select(. == $m)' "$YAML" >/dev/null 2>&1; then
    echo "[warn] MODE '$MODE_ACTIVE' is not in topology.yaml:modes.allowed"
  fi
fi
# 正規化（上書きはしない／表示用）
MODE_ACTIVE_UP="$(printf "%s" "$MODE_ACTIVE" | tr '[:lower:]' '[:upper:]')"
if [[ "$QUIET" != "true" ]]; then
  echo "[mode] $MODE_ACTIVE_UP"
fi

# --- 一覧を yq で出す（| 区切り）
# 出力: role|session|window|index
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

send_once(){  # $1=pane_id, $2="text"|"file", $3=payload
  local pid="$1" kind="$2" payload="$3"
  if [[ "$kind" == "text" ]]; then
    tmux set-buffer -- "$payload"
  else
    tmux load-buffer -- "$payload"
  fi
  tmux paste-buffer -t "$pid"
  tmux send-keys -t "$pid" Enter
}

send_with_retry(){ # $1=pane_id, $2="text"|"file", $3=payload
  local pid="$1" kind="$2" payload="$3"
  local n=0
  while true; do
    if send_once "$pid" "$kind" "$payload"; then
      return 0
    fi
    (( n+=1 ))
    if (( n > RETRY )); then
      return 1
    fi
    sleep "$INTERVAL"
  done
}

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
      if send_with_retry "$pid" "text" "$(cat "state/last_$pid.txt")"; then
        echo "[resent] $role"
      else
        echo "[ng] resend failed -> $role"
      fi
      continue
    fi

    if   [[ -n "$FILE" ]] ; then
      if send_with_retry "$pid" "file" "$FILE"; then
        echo "[file] $FILE -> $role"
      else
        echo "[ng] file failed -> $role"
      fi
    elif [[ -n "$TEXT" ]] ; then
      echo "$TEXT" > "state/last_$pid.txt"
      if send_with_retry "$pid" "text" "$TEXT"; then
        echo "[text] -> $role"
      else
        echo "[ng] text failed -> $role"
      fi
    else
      echo "[send] nothing to send"; exit 1
    fi
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
  if send_with_retry "$pid" "text" "$(cat "state/last_$pid.txt")"; then
    echo "[resent] $TO"
    exit 0
  else
    echo "[ng] resend failed -> $TO"; exit 1
  fi
fi

if   [[ -n "$FILE" ]] ; then
  send_with_retry "$pid" "file" "$FILE" && echo "[file] $FILE -> $TO" || { echo "[ng] file failed -> $TO"; exit 1; }
elif [[ -n "$TEXT" ]] ; then
  echo "$TEXT" > "state/last_$pid.txt"
  send_with_retry "$pid" "text" "$TEXT" && echo "[text] -> $TO" || { echo "[ng] text failed -> $TO"; exit 1; }
else
  echo "[send] nothing to send"; exit 1
fi
