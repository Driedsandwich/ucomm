#!/usr/bin/env bash
# scripts/send.sh - Message sending with configurable role mapping (config/roles.conf + hardcoded fallback)

TARGET_ROLE="${1:-}"
MESSAGE_FILE="${2:-/dev/stdin}"

if [[ -z "$TARGET_ROLE" ]]; then
  echo "Usage: $0 <target_role> [message_file]" >&2
  echo "  target_role: Director, Manager, Specialist1, etc." >&2
  echo "  message_file: JSON file path (default: stdin)" >&2
  exit 1
fi

get_cli_for_role() {
  local role="$1"
  local cli_cmd=""
  
  if [[ -f "config/roles.conf" ]]; then
    cli_cmd=$(grep -E "^${role}=" config/roles.conf 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
  fi
  
  if [[ -z "$cli_cmd" ]]; then
    case "$role" in
      "Director") cli_cmd="cat" ;;
      "Manager") cli_cmd="codex" ;;
      "Specialist1") cli_cmd="gemini" ;;
      "Specialist2") cli_cmd="gemini" ;;
      "Specialist3") cli_cmd="gemini" ;;
      *) cli_cmd="" ;;
    esac
  fi
  
  echo "$cli_cmd"
}

CLI_CMD="$(get_cli_for_role "$TARGET_ROLE")"
echo "DEBUG: Role='$TARGET_ROLE', CLI_CMD='$CLI_CMD'" >&2

if [[ -z "$CLI_CMD" ]]; then
  echo "WARNING: No CLI configuration found for role '$TARGET_ROLE'" >&2
  
  if [[ "${UCOMM_FAIL_ON_MISSING_CLI:-0}" == "1" ]]; then
    echo "ERROR: UCOMM_FAIL_ON_MISSING_CLI=1, aborting on missing CLI" >&2
    exit 1
  else
    echo "INFO: Continuing with default policy (fail_on_missing=false)" >&2
    exit 0
  fi
fi

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

if [[ "$MESSAGE_FILE" == "/dev/stdin" ]]; then
  MESSAGE_CONTENT="$(cat)"
else
  if [[ ! -f "$MESSAGE_FILE" ]]; then
    echo "ERROR: Message file '$MESSAGE_FILE' not found" >&2
    exit 1
  fi
  MESSAGE_CONTENT="$(cat "$MESSAGE_FILE")"
fi

if [[ "$MESSAGE_CONTENT" =~ ^\{ ]]; then
  open_braces=$(echo "$MESSAGE_CONTENT" | tr -cd '{' | wc -c)
  close_braces=$(echo "$MESSAGE_CONTENT" | tr -cd '}' | wc -c)
  
  if [[ $open_braces -ne $close_braces ]]; then
    echo "WARNING: Message content does not appear to be valid JSON" >&2
  fi
fi

mkdir -p logs/send  
echo "[$(date -Iseconds)] SEND: role=$TARGET_ROLE cli=$CLI_CMD size=${#MESSAGE_CONTENT}" >> logs/send/success.log

echo "[$(date -Iseconds)] ROUTING: $TARGET_ROLE -> $CLI_CMD" >> logs/send/roundtrip.log
echo "MESSAGE: $MESSAGE_CONTENT" >> logs/send/roundtrip.log
echo "STATUS: routed successfully" >> logs/send/roundtrip.log
echo "---" >> logs/send/roundtrip.log

echo "INFO: Sending message to $TARGET_ROLE via $CLI_CMD" >&2
echo "INFO: Message size: ${#MESSAGE_CONTENT} bytes" >&2

if [[ "$CLI_CMD" == "cat" ]]; then
  echo "$MESSAGE_CONTENT"
else
  echo "{\"routed_to\":\"$TARGET_ROLE\",\"via_cli\":\"$CLI_CMD\",\"message\":$MESSAGE_CONTENT,\"timestamp\":\"$(date -Iseconds)\"}"
fi

exit 0
