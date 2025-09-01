#!/usr/bin/env bash
set -euo pipefail
DATE="${1:-$(date +%F)}"
MODE="${2:-local}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT/logs/$MODE/$DATE"
OUT_DIR="$ROOT/reports/minutes/$DATE"
OUT="$OUT_DIR/$MODE.md"
mkdir -p "$OUT_DIR"

# ログ存在チェック
if ! ls "$SRC_DIR"/*.log >/dev/null 2>&1; then
  echo "No logs in $SRC_DIR" >&2; exit 1
fi

# 「メッセージ列だけ」マスクしてから TSV を awk に渡す
masked_ts=$(mktemp)
while IFS=$'\t' read -r ts role msg; do
  masked_msg="$(printf '%s' "$msg" | scripts/lib/mask.sh)"
  printf '%s\t%s\t%s\n' "$ts" "$role" "$masked_msg"
done < <(cat "$SRC_DIR"/*.log) > "$masked_ts"

awk -F'\t' -v DATE="$DATE" -v MODE="$MODE" '
BEGIN{
  print "# Minutes (" DATE " / " MODE ")\n## 概要"
}
{
  ts=$1; role=$2; msg=$3;
  roles[role]++
  if (match(msg, /^\[#topic\]/)) topics[++t]=msg
  if (match(msg, /^(決定:|\[DECISION\])/)) decisions[++d]=msg
  if (match(msg, /^(TODO:|@[^ ]+:)/)) todos[++u]=msg
  last[NR]=ts "\t" role "\t" msg
}
END{
  # 概要
  printf("- ロール:"); for (r in roles) printf("  %s(%d)", r, roles[r]); print "\n"

  # 議題
  if (t>0) { print "## 議題"; for(i=1;i<=t;i++) print "- " topics[i] }

  # 論点（PoC簡易）
  print "## 論点"; print "- (PoC) 簡易抽出"

  # 決定事項
  if (d>0) { print "## 決定事項"; for(i=1;i<=d;i++) print "- " decisions[i] }

  # TODO
  if (u>0) { print "## TODO"; for(i=1;i<=u;i++) print "- " todos[i] }

  # 参考ログ（末尾5行）
  print "## 参考ログ"
  N=5
  start=(NR>N)? NR-N+1 : 1
  for(i=start;i<=NR;i++) print "> " last[i]
}
' "$masked_ts" > "$OUT"

rm -f "$masked_ts"
echo "Wrote $OUT"
