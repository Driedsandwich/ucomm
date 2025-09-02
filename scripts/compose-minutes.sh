#!/usr/bin/env bash
# scripts/compose-minutes.sh - Complete pipeline for meeting minutes generation
# Usage: compose-minutes.sh <date> <mode> [summarizer_mode]

set -euo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

usage() {
    echo "Usage: $0 <date> <mode> [summarizer_mode]"
    echo "  date: YYYY-MM-DD format"
    echo "  mode: log mode (e.g., local, api, council)"
    echo "  summarizer_mode: local|api (default: local)"
    echo ""
    echo "This script runs the complete pipeline:"
    echo "  1. Optional: capture.sh (if available and logs are missing)"
    echo "  2. minutes.sh - generate base minutes"
    echo "  3. summarizer.sh - generate summary"
    echo ""
    echo "Environment variables:"
    echo "  SKIP_CAPTURE=1    Skip automatic capture step"
    echo "  FORCE_RECAPTURE=1 Force recapture even if logs exist"
    echo ""
    echo "Example: $0 2025-09-01 local api"
    exit 1
}

# Validate input parameters
if [[ $# -lt 2 || $# -gt 3 ]]; then
    usage
fi

DATE="$1"
MODE="$2"
SUMMARIZER_MODE="${3:-local}"

# Validate date format
if ! [[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Error: Date must be in YYYY-MM-DD format" >&2
    exit 1
fi

echo "=== Minutes Composition Pipeline ==="
echo "Date: $DATE"
echo "Mode: $MODE"  
echo "Summarizer: $SUMMARIZER_MODE"
echo "========================================"

# Step 1: Optional capture (if capture.sh exists and logs are missing/forced)
LOG_DIR="logs/$MODE/$DATE"
CAPTURE_SCRIPT="$SCRIPT_DIR/capture.sh"

if [[ -f "$CAPTURE_SCRIPT" ]]; then
    if [[ "${FORCE_RECAPTURE:-}" == "1" ]] || [[ "${SKIP_CAPTURE:-}" != "1" && ! -d "$LOG_DIR" ]]; then
        echo "Step 1: Running capture for missing logs..."
        if "$CAPTURE_SCRIPT" "$DATE" "$MODE"; then
            echo "✓ Capture completed"
        else
            echo "⚠ Capture failed or no new data captured"
        fi
    else
        echo "Step 1: Skipping capture (logs exist or SKIP_CAPTURE=1)"
    fi
else
    echo "Step 1: Skipping capture (capture.sh not found)"
fi

# Step 2: Generate base minutes
echo "Step 2: Generating base minutes..."
if "$SCRIPT_DIR/minutes.sh" "$DATE" "$MODE"; then
    echo "✓ Base minutes generated"
else
    echo "✗ Failed to generate base minutes" >&2
    exit 1
fi

# Step 3: Generate summary
echo "Step 3: Generating summary..."
if "$SCRIPT_DIR/summarizer.sh" "$DATE" "$MODE" "$SUMMARIZER_MODE"; then
    echo "✓ Summary generated"
else
    echo "✗ Failed to generate summary" >&2
    exit 1
fi

# Final report
OUTPUT_DIR="reports/minutes/$DATE"
BASE_FILE="$OUTPUT_DIR/$MODE.md"
SUMMARY_FILE="$OUTPUT_DIR/$MODE.$SUMMARIZER_MODE.md"

echo "========================================"
echo "Pipeline completed successfully!"
echo ""
echo "Generated files:"
if [[ -f "$BASE_FILE" ]]; then
    echo "  Base minutes: $BASE_FILE ($(wc -l < "$BASE_FILE") lines)"
fi
if [[ -f "$SUMMARY_FILE" ]]; then
    echo "  Summary: $SUMMARY_FILE ($(wc -l < "$SUMMARY_FILE") lines)"
fi

echo ""
echo "Log statistics:"
if [[ -d "$LOG_DIR" ]]; then
    LOG_COUNT=$(find "$LOG_DIR" -name "*.log" -type f | wc -l)
    if [[ $LOG_COUNT -gt 0 ]]; then
        ENTRY_COUNT=$(find "$LOG_DIR" -name "*.log" -type f -exec cat {} \; | wc -l)
        echo "  Source logs: $LOG_COUNT files, $ENTRY_COUNT entries"
    else
        echo "  Source logs: No log files found"
    fi
else
    echo "  Source logs: Directory not found ($LOG_DIR)"
fi

echo ""
echo "Next steps:"
echo "  View base: cat '$BASE_FILE'"
echo "  View summary: cat '$SUMMARY_FILE'"
echo "  Archive: tar -czf minutes_${DATE}_${MODE}.tar.gz '$OUTPUT_DIR'"