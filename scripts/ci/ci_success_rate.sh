#!/usr/bin/env bash
# scripts/ci/ci_success_rate.sh - CI success rate monitoring for Phase 4 KPI tracking
set -Eeuo pipefail
export LANG=C LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TIMESTAMP="$(date -u +%Y%m%d_%H%M%S)"
ARTIFACT_DIR="artifacts/ci"
SUMMARY_FILE="$ARTIFACT_DIR/summary.json"
WORKFLOW_NAME="${CI_WORKFLOW_NAME:-smoke.yml}"
REPO="${GITHUB_REPOSITORY:-$(git config --get remote.origin.url | sed 's|.*[:/]\([^/]*\)/\([^/]*\)\.git.*|\1/\2|')}"

log() {
    echo "[$(date -u +%H:%M:%S)] $*" >&2
}

check_gh_cli() {
    if command -v gh >/dev/null 2>&1; then
        if gh auth status >/dev/null 2>&1; then
            echo "gh_cli"
            return 0
        fi
    fi
    echo "curl_api"
}

count_conclusions() {
    local data="$1"
    local pattern="$2"
    echo "$data" | grep -o "\"conclusion\":\"$pattern\"" | wc -l
}

calc_percentage() {
    local count="$1"
    local total="$2"
    if [[ "$total" -eq 0 ]]; then
        echo "0.0"
    else
        echo "$count $total" | awk '{printf "%.1f", $1 * 100 / $2}'
    fi
}

fetch_runs_gh() {
    local limit=${1:-20}
    log "Fetching last $limit runs using gh CLI..."
    gh run list --workflow="$WORKFLOW_NAME" --limit="$limit" --json="conclusion,status,createdAt,number,displayTitle,headSha" 2>/dev/null || return 1
}

fetch_runs_curl() {
    local limit=${1:-20}
    log "Fetching last $limit runs using GitHub API..."
    local token="${GITHUB_TOKEN:-}"
    local auth_header=""
    
    if [[ -n "$token" ]]; then
        auth_header="-H \"Authorization: token $token\""
    fi
    
    local api_url="https://api.github.com/repos/$REPO/actions/workflows/$WORKFLOW_NAME/runs?per_page=$limit"
    eval curl -fsS $auth_header -H "Accept: application/vnd.github.v3+json" "$api_url" 2>/dev/null || return 1
}

calculate_metrics() {
    local runs_data="$1"
    local success_count failure_count cancelled_count total_count
    
    success_count=$(count_conclusions "$runs_data" "success")
    failure_count=$(count_conclusions "$runs_data" "failure")
    cancelled_count=$(count_conclusions "$runs_data" "cancelled")
    
    if [[ "$runs_data" =~ workflow_runs ]]; then
        total_count=$(echo "$runs_data" | grep -o '"conclusion":' | wc -l)
    else
        total_count=$(echo "$runs_data" | grep -o '{"conclusion":' | wc -l)
    fi
    
    if [[ "$total_count" -eq 0 ]]; then
        echo "0|0|0|0|0.0|0.0|0.0"
        return 0
    fi
    
    local success_rate failure_rate cancelled_rate
    success_rate=$(calc_percentage "$success_count" "$total_count")
    failure_rate=$(calc_percentage "$failure_count" "$total_count")
    cancelled_rate=$(calc_percentage "$cancelled_count" "$total_count")
    
    echo "$success_count|$failure_count|$cancelled_count|$total_count|$success_rate|$failure_rate|$cancelled_rate"
}

main() {
    log "CI Success Rate Analysis starting..."
    mkdir -p "$ARTIFACT_DIR"
    
    local fetch_method
    fetch_method=$(check_gh_cli)
    log "Using fetch method: $fetch_method"
    
    local runs_data=""
    if [[ "$fetch_method" == "gh_cli" ]]; then
        runs_data=$(fetch_runs_gh 20)
    else
        runs_data=$(fetch_runs_curl 20) 
    fi
    
    if [[ -z "$runs_data" || "$runs_data" == "null" ]]; then
        log "Failed to fetch workflow runs"
        echo "{\"error\":\"failed_to_fetch_runs\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\"}" > "$SUMMARY_FILE"
        exit 1
    fi
    
    local run_count
    run_count=$(echo "$runs_data" | grep -o '"conclusion":' | wc -l)
    log "Fetched $run_count workflow runs"
    
    local metrics
    metrics=$(calculate_metrics "$runs_data")
    IFS='|' read -r success_count failure_count cancelled_count total_count success_rate failure_rate cancelled_rate <<< "$metrics"
    
    log "Metrics: $success_count success, $failure_count failure, $cancelled_count cancelled"
    log "Success rate: $success_rate% (target: >= 70.0%)"
    
    local meets_target="false"
    if [[ $(echo "$success_rate >= 70.0" | awk '{print ($1 >= $3)}') -eq 1 ]]; then
        meets_target="true"
    fi
    
    local summary_json="{
  \"ci_summary\": {
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",
    \"workflow\": \"$WORKFLOW_NAME\",
    \"repository\": \"$REPO\",
    \"fetch_method\": \"$fetch_method\"
  },
  \"metrics\": {
    \"total_runs\": $total_count,
    \"success\": {\"count\": $success_count, \"rate\": $success_rate},
    \"failure\": {\"count\": $failure_count, \"rate\": $failure_rate},
    \"cancelled\": {\"count\": $cancelled_count, \"rate\": $cancelled_rate}
  },
  \"kpi_status\": {
    \"target_rate\": 70.0,
    \"current_rate\": $success_rate,
    \"meets_target\": $meets_target,
    \"phase4_goal\": \"Increase CI success rate from 22.2% to >= 70%\"
  }
}"

    echo "$summary_json" > "$SUMMARY_FILE"
    echo "$summary_json" > "$ARTIFACT_DIR/summary_${TIMESTAMP}.json"
    
    log "Summary saved to $SUMMARY_FILE"
    
    if [[ "$meets_target" == "true" ]]; then
        log "KPI TARGET MET: Success rate $success_rate% >= 70.0%"
    else
        log "KPI TARGET NOT MET: Success rate $success_rate% < 70.0%"
    fi
}

main "$@"
