#!/usr/bin/env bash
# tests/test_minutes.sh - Basic functionality test for minutes generation
# Usage: ./tests/test_minutes.sh

set -euo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Testing minutes.sh functionality..."
echo "==================================="

# Test with existing logs if they exist
TEST_DATE="2025-09-01"
TEST_MODE="local"

if [[ -d "$PROJECT_ROOT/logs/$TEST_MODE/$TEST_DATE" ]]; then
    echo "✓ Found existing logs for $TEST_DATE/$TEST_MODE"
    
    # Run minutes generation
    echo "Running: scripts/minutes.sh $TEST_DATE $TEST_MODE"
    cd "$PROJECT_ROOT"
    ./scripts/minutes.sh "$TEST_DATE" "$TEST_MODE"
    
    # Check if output was created
    OUTPUT_FILE="reports/minutes/$TEST_DATE/$TEST_MODE.md"
    if [[ -f "$OUTPUT_FILE" ]]; then
        echo "✓ Minutes file created: $OUTPUT_FILE"
        
        # Basic content checks
        if grep -q "# Minutes" "$OUTPUT_FILE"; then
            echo "✓ Header format correct"
        else
            echo "✗ Missing header"
        fi
        
        if grep -q "## 概要" "$OUTPUT_FILE"; then
            echo "✓ Summary section found"
        else
            echo "✗ Missing summary section"
        fi
        
        # Check for timestamp preservation (should contain actual timestamps)
        if grep -qE "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" "$OUTPUT_FILE"; then
            echo "✓ Timestamps preserved in output"
        else
            echo "✗ No timestamps found in output"
        fi
        
        # Check for proper masking (should not contain email patterns in content)
        if grep -q "example@" "$OUTPUT_FILE"; then
            echo "✗ Warning: Possible unmasked email found"
        else
            echo "✓ Email masking appears to be working"
        fi
        
        echo ""
        echo "Generated minutes preview (first 20 lines):"
        echo "--------------------------------------------"
        head -20 "$OUTPUT_FILE"
        
    else
        echo "✗ Minutes file not created"
        exit 1
    fi
else
    echo "⚠ No test logs found at logs/$TEST_MODE/$TEST_DATE"
    echo "Creating minimal test data..."
    
    # Create minimal test data
    mkdir -p "logs/$TEST_MODE/$TEST_DATE"
    cat > "logs/$TEST_MODE/$TEST_DATE/session1.log" << 'EOF'
2025-09-01 09:00:00	admin	Meeting started - test meeting
2025-09-01 09:01:00	developer	Contact me at test@example.com for details
2025-09-01 09:02:00	admin	API token is sk-test123456789abcdef
2025-09-01 09:03:00	developer	Call +1-555-123-4567 for support
2025-09-01 09:04:00	admin	Meeting ended
EOF
    
    echo "✓ Created test data"
    
    # Run minutes generation
    echo "Running: scripts/minutes.sh $TEST_DATE $TEST_MODE"
    cd "$PROJECT_ROOT"
    ./scripts/minutes.sh "$TEST_DATE" "$TEST_MODE"
    
    OUTPUT_FILE="reports/minutes/$TEST_DATE/$TEST_MODE.md"
    if [[ -f "$OUTPUT_FILE" ]]; then
        echo "✓ Minutes file created with test data"
        
        # Check for masking
        if grep -q "REDACTED" "$OUTPUT_FILE"; then
            echo "✓ Masking applied to content"
        else
            echo "⚠ No REDACTED tokens found - check if test data had sensitive info"
        fi
    else
        echo "✗ Failed to create minutes with test data"
        exit 1
    fi
fi

echo ""
echo "✓ Minutes functionality test completed"