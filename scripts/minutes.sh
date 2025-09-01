#!/usr/bin/env bash
# scripts/minutes.sh - Generate meeting minutes from TSV logs
# Usage: minutes.sh <date> <mode>
# Input: logs/{mode}/{date}/*.log (TSV format: YYYY-MM-DD HH:MM:SS<TAB>role<TAB>message)
# Output: reports/minutes/<date>/<mode>.md

set -euo pipefail

# Source the masking library
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/lib/mask.sh"

usage() {
    echo "Usage: $0 <date> <mode>"
    echo "  date: YYYY-MM-DD format"
    echo "  mode: log mode (e.g., local, api, council)"
    echo "Example: $0 2025-09-01 local"
    exit 1
}

# Validate input parameters
if [[ $# -ne 2 ]]; then
    usage
fi

DATE="$1"
MODE="$2"

# Validate date format
if ! [[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Error: Date must be in YYYY-MM-DD format" >&2
    exit 1
fi

# Set paths
LOG_DIR="logs/$MODE/$DATE"
OUTPUT_DIR="reports/minutes/$DATE"
OUTPUT_FILE="$OUTPUT_DIR/$MODE.md"

# Check if log directory exists
if [[ ! -d "$LOG_DIR" ]]; then
    echo "Error: Log directory $LOG_DIR does not exist" >&2
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Temporary files
MERGED_LOGS=$(mktemp)
MASKED_LOGS=$(mktemp)

# Cleanup function
cleanup() {
    rm -f "$MERGED_LOGS" "$MASKED_LOGS"
}
trap cleanup EXIT

echo "Processing logs for $DATE/$MODE..."

# Merge and sort logs chronologically
find "$LOG_DIR" -name "*.log" -type f -print0 | \
    xargs -0 cat | \
    sort -t$'\t' -k1,1 > "$MERGED_LOGS"

if [[ ! -s "$MERGED_LOGS" ]]; then
    echo "Error: No log entries found in $LOG_DIR" >&2
    exit 1
fi

# Apply masking (only to column 3 - message)
mask_tsv_messages < "$MERGED_LOGS" > "$MASKED_LOGS"

# Extract information for sections
extract_roles_and_counts() {
    awk -F'\t' '{roles[$2]++; total++} END {
        for (role in roles) {
            printf "%s: %d entries\n", role, roles[role]
        }
        printf "Total: %d entries\n", total
    }' "$MASKED_LOGS" | sort
}

extract_topics() {
    # Look for lines starting with [#topic] or take first few meaningful lines
    local topic_count
    topic_count=$(grep -E '^\[[^]]*\].*#topic' "$MASKED_LOGS" 2>/dev/null | wc -l)
    
    {
        if [[ "$topic_count" -gt 0 ]]; then
            grep -E '^\[[^]]*\].*#topic' "$MASKED_LOGS" | head -5
        else
            # If no explicit topics, use first meaningful lines as provisional topics
            awk -F'\t' 'length($3) > 20 && $3 !~ /^(ok|yes|no|done|started|completed)$/i {print "暫定: " $3}' "$MASKED_LOGS" | head -3
        fi
    } | sed 's/^[^[:space:]]*[[:space:]]*[^[:space:]]*[[:space:]]*//'
}

extract_discussion_points() {
    # Group discussion points by role and proximity to topics
    awk -F'\t' '
    BEGIN { current_role = ""; points_count = 0 }
    {
        role = $2
        message = $3
        
        # Skip very short messages
        if (length(message) < 10) next
        
        # Skip status messages
        if (message ~ /^(ok|yes|no|done|started|completed|確認|了解)$/i) next
        
        # If role changed or meaningful message, capture as discussion point
        if (role != current_role && length(message) > 15) {
            printf "- [%s] %s\n", role, substr(message, 1, 100)
            current_role = role
            points_count++
            if (points_count >= 10) exit  # Limit output
        }
    }' "$MASKED_LOGS"
}

extract_decisions() {
    grep -iE '\t(決定:|DECISION|\[DECISION\]|決定しました|決まりました)' "$MASKED_LOGS" | \
        sed 's/^[^[:space:]]*[[:space:]]*[^[:space:]]*[[:space:]]*/- /' | \
        head -10
}

extract_todos() {
    grep -iE '\t(TODO:|@[a-zA-Z0-9_]+:|タスク:|やること:|次に)' "$MASKED_LOGS" | \
        sed 's/^[^[:space:]]*[[:space:]]*[^[:space:]]*[[:space:]]*/- /' | \
        head -10
}

extract_reference_logs() {
    # Last N lines, re-masked for safety
    tail -n 20 "$MASKED_LOGS" | \
        awk -F'\t' '{printf "%s %s: %s\n", $1, $2, $3}' | \
        mask_data
}

# Generate the minutes file
generate_minutes() {
    cat > "$OUTPUT_FILE" << EOF
# Minutes ($DATE / $MODE)

## 概要
EOF

    local roles_info
    roles_info=$(extract_roles_and_counts)
    if [[ -n "$roles_info" ]]; then
        echo "$roles_info" >> "$OUTPUT_FILE"
    fi
    echo "" >> "$OUTPUT_FILE"

    # Topics section
    local topics
    topics=$(extract_topics)
    if [[ -n "$topics" ]]; then
        echo "## 議題" >> "$OUTPUT_FILE"
        echo "$topics" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi

    # Discussion points section
    local discussion_points
    discussion_points=$(extract_discussion_points)
    if [[ -n "$discussion_points" ]]; then
        echo "## 論点" >> "$OUTPUT_FILE"
        echo "$discussion_points" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi

    # Decisions section
    local decisions
    decisions=$(extract_decisions)
    if [[ -n "$decisions" ]]; then
        echo "## 決定事項" >> "$OUTPUT_FILE"
        echo "$decisions" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi

    # TODOs section
    local todos
    todos=$(extract_todos)
    if [[ -n "$todos" ]]; then
        echo "## TODO" >> "$OUTPUT_FILE"
        echo "$todos" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi

    # Reference logs section
    local ref_logs
    ref_logs=$(extract_reference_logs)
    if [[ -n "$ref_logs" ]]; then
        echo "## 参考ログ" >> "$OUTPUT_FILE"
        echo '```' >> "$OUTPUT_FILE"
        echo "$ref_logs" >> "$OUTPUT_FILE"
        echo '```' >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi

    # Add generation timestamp
    echo "---" >> "$OUTPUT_FILE"
    echo "_Generated: $(date '+%Y-%m-%d %H:%M:%S JST') by minutes.sh_" >> "$OUTPUT_FILE"
}

# Generate the minutes
generate_minutes

echo "Minutes generated: $OUTPUT_FILE"
echo "Log entries processed: $(wc -l < "$MERGED_LOGS")"
echo "Sections created: $(grep -c '^##' "$OUTPUT_FILE")"