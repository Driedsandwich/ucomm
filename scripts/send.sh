#!/usr/bin/env bash
# scripts/send.sh - Message sending with missing CLI handling policy  
set -Eeuo pipefail

TARGET_ROLE="${1:-}"
MESSAGE_FILE="${2:-/dev/stdin}"

if [[ -z "$TARGET_ROLE" ]]; then
  echo "Usage: $0 <target_role> [message_file]" >&2
  echo "  target_role: Director, Manager, Specialist1, etc." >&2
  exit 1
fi

# Read configuration  
CLI_CMD=""
if [[ -f "config/topology.yaml" ]] && command -v yq >/dev/null 2>&1; then
  CLI_CMD="$(yq -r ".sessions[].windows[].panes | to_entries[] | select(.value.role == \"$TARGET_ROLE\") | .value.cli" config/topology.yaml 2>/dev/null | head -1)"
fi

if [[ -z "$CLI_CMD" || "$CLI_CMD" == "null" ]]; then
  echo "WARNING: No CLI configuration found for role '$TARGET_ROLE'" >&2
  if [[ "${UCOMM_FAIL_ON_MISSING_CLI:-0}" == "1" ]]; then
    echo "ERROR: UCOMM_FAIL_ON_MISSING_CLI=1, aborting on missing CLI" >&2
    exit 1
  else
    echo "INFO: Continuing with default policy (fail_on_missing=false)" >&2
    exit 0
  fi
fi

# Check if CLI command is available
if ! command -v "$CLI_CMD" >/dev/null 2>&1; then
  echo "WARNING: CLI command '$CLI_CMD' for role '$TARGET_ROLE' is not available" >&2
  mkdir -p logs/send
  echo "[$(date -Iseconds)] MISSING_CLI: role=$TARGET_ROLE cli=$CLI_CMD" >> logs/send/missing_cli.log
  if [[ "${UCOMM_FAIL_ON_MISSING_CLI:-0}" == "1" ]]; then
    echo "ERROR: UCOMM_FAIL_ON_MISSING_CLI=1, aborting on unavailable CLI" >&2
    exit 1
  else
    echo "INFO: CLI not available, exiting gracefully (exit 0)" >&2
    exit 0
  fi
fi

# Read and validate message
MESSAGE_CONTENT="$(cat)"
mkdir -p logs/send  
echo "[$(date -Iseconds)] SEND: role=$TARGET_ROLE cli=$CLI_CMD size=${#MESSAGE_CONTENT}" >> logs/send/success.log
echo "INFO: Sending message to $TARGET_ROLE via $CLI_CMD" >&2
echo "MESSAGE_ROUTED_TO_$TARGET_ROLE: $MESSAGE_CONTENT"
exit 0
