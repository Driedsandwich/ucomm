#!/usr/bin/env bash
set +e
export UCOMM_SECURE_MODE=1
scripts/ucomm-launch.sh start
exit_code=$?
echo "exit_code=$exit_code"
set -e
