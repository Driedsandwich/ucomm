#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../_common.sh"
. "$SCRIPT_DIR/_exec_or_echo.sh"
: "${S3_CMD:=gemini}"
exec_or_echo "s3" "${S3_CMD}"