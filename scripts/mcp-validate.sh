#!/usr/bin/env bash
set -euo pipefail
schema="schemas/mcp.schema.json"
fail=0
# jq と ajv を使用（ajvはnpxで取得）
if ! command -v jq >/dev/null 2>&1; then echo "jq required"; exit 1; fi
npx --yes ajv-cli@5 validate -s "$schema" -d 'profiles/mcp/**/mcp.json' || fail=1
# 追加のallowlist静的チェック例（過剰権限の目視防止）
if grep -R --line-number -E '"methods"\\s*:\\s*\\[(?:(?!GET).)*\\]' profiles/mcp/; then
  echo "Non-GET methods detected in fetch.methods"; fail=1
fi
exit $fail