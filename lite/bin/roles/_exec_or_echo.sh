#!/usr/bin/env bash
set -euo pipefail

if [[ ${#} -eq 0 ]]; then
  echo "usage: _exec_or_echo.sh CMD [ARGS...]"
  exit 2
fi

cmd="$1"; shift || true
if command -v "$cmd" >/dev/null 2>&1; then
  "$cmd" "$@"
else
  # echo-mode fallback
  echo "[echo-mode] $cmd $*"
fi