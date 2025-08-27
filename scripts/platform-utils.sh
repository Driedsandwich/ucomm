#!/usr/bin/env bash
# scripts/platform-utils.sh — Cross-platform utility functions for ucomm
set -Eeuo pipefail

# Detect current platform
detect_platform() {
  local os_type="$(uname -s 2>/dev/null || echo "unknown")"
  local platform="unknown"
  
  case "$os_type" in
    Linux*)     
      if grep -qi ubuntu /etc/os-release 2>/dev/null; then
        platform="ubuntu"
      else
        platform="linux"
      fi
      ;;
    Darwin*)    platform="macos" ;;
    CYGWIN*|MINGW*|MSYS*) platform="windows" ;;
    *)          platform="unknown" ;;
  esac
  
  echo "$platform"
}

# Get platform-specific artifact directory
get_artifact_dir() {
  local platform="$(detect_platform)"
  local base_dir="${1:-artifacts}"
  
  case "$platform" in
    ubuntu|linux) echo "${base_dir}" ;;
    macos)        echo "${base_dir}-macos" ;;
    windows)      echo "${base_dir}-windows" ;;
    *)            echo "${base_dir}" ;;
  esac
}

# Check if command exists with platform-specific handling
check_command() {
  local cmd="$1"
  local platform="$(detect_platform)"
  
  case "$platform" in
    windows)
      # On Windows, check both with and without .exe extension
      command -v "$cmd" >/dev/null 2>&1 || command -v "${cmd}.exe" >/dev/null 2>&1
      ;;
    *)
      command -v "$cmd" >/dev/null 2>&1
      ;;
  esac
}

# Create platform-specific logs with system info
create_platform_log() {
  local log_file="$1"
  local platform="$(detect_platform)"
  
  {
    echo "=== Platform Information ==="
    echo "Platform: $platform"
    echo "OS: $(uname -a 2>/dev/null || echo "unknown")"
    echo "Date: $(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
    echo "Shell: ${SHELL:-unknown}"
    echo "User: ${USER:-${USERNAME:-unknown}}"
    echo ""
    
    echo "=== Available Tools ==="
    local tools=("tmux" "yq" "curl" "git" "node" "python3")
    for tool in "${tools[@]}"; do
      if check_command "$tool"; then
        printf "%-10s ✓ available\n" "$tool"
      else
        printf "%-10s ✗ not found\n" "$tool"
      fi
    done
    echo ""
    
    echo "=== Environment Variables ==="
    echo "UCOMM_SECURE_MODE: ${UCOMM_SECURE_MODE:-0}"
    echo "MCP_HOST: ${MCP_HOST:-127.0.0.1}"
    echo "MCP_PORT: ${MCP_PORT:-39200}"
    echo ""
    
    case "$platform" in
      windows)
        echo "=== Windows Specific ==="
        echo "MSYSTEM: ${MSYSTEM:-unknown}"
        echo "MINGW_PREFIX: ${MINGW_PREFIX:-unknown}"
        ;;
      macos)
        echo "=== macOS Specific ==="
        if check_command sw_vers; then
          sw_vers 2>/dev/null || echo "sw_vers unavailable"
        fi
        ;;
      ubuntu|linux)
        echo "=== Linux Specific ==="
        if [[ -f /etc/os-release ]]; then
          cat /etc/os-release | head -3
        fi
        ;;
    esac
    echo ""
  } > "$log_file"
}

# Main function for command-line usage
main() {
  case "${1:-help}" in
    detect-platform)  detect_platform ;;
    artifact-dir)     get_artifact_dir "${2:-artifacts}" ;;
    check-command)    check_command "${2:-tmux}" && echo "✓ available" || echo "✗ not found" ;;
    platform-log)    create_platform_log "${2:-platform.log}" && echo "Platform log created: ${2:-platform.log}" ;;
    *)
      echo "Usage: $0 {detect-platform|artifact-dir [dir]|check-command <cmd>|platform-log [file]}"
      echo ""
      echo "Commands:"
      echo "  detect-platform    - Detect current platform (ubuntu|macos|windows|unknown)"
      echo "  artifact-dir [dir] - Get platform-specific artifact directory"
      echo "  check-command <cmd>- Check if command is available (platform-aware)"
      echo "  platform-log [file]- Create detailed platform information log"
      exit 1
      ;;
  esac
}

# If script is run directly, execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
