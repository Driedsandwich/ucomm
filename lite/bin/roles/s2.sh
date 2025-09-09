#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../_common.sh"
. "$SCRIPT_DIR/_exec_or_echo.sh"
: "${S2_CMD:=codex}"
exec_or_echo "s2" "${S2_CMD}"