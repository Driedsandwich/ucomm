#!/usr/bin/env bash
# tests/test_mask.sh - Minimal tests for masking functionality
# Usage: ./tests/test_mask.sh

set -euo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the masking library
source "$PROJECT_ROOT/scripts/lib/mask.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_assert() {
    local description="$1"
    local expected="$2"
    local actual="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        echo "✓ PASS: $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAIL: $description"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "Running mask.sh tests..."
echo "========================"

# Test email masking
test_email="Contact me at john.doe@example.com for details"
expected_email="Contact me at [REDACTED:EMAIL] for details"
actual_email=$(echo "$test_email" | mask_data)
test_assert "Email masking" "$expected_email" "$actual_email"

# Test token masking - OpenAI style
test_token1="API key: sk-abcdef123456789012345"
expected_token1="API key: [REDACTED:TOKEN]"
actual_token1=$(echo "$test_token1" | mask_data)
test_assert "OpenAI token masking" "$expected_token1" "$actual_token1"

# Test token masking - hex style
test_token2="Session token: 1234567890abcdef1234567890abcdef"
expected_token2="Session token: [REDACTED:TOKEN]"
actual_token2=$(echo "$test_token2" | mask_data)
test_assert "Hex token masking" "$expected_token2" "$actual_token2"

# Test phone masking
test_phone="Call me at +1-555-123-4567"
expected_phone="Call me at [REDACTED:PHONE]"
actual_phone=$(echo "$test_phone" | mask_data)
test_assert "Phone number masking" "$expected_phone" "$actual_phone"

# Test timestamp preservation (should NOT be masked as phone)
test_timestamp="2025-09-01 14:30:45"
expected_timestamp="2025-09-01 14:30:45"
actual_timestamp=$(echo "$test_timestamp" | mask_data)
test_assert "Timestamp preservation" "$expected_timestamp" "$actual_timestamp"

# Test TSV message masking (only column 3 should be masked)
test_tsv="2025-09-01 14:30:00	admin	Contact john.doe@example.com"
expected_tsv="2025-09-01 14:30:00	admin	Contact [REDACTED:EMAIL]"
actual_tsv=$(echo "$test_tsv" | mask_tsv_messages)
test_assert "TSV message-only masking" "$expected_tsv" "$actual_tsv"

# Test TSV with role preservation
test_tsv_role="2025-09-01 14:30:00	user@company.com	API key is sk-test123456789"
expected_tsv_role="2025-09-01 14:30:00	user@company.com	API key is [REDACTED:TOKEN]"
actual_tsv_role=$(echo "$test_tsv_role" | mask_tsv_messages)
test_assert "TSV role preservation (email in role column)" "$expected_tsv_role" "$actual_tsv_role"

# Test multiple patterns in one message
test_multi="Email john@test.com, token sk-abc123def456ghi, call +1-555-999-8888"
expected_multi="Email [REDACTED:EMAIL], token [REDACTED:TOKEN], call [REDACTED:PHONE]"
actual_multi=$(echo "$test_multi" | mask_data)
test_assert "Multiple patterns masking" "$expected_multi" "$actual_multi"

# Test empty/edge cases
test_empty=""
expected_empty=""
actual_empty=$(echo "$test_empty" | mask_data)
test_assert "Empty input handling" "$expected_empty" "$actual_empty"

# Summary
echo ""
echo "Test Results:"
echo "============="
echo "Tests run: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed!"
    exit 1
fi