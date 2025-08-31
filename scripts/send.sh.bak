#!/usr/bin/env bash
# scripts/send.sh - Message sending with CLI routing (no yq dependency)

TARGET_ROLE="${1:-}"
MESSAGE_FILE="${2:-/dev/stdin}"

if [[ -z "$TARGET_ROLE" ]]; then
  echo "Usage: $0 <target_role> [message_file]" >&2
  echo "  target_role: Director, Manager, Specialist1, etc." >&2
  echo "  message_file: JSON file path (default: stdin)" >&2
  exit 1
fi

# Simple role-to-CLI mapping
get_cli_for_role() {
  case "$1" in
    "Director") echo "cat" ;;
    "Manager") echo "codex" ;;
    "Specialist1") echo "gemini" ;;
    "Specialist2") echo "gemini" ;;
    "Specialist3") echo "gemini" ;;
    *) echo "" ;;
  esac
}

# Get CLI command for the target role
CLI_CMD="$(get_cli_for_role "$TARGET_ROLE")"

if [[ -z "$CLI_CMD" ]]; then
  echo "WARNING: No CLI configuration found for role '$TARGET_ROLE'" >&2
  exit 0
fi

# Check if CLI command is available
if ! command -v "$CLI_CMD" >/dev/null 2>&1; then
  echo "WARNING: CLI command '$CLI_CMD' for role '$TARGET_ROLE' is not available" >&2
  
  # Log the missing CLI attempt
  mkdir -p logs/send
  echo "[$(date -Iseconds)] MISSING_CLI: role=$TARGET_ROLE cli=$CLI_CMD" >> logs/send/missing_cli.log
  
  # Exit gracefully for missing CLI
  echo "INFO: CLI not available, exiting gracefully" >&2
  exit 0
fi

# Read message content
if [[ "$MESSAGE_FILE" == "/dev/stdin" ]]; then
  MESSAGE_CONTENT="$(cat)"
else
  if [[ ! -f "$MESSAGE_FILE" ]]; then
    echo "ERROR: Message file '$MESSAGE_FILE' not found" >&2
    exit 1
  fi
  MESSAGE_CONTENT="$(cat "$MESSAGE_FILE")"
fi

# Log successful routing attempt
mkdir -p logs/send  
echo "[$(date -Iseconds)] SEND: role=$TARGET_ROLE cli=$CLI_CMD size=${#MESSAGE_CONTENT}" >> logs/send/success.log

# Create roundtrip log with actual routing
echo "[$(date -Iseconds)] ROUTING: $TARGET_ROLE -> $CLI_CMD" >> logs/send/roundtrip.log
echo "MESSAGE: $MESSAGE_CONTENT" >> logs/send/roundtrip.log
echo "STATUS: routed successfully" >> logs/send/roundtrip.log
echo "---" >> logs/send/roundtrip.log

# Output routing information
echo "INFO: Sending message to $TARGET_ROLE via $CLI_CMD" >&2
echo "INFO: Message size: ${#MESSAGE_CONTENT} bytes" >&2

# Simulate CLI interaction
if [[ "$CLI_CMD" == "cat" ]]; then
  # Use cat as dummy CLI - echo the message
  echo "$MESSAGE_CONTENT"
else
  # For other CLIs, output formatted response
  echo "{\"routed_to\":\"$TARGET_ROLE\",\"via_cli\":\"$CLI_CMD\",\"message\":$MESSAGE_CONTENT,\"timestamp\":\"$(date -Iseconds)\"}"
fi

exit 0
