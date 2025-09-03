#!/usr/bin/env bash
# tests/test_minutes_last_line.sh - Regression test for last-line handling
# Prevents regression of the "no trailing newline drops last line" bug
# Usage: ./tests/test_minutes_last_line.sh

set -euo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Minutes Last-Line Regression Test ==="
echo "Testing both with and without trailing newlines"
echo ""

# Test variables
TEST_DATE="2025-09-01"
TEST_MODE="local"
LOG_DIR="$PROJECT_ROOT/logs/$TEST_MODE/$TEST_DATE"
REPORT_FILE="$PROJECT_ROOT/reports/minutes/$TEST_DATE/$TEST_MODE.md"

# Cleanup function
cleanup() {
    rm -rf "$LOG_DIR"
    rm -f "$REPORT_FILE"
}

# Test helper
assert_role_present() {
    local role="$1"
    local description="$2"
    
    if grep -q "$role" "$REPORT_FILE"; then
        echo "✓ PASS: $description - $role found"
    else
        echo "✗ FAIL: $description - $role missing"
        echo "Report content:"
        cat "$REPORT_FILE"
        exit 1
    fi
}

echo "--- Test 1: Input WITH trailing newlines ---"

# Clean start
cleanup
mkdir -p "$LOG_DIR"

# Create test data WITH trailing newlines (using cat with heredoc)
cat > "$LOG_DIR/session.log" << 'EOF'
2025-09-01 10:00:00	director	[#topic] フェーズ5キックオフ
2025-09-01 10:03:12	manager	決定: Link Check を必須（Public時のみ enforce）
2025-09-01 10:05:00	specialist	TODO: minutes.sh の章立て実装を進める @alice
EOF

echo "Created test data with trailing newlines"

# Run minutes generation
cd "$PROJECT_ROOT"
./scripts/minutes.sh "$TEST_DATE" "$TEST_MODE" > /dev/null 2>&1

# Verify all roles present
assert_role_present "director" "With trailing newlines"
assert_role_present "manager" "With trailing newlines" 
assert_role_present "specialist" "With trailing newlines (should always work)"

echo ""
echo "--- Test 2: Input WITHOUT trailing newlines (CRITICAL) ---"

# Clean and setup for critical test
cleanup
mkdir -p "$LOG_DIR"

# Create test data WITHOUT trailing newlines (using printf, no final \n)
printf "2025-09-01 10:00:00\tdirector\t[#topic] フェーズ5キックオフ\n2025-09-01 10:03:12\tmanager\t決定: Link Check を必須（Public時のみ enforce）\n2025-09-01 10:05:00\tspecialist\tTODO: minutes.sh の章立て実装を進める @alice" > "$LOG_DIR/session.log"

echo "Created test data WITHOUT trailing newlines"

# Verify the test setup (file should NOT end with newline)
if tail -c1 "$LOG_DIR/session.log" | grep -q '^$'; then
    echo "⚠ WARNING: Test setup failed - file unexpectedly ends with newline"
    echo "This test may not be testing the critical case properly"
else
    echo "✓ Confirmed: test data ends without trailing newline"
fi

# Run minutes generation (this is the critical test)
cd "$PROJECT_ROOT"
./scripts/minutes.sh "$TEST_DATE" "$TEST_MODE" > /dev/null 2>&1

# Verify all roles present (especially specialist as last line)
assert_role_present "director" "Without trailing newlines"
assert_role_present "manager" "Without trailing newlines"

# This is the critical assertion - specialist was the last line without \n
if grep -q "specialist" "$REPORT_FILE"; then
    echo "✅ CRITICAL SUCCESS: specialist role captured despite no trailing newline"
    echo "   Last-line handling is working correctly"
else
    echo "❌ CRITICAL FAILURE: specialist role missing from no-newline input"
    echo "   This indicates the last-line bug has regressed"
    echo ""
    echo "Generated report content:"
    cat "$REPORT_FILE"
    echo ""
    echo "Input file hex dump (last 32 bytes):"
    if command -v xxd >/dev/null 2>&1; then
        xxd "$LOG_DIR/session.log" | tail -2
    elif command -v hexdump >/dev/null 2>&1; then
        hexdump -C "$LOG_DIR/session.log" | tail -2  
    else
        od -c "$LOG_DIR/session.log" | tail -2
    fi
    cleanup
    exit 1
fi

echo ""
echo "--- Test 3: Role Count Verification ---"

# Extract role counts from summary section
role_counts=$(grep -A5 "## 概要" "$REPORT_FILE" | grep -E "(director|manager|specialist).*entries")

echo "Role counts found:"
echo "$role_counts"

# Verify each role has exactly 1 entry
for role in director manager specialist; do
    if echo "$role_counts" | grep -q "$role: 1 entries"; then
        echo "✓ $role: 1 entry (correct)"
    else
        echo "✗ $role: count mismatch or missing"
        cleanup
        exit 1
    fi
done

# Verify total count
if grep -q "Total: 3 entries" "$REPORT_FILE"; then
    echo "✓ Total: 3 entries (correct)"
else
    echo "✗ Total count incorrect"
    cleanup
    exit 1
fi

echo ""
echo "🎉 ALL TESTS PASSED!"
echo "✅ Minutes generation handles inputs with trailing newlines"  
echo "✅ Minutes generation handles inputs WITHOUT trailing newlines"
echo "✅ All three roles captured in both scenarios"
echo "✅ Correct role counts in summary section"
echo ""
echo "Regression test completed successfully."

# Cleanup
cleanup
echo "Test files cleaned up."