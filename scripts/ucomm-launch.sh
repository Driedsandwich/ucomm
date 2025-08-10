#!/usr/bin/env bash
# ucomm-launch.sh — Phase 1 (v0): YAML-driven tmux build, all panes = default_cli (gemini)
# Requirements: tmux, yq
set -euo pipefail

cd "$(dirname "$0")/.."

YAML="config/topology.yaml"
[[ -f "$YAML" ]] || { echo "[launch] missing $YAML"; exit 1; }

require() { command -v "$1" >/dev/null 2>&1 || { echo "[launch] missing dependency: $1"; exit 1; }; }
require tmux
require yq

MODE_DEFAULT="$(yq -r '.modes.active // "HIERARCHY"' "$YAML")"
MODE="${MODE:-$MODE_DEFAULT}"
export MODE

# Kill existing sessions with the same names (clean start)
# NOTE: In later phases we may choose to reuse; for v0 we prefer deterministic rebuild.
mapfile -t SESSIONS < <(yq -r '.sessions[].name' "$YAML")
for s in "${SESSIONS[@]}"; do
  if tmux has-session -t "$s" 2>/dev/null; then
    tmux kill-session -t "$s"
  fi
done

# Build sessions/windows/panes
SESSION_COUNT="$(yq '.sessions | length' "$YAML")"
for (( si=0; si<SESSION_COUNT; si++ )); do
  SNAME="$(yq -r ".sessions[$si].name" "$YAML")"
  WIN_COUNT="$(yq ".sessions[$si].windows | length" "$YAML")"
  if [[ "$WIN_COUNT" -eq 0 ]]; then
    echo "[launch] warning: session '$SNAME' has no windows"; continue
  fi

  # Create first window (new-session), then others (new-window)
  FIRST_WNAME="$(yq -r ".sessions[$si].windows[0].name" "$YAML")"
  tmux new-session -d -s "$SNAME" -n "$FIRST_WNAME"

  for (( wi=0; wi<WIN_COUNT; wi++ )); do
    WNAME="$(yq -r ".sessions[$si].windows[$wi].name" "$YAML")"
    if [[ $wi -ne 0 ]]; then
      tmux new-window -t "$SNAME:" -n "$WNAME"
    fi

    PANE_COUNT="$(yq ".sessions[$si].windows[$wi].panes | length" "$YAML")"
    if [[ "$PANE_COUNT" -eq 0 ]]; then
      echo "[launch] warning: window '$SNAME:$WNAME' has no panes"; continue
    fi

    for (( pi=0; pi<PANE_COUNT; pi++ )); do
      ROLE="$(yq -r ".sessions[$si].windows[$wi].panes[$pi].role" "$YAML")"
      TITLE="$(yq -r ".sessions[$si].windows[$wi].panes[$pi].title" "$YAML")"
      CLI="$(yq -r ".sessions[$si].windows[$wi].panes[$pi].cli // .default_cli" "$YAML")"

      if [[ $pi -eq 0 ]]; then
        PANE_TARGET="${SNAME}:${WNAME}.0"
      else
        tmux split-window -t "${SNAME}:${WNAME}" -h
        tmux select-layout -t "${SNAME}:${WNAME}" tiled >/dev/null
        PANE_TARGET="$(tmux list-panes -t "${SNAME}:${WNAME}" -F '#{pane_id}' | tail -n1)"
      fi

      # Title & identity banner
      tmux select-pane -t "$PANE_TARGET" \; select-pane -T "$TITLE"
      tmux send-keys -t "$PANE_TARGET" "echo '[[ $TITLE ready / MODE:$MODE / ROLE:$ROLE / CLI:$CLI ]]'" Enter

      # Try to start CLI if available; otherwise keep pane alive (no-op loop)
      if command -v "$CLI" >/dev/null 2>&1; then
        tmux send-keys -t "$PANE_TARGET" "$CLI" Enter
      else
        tmux send-keys -t "$PANE_TARGET" "echo '[launch] CLI not found: $CLI — keeping pane alive'; tail -f /dev/null" Enter
      fi
    done
  done

  # Focus the first window of this session
  tmux switch-client -t "${SNAME}:${FIRST_WNAME}" || true
done

echo "[ucomm] launched ${#SESSIONS[@]} sessions (MODE=$MODE)"
