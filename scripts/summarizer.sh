#!/usr/bin/env bash
# scripts/summarizer.sh - Summarize meeting minutes using local or API methods
# Usage: summarizer.sh <date> <mode> [summarizer_mode]
# Environment: SUMMARIZER_MODE=local|api (default: local)

set -euo pipefail

# Source the masking library
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/lib/mask.sh"

usage() {
    echo "Usage: $0 <date> <mode> [summarizer_mode]"
    echo "  date: YYYY-MM-DD format"
    echo "  mode: log mode (e.g., local, api, council)"
    echo "  summarizer_mode: local|api (default: local)"
    echo ""
    echo "Environment variables:"
    echo "  SUMMARIZER_MODE: local|api (overrides command line)"
    echo "  OPENAI_API_KEY: Required for api mode"
    echo "  ANTHROPIC_API_KEY: Alternative for api mode"
    echo ""
    echo "Example: SUMMARIZER_MODE=local $0 2025-09-01 local"
    exit 1
}

# Validate input parameters
if [[ $# -lt 2 || $# -gt 3 ]]; then
    usage
fi

DATE="$1"
MODE="$2"
SUMMARIZER_MODE="${3:-${SUMMARIZER_MODE:-local}}"

# Validate date format
if ! [[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Error: Date must be in YYYY-MM-DD format" >&2
    exit 1
fi

# Validate summarizer mode
if [[ "$SUMMARIZER_MODE" != "local" && "$SUMMARIZER_MODE" != "api" ]]; then
    echo "Error: Summarizer mode must be 'local' or 'api'" >&2
    exit 1
fi

# Set paths
INPUT_DIR="reports/minutes/$DATE"
INPUT_FILE="$INPUT_DIR/$MODE.md"
OUTPUT_FILE="$INPUT_DIR/$MODE.$SUMMARIZER_MODE.md"

# Check if input file exists
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file $INPUT_FILE does not exist" >&2
    echo "Tip: Run minutes.sh first to generate the base minutes file" >&2
    exit 1
fi

echo "Summarizing $INPUT_FILE using $SUMMARIZER_MODE mode..."

# API mode implementation
summarize_api() {
    local input_content
    input_content=$(cat "$INPUT_FILE")
    
    # Check for API keys
    if [[ -z "${OPENAI_API_KEY:-}" && -z "${ANTHROPIC_API_KEY:-}" ]]; then
        echo "Error: API mode requires OPENAI_API_KEY or ANTHROPIC_API_KEY environment variable" >&2
        echo "No API keys found - failing explicitly (no silent fallback)" >&2
        exit 1
    fi
    
    # Call the separate API adapter script if it exists
    local api_adapter="$SCRIPT_DIR/adapters/summarize_api.sh"
    if [[ -f "$api_adapter" ]]; then
        echo "$input_content" | "$api_adapter" > "$OUTPUT_FILE"
    else
        # Fallback to simple API call (this would be expanded in real implementation)
        echo "Error: API adapter script not found at $api_adapter" >&2
        echo "Create $api_adapter to implement API-based summarization" >&2
        exit 1
    fi
}

# Local mode implementation using extractive summarization
summarize_local() {
    local temp_content
    temp_content=$(mktemp)
    
    # Copy input content to temp file for processing
    cp "$INPUT_FILE" "$temp_content"
    
    # Generate summary using awk/sed extractive methods
    {
        # Copy header
        echo "# Summary ($DATE / $MODE / $SUMMARIZER_MODE)"
        echo ""
        
        # Extract and summarize each section
        awk '
        BEGIN { 
            in_section = 0
            section_name = ""
            section_content = ""
        }
        
        /^## / {
            # Process previous section if it exists
            if (in_section && section_content != "") {
                print "## " section_name
                print summarize_section(section_content)
                print ""
            }
            
            # Start new section
            section_name = substr($0, 4)  # Remove "## "
            section_content = ""
            in_section = 1
            next
        }
        
        in_section && /^[^#]/ {
            section_content = section_content $0 "\n"
        }
        
        !in_section {
            print $0
        }
        
        END {
            # Process final section
            if (in_section && section_content != "") {
                print "## " section_name
                print summarize_section(section_content)
            }
        }
        
        function summarize_section(content) {
            # Simple extractive summarization
            # Take first few lines and key bullet points
            split(content, lines, "\n")
            summary = ""
            bullet_count = 0
            line_count = 0
            
            for (i = 1; i <= length(lines); i++) {
                line = lines[i]
                if (line == "") continue
                
                # Always include bullet points (up to limit)
                if (line ~ /^- / && bullet_count < 5) {
                    summary = summary line "\n"
                    bullet_count++
                }
                # Include first few non-bullet lines
                else if (line !~ /^- / && line_count < 2 && length(line) > 10) {
                    summary = summary line "\n"
                    line_count++
                }
            }
            
            # If section was too sparse, include word frequency highlights
            if (length(summary) < 50) {
                summary = summary extract_keywords(content)
            }
            
            return summary
        }
        
        function extract_keywords(content) {
            # Simple keyword extraction based on frequency
            # This would be more sophisticated in a real implementation
            return "主要キーワード: " substr(content, 1, 100) "..."
        }
        ' "$temp_content"
        
        # Add generation timestamp
        echo "---"
        echo "_Summary generated: $(date '+%Y-%m-%d %H:%M:%S JST') by summarizer.sh ($SUMMARIZER_MODE mode)_"
        
    } > "$OUTPUT_FILE"
    
    # Cleanup
    rm -f "$temp_content"
}

# Main execution
case "$SUMMARIZER_MODE" in
    "local")
        summarize_local
        ;;
    "api")
        summarize_api
        ;;
    *)
        echo "Error: Unknown summarizer mode: $SUMMARIZER_MODE" >&2
        exit 1
        ;;
esac

echo "Summary generated: $OUTPUT_FILE"
echo "Mode: $SUMMARIZER_MODE"

# Verify output file was created and has content
if [[ -f "$OUTPUT_FILE" && -s "$OUTPUT_FILE" ]]; then
    echo "Summary file size: $(wc -l < "$OUTPUT_FILE") lines"
else
    echo "Warning: Summary file may be empty or missing" >&2
    exit 1
fi