#!/usr/bin/env bash
# scripts/ucomm-launch.sh - Unified launch sequence for ucomm system
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SECURE_MODE="${1:-${UCOMM_SECURE_MODE:-0}}"
ACTION="${2:-start}"

# SECURE_MODE=1 immediate exit guard
if [[ "${SECURE_MODE:-${UCOMM_SECURE_MODE:-0}}" == "1" ]] && [[ "$ACTION" == "start" || "$ACTION" == "restart" ]]; then
  echo "[prod] SECURE_MODE=1 - exiting immediately for manual verification" >&2
  exit 1
fi

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Launch sequence: MCP → CLI → Initial seeding → Insurance resend
launch_system() {
  local secure_mode="$1"
  
  log "Starting ucomm system launch (SECURE_MODE=$secure_mode)"
  
  # Step 1: Launch MCP
  log "Step 1/4: Starting MCP server..."
  if [[ "$secure_mode" == "1" ]]; then
    log "SECURE_MODE=1: MCP disabled in production mode"
  else
    scripts/mcp-launch.sh start || {
      log "ERROR: MCP launch failed"
      return 1
    }
    sleep 2
    
    # Verify MCP is responding
    if ! curl -fsS "http://127.0.0.1:39200/ready" --max-time 3 >/dev/null 2>&1; then
      log "WARNING: MCP not responding, continuing anyway"
    else
      log "✓ MCP server ready"
    fi
  fi
  
  # Step 2: Initialize CLI adapters
  log "Step 2/4: Initializing CLI adapters..."
  if [[ -f "config/cli_adapters.yaml" ]]; then
    while IFS= read -r cmd; do
      [[ -n "$cmd" && "$cmd" != "null" ]] || continue
      if command -v "$cmd" >/dev/null 2>&1; then
        log "✓ CLI adapter '$cmd' available"
      else
        log "⚠ CLI adapter '$cmd' missing (will show warning in send.sh)"
      fi
    done < <(yq -r '.adapters[].cmd' config/cli_adapters.yaml 2>/dev/null || true)
  else
    log "⚠ config/cli_adapters.yaml not found"
  fi
  
  # Step 3: Create tmux topology
  log "Step 3/4: Creating tmux session topology..."
  if command -v tmux >/dev/null 2>&1; then
    if [[ -f "config/topology.yaml" ]]; then
      # Parse topology and create sessions
      while IFS='|' read -r session_name window_name role cli; do
        [[ -n "$session_name" && -n "$window_name" ]] || continue
        
        # Create session if not exists
        if ! tmux has-session -t "$session_name" 2>/dev/null; then
          tmux new-session -d -s "$session_name" -n "$window_name"
          log "✓ Created session '$session_name'"
        fi
        
        # Add panes for roles
        if [[ -n "$role" && -n "$cli" ]]; then
          tmux new-window -t "$session_name" -n "$role" 2>/dev/null || true
          log "✓ Added pane for role '$role' (CLI: $cli)"
        fi
      done < <(
        yq -r '
          .sessions[] as $s |
          $s.windows[] as $w |
          ($w.panes | to_entries[]) |
          "\($s.name)|\($w.name)|\(.value.role)|\(.value.cli)"
        ' config/topology.yaml 2>/dev/null || true
      )
    else
      log "⚠ config/topology.yaml not found, skipping tmux setup"
    fi
  else
    log "⚠ tmux not available, skipping session creation"
  fi
  
  # Step 4: Initial seeding and insurance resend
  log "Step 4/4: Initial system seeding..."
  if [[ -f "scripts/send.sh" ]]; then
    # Send initial health check
    echo '{"action": "health_check", "timestamp": "'$(date -Iseconds)'"}' | \
      scripts/send.sh "Director" 2>/dev/null || \
      log "⚠ Initial seeding failed (CLI may not be ready)"
    
    sleep 1
    
    # Insurance resend
    echo '{"action": "system_ready", "timestamp": "'$(date -Iseconds)'"}' | \
      scripts/send.sh "Manager" 2>/dev/null || \
      log "⚠ Insurance resend failed (CLI may not be ready)"
  else
    log "⚠ scripts/send.sh not found, skipping initial seeding"
  fi
  
  log "✓ ucomm system launch completed"
}

stop_system() {
  log "Stopping ucomm system..."
  
  # Stop MCP
  scripts/mcp-launch.sh stop 2>/dev/null || true
  
  # Kill tmux sessions
  if command -v tmux >/dev/null 2>&1; then
    tmux kill-session -t ucomm_Director 2>/dev/null || true
    tmux kill-session -t ucomm_multiagent 2>/dev/null || true
  fi
  
  log "✓ ucomm system stopped"
}

case "$ACTION" in
  start)
    if [[ "$SECURE_MODE" == "1" ]]; then
      log "SECURE_MODE=1: Production mode detected"
      log "ERROR: Production launch requires manual verification"
      exit 1
    fi
    launch_system "$SECURE_MODE"
    ;;
  stop)
    stop_system
    ;;
  restart)
    stop_system
    sleep 2
    launch_system "$SECURE_MODE"
    ;;
  *)
    echo "Usage: $0 [SECURE_MODE] [start|stop|restart]"
    echo "  SECURE_MODE: 0=development, 1=production"
    exit 1
    ;;
esac
