#!/usr/bin/env bash
# scripts/capture-enhanced.sh — Cross-platform artifact capture with enhanced logging
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Source platform utilities
source "$ROOT/scripts/platform-utils.sh"

# ==== Platform-aware Configuration ====
PLATFORM="$(detect_platform)"
ARTIFACT_DIR="$(get_artifact_dir artifacts)"
YQ="${YQ_BIN:-yq}"
TMUX="${TMUX_BIN:-tmux}"
DATE_DIR="$(date +%F)"

# Create platform-specific artifact directory
mkdir -p "$ARTIFACT_DIR"

# Get mode from topology or fallback
if check_command "$YQ" && [[ -f "config/topology.yaml" ]]; then
  MODE="$($YQ -r '.modes.active // "HIERARCHY"' config/topology.yaml 2>/dev/null || echo HIERARCHY)"
else
  MODE="HIERARCHY"
fi

OUT_DIR="$ROOT/logs/${MODE}/${DATE_DIR}"
mkdir -p "$OUT_DIR"

echo "MODE=HIERARCHY" > "$ARTIFACT_DIR/MODE"

# Create platform information log
create_platform_log "$ARTIFACT_DIR/platform.log"

# Copy current system configuration
if [[ -f "config/topology.yaml" ]]; then
  cp "config/topology.yaml" "$ARTIFACT_DIR/topology.yaml"
fi

# Run health check and capture results  
echo "=== Running health check ==="
if [[ -x "$ROOT/scripts/health.sh" ]]; then
  if "$ROOT/scripts/health.sh" --json > "$ARTIFACT_DIR/health.json" 2>/dev/null; then
    echo "[ok] health check captured"
  else
    echo '{"error":"health_check_failed","platform":"'$PLATFORM'","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'"}' > "$ARTIFACT_DIR/health.json"
    echo "[warn] health check failed, using fallback"
  fi
else
  echo '{"error":"health_script_not_found","platform":"'$PLATFORM'","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'"}' > "$ARTIFACT_DIR/health.json"
fi

# MCP endpoint checks with platform awareness
echo "=== Testing MCP endpoints ===" 
for endpoint in "ready" "health"; do
  local_file="$ARTIFACT_DIR/mcp_${endpoint}.json"
  if check_command curl; then
    if curl -fsS "http://127.0.0.1:39200/${endpoint}" --max-time 6 > "$local_file" 2>/dev/null; then
      echo "[ok] MCP /${endpoint} endpoint captured"
    else
      echo '{"error":"endpoint_unreachable","endpoint":"/'$endpoint'","platform":"'$PLATFORM'","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'"}' > "$local_file"
      echo "[warn] MCP /${endpoint} endpoint unreachable (expected in CI)"
    fi
  else
    echo '{"error":"curl_not_available","platform":"'$PLATFORM'","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'"}' > "$local_file"
  fi
done

# Tmux capture with platform-specific handling
echo "=== Tmux capture (platform: $PLATFORM) ==="
if check_command "$TMUX"; then
  if $TMUX ls >/dev/null 2>&1; then
    echo "[ok] tmux sessions found, capturing..."
    
    # Basic tmux info capture
    $TMUX list-windows -a -F '#{session_name}:#{window_index} #{window_name} (#{window_panes} panes)' > "$ARTIFACT_DIR/tmux_windows.txt" 2>/dev/null || echo "Failed to capture windows" > "$ARTIFACT_DIR/tmux_windows.txt"
    
    # Capture Director and multiagent pane info if they exist
    if $TMUX has-session -t ucomm_Director 2>/dev/null; then
      $TMUX list-panes -t ucomm_Director -F '#{pane_index}: #{pane_title}' > "$ARTIFACT_DIR/tmux_director_panes.txt" 2>/dev/null || echo "Failed to capture Director panes" > "$ARTIFACT_DIR/tmux_director_panes.txt"
    else
      echo "No ucomm_Director session found" > "$ARTIFACT_DIR/tmux_director_panes.txt"
    fi
    
    if $TMUX has-session -t ucomm_multiagent 2>/dev/null; then
      $TMUX list-panes -t ucomm_multiagent -F '#{pane_index}: #{pane_title}' > "$ARTIFACT_DIR/tmux_team_panes.txt" 2>/dev/null || echo "Failed to capture team panes" > "$ARTIFACT_DIR/tmux_team_panes.txt"
    else
      echo "No ucomm_multiagent session found" > "$ARTIFACT_DIR/tmux_team_panes.txt"
    fi
    
  else
    echo "[warn] no tmux session found; creating placeholder files"
    echo "No tmux sessions found" > "$ARTIFACT_DIR/tmux_windows.txt" 
    echo "No tmux sessions available" > "$ARTIFACT_DIR/tmux_director_panes.txt"
    echo "No tmux sessions available" > "$ARTIFACT_DIR/tmux_team_panes.txt"
  fi
else
  echo "[info] tmux not available on $PLATFORM - creating platform-specific placeholders"
  case "$PLATFORM" in
    windows)
      echo "Windows platform: tmux not supported in CI environment" > "$ARTIFACT_DIR/tmux_windows.txt"
      echo "Windows platform: no tmux sessions" > "$ARTIFACT_DIR/tmux_director_panes.txt"
      echo "Windows platform: no tmux sessions" > "$ARTIFACT_DIR/tmux_team_panes.txt"
      ;;
    macos)
      echo "macOS platform: tmux not available in CI environment" > "$ARTIFACT_DIR/tmux_windows.txt"
      echo "macOS platform: no tmux sessions" > "$ARTIFACT_DIR/tmux_director_panes.txt"
      echo "macOS platform: no tmux sessions" > "$ARTIFACT_DIR/tmux_team_panes.txt"
      ;;
    *)
      echo "$PLATFORM: tmux not found" > "$ARTIFACT_DIR/tmux_windows.txt"
      echo "$PLATFORM: tmux not found" > "$ARTIFACT_DIR/tmux_director_panes.txt"
      echo "$PLATFORM: tmux not found" > "$ARTIFACT_DIR/tmux_team_panes.txt"
      ;;
  esac
fi

echo "[capture] Artifacts saved to: $ARTIFACT_DIR"
echo "[capture] Platform: $PLATFORM"
echo "[capture] Mode: $MODE"

# List created artifacts for verification
echo "[capture] Created artifacts:"
ls -la "$ARTIFACT_DIR/" | grep -E '\.(json|txt|yaml|log)$' || echo "No artifacts found"

# Return success if we captured any artifacts
if [[ -d "$ARTIFACT_DIR" ]] && [[ -n "$(ls -A "$ARTIFACT_DIR" 2>/dev/null || true)" ]]; then
  exit 0
else
  exit 1
fi
