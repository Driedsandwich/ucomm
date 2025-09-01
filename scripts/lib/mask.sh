#!/usr/bin/env bash
set -euo pipefail
# email / phone / token（非常に簡易）
sed -E \
  -e "s/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/[REDACTED:EMAIL]/g" \
  -e "s/\+?[0-9][-0-9 ]{8,}[0-9]/[REDACTED:PHONE]/g" \
  -e "s/sk-[A-Za-z0-9]{12,}/[REDACTED:TOKEN]/g"
