#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../_common.sh"
. "$SCRIPT_DIR/_exec_or_echo.sh"
: "${BOSS_CMD:=gemini}"
exec_or_echo "boss" "${BOSS_CMD}"