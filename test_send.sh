#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p logs/send

timestamp=$(date -Iseconds)
echo '{"ping":"pong","ts":"'$timestamp'"}' | scripts/send.sh Director | tee logs/send/roundtrip.log
