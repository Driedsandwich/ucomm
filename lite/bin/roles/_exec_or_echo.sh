#!/usr/bin/env bash
set -euo pipefail
role="$1"; shift || true
cmd="$1"; shift || true
if command -v "$cmd" >/dev/null 2>&1; then
  exec "$cmd" "$@"
else
  echo "[$role] command '$cmd' not found; echo-mode. Ctrl-C to exit."
  while IFS= read -r line; do echo "[$role] $line"; done
fi