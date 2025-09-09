#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../_common.sh"

if [[ -n "${S2_CMD:-}" ]]; then
    "$SCRIPT_DIR/_exec_or_echo.sh" ${S2_CMD}
fi