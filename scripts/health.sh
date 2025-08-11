#!/usr/bin/env bash
# health.sh v1.1
# - 既存のプレーン出力に加え、--json で機械可読を返す
set -euo pipefail
cd "$(dirname "$0")/.."

YAML="config/topology.yaml"
ok=0; ng=0

JSON="false"
if [[ "${1:-}" == "--json" ]]; then
  JSON="true"
fi

have(){ command -v "$1" >/dev/null 2>&1; }

# JSON 集計用
deps_json=()
sessions_json=()
panes_json=()
proc_json=""

# 1) 基本依存
for c in tmux yq ps awk; do
  if have "$c"; then
    echo "[ok] dep: $c"; ((ok+=1)); deps_json+=("{\"name\":\"$c\",\"ok\":true}")
  else
    echo "[ng] dep: $c missing"; ((ng+=1)); deps_json+=("{\"name\":\"$c\",\"ok\":false}")
  fi
done

# 2) セッション存在
while read -r s; do
  if tmux has-session -t "$s" 2>/dev/null; then
    echo "[ok] session: $s"; ((ok+=1)); sessions_json+=("{\"name\":\"$s\",\"ok\":true}")
  else
    echo "[ng] session: $s (not found)"; ((ng+=1)); sessions_json+=("{\"name\":\"$s\",\"ok\":false}")
  fi
done < <(yq -r '.sessions[].name' "$YAML")

# 3) ペイン構成 & pane_id の取得
while IFS='|' read -r role sess win idx; do
  pid="$(tmux list-panes -t "${sess}:${win}" -F '#{pane_index} #{pane_id}' 2>/dev/null | awk -v i="$idx" '$1==i{print $2; exit}')"
  if [[ -n "${pid:-}" ]]; then
    echo "[ok] pane: ${sess}:${win} idx=${idx} (${role}) id=${pid}"; ((ok+=1))
    panes_json+=("{\"role\":\"$role\",\"session\":\"$sess\",\"window\":\"$win\",\"index\":$idx,\"ok\":true}")
  else
    echo "[ng] pane: ${sess}:${win} idx=${idx} (${role}) not found"; ((ng+=1))
    panes_json+=("{\"role\":\"$role\",\"session\":\"$sess\",\"window\":\"$win\",\"index\":$idx,\"ok\":false}")
  fi
done < <(yq -r '
  .sessions[] as $s
  | $s.windows[] as $w
  | ($w.panes | to_entries[])
  | "\(.value.role)|\($s.name)|\($w.name)|\(.key)"
' "$YAML")

# 4) CLIプロセス（ざっくり存在チェック）
pats='gemini|codex|ccc|cursor'
if ps aux | grep -Ei "$pats" | grep -v grep >/dev/null; then
  echo "[ok] cli-process: one or more matched ($pats)"; ((ok+=1))
  proc_json="{\"matched\":true,\"pattern\":\"$pats\"}"
else
  echo "[ng] cli-process: none matched ($pats)"; ((ng+=1))
  proc_json="{\"matched\":false,\"pattern\":\"$pats\"}"
fi

# --json 指定時はここで JSON を返す
if [[ "$JSON" == "true" ]]; then
  printf '%s\n' "{
  \"summary\": {\"ok\": $ok, \"ng\": $ng},
  \"deps\": [$(IFS=,; printf '%s' "${deps_json[*]-}")],
  \"sessions\": [$(IFS=,; printf '%s' "${sessions_json[*]-}")],
  \"panes\": [$(IFS=,; printf '%s' "${panes_json[*]-}")],
  \"process\": ${proc_json:-null}
}"
  exit 0
fi

echo "---"
echo "[summary] ok=$ok ng=$ng"
exit 0
