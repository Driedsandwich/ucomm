#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../_common.sh"
. "$SCRIPT_DIR/_exec_or_echo.sh"
: "${S1_CMD:=claude}"
exec_or_echo "s1" "${S1_CMD}"