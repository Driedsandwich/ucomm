#!/usr/bin/env bash
# scripts/lib/mask.sh - Data masking library for meeting minutes
# Usage: mask_data < input.txt > output.txt
# Environment: MASK_DEBUG=1 to print counts to stderr

set -euo pipefail

# Masking patterns and replacements
EMAIL_PATTERN='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
EMAIL_REPLACEMENT='[REDACTED:EMAIL]'

PHONE_PATTERN='\+[0-9][-0-9 ]{8,14}[0-9]|[0-9]{3}[-. ][0-9]{3}[-. ][0-9]{4}|\([0-9]{3}\)[-. ][0-9]{3}[-. ][0-9]{4}'
PHONE_REPLACEMENT='[REDACTED:PHONE]'

TOKEN_PATTERN='sk-[A-Za-z0-9]{12,}|[A-Fa-f0-9]{24,}'
TOKEN_REPLACEMENT='[REDACTED:TOKEN]'

# Debug counters
email_count=0
phone_count=0
token_count=0

# Main masking function
mask_data() {
    local input_text
    local output_text
    
    # Read all input
    input_text=$(cat)
    
    # Start with original text
    output_text="$input_text"
    
    # Count original instances for debug
    if [[ -n "${MASK_DEBUG:-}" ]]; then
        email_count=$(echo "$input_text" | grep -oE "$EMAIL_PATTERN" | wc -l || echo 0)
        phone_count=$(echo "$input_text" | grep -oE "$PHONE_PATTERN" | wc -l || echo 0)
        token_count=$(echo "$input_text" | grep -oE "$TOKEN_PATTERN" | wc -l || echo 0)
    fi
    
    # Mask tokens first (to avoid interference with phone pattern)
    output_text=$(echo "$output_text" | sed -E "s/$TOKEN_PATTERN/$TOKEN_REPLACEMENT/g")
    
    # Then mask emails
    output_text=$(echo "$output_text" | sed -E "s/$EMAIL_PATTERN/$EMAIL_REPLACEMENT/g")
    
    # Finally mask phone numbers (exclude timestamp-like patterns)
    output_text=$(echo "$output_text" | sed -E "s/([^0-9:]|^)($PHONE_PATTERN)([^0-9:]|$)/\1$PHONE_REPLACEMENT\3/g")
    
    # Output debug info to stderr if requested
    if [[ -n "${MASK_DEBUG:-}" ]]; then
        echo "MASK_DEBUG: emails=$email_count, phones=$phone_count, tokens=$token_count" >&2
    fi
    
    # Output the masked text
    echo "$output_text"
}

# Function to mask a single line (for streaming processing)
mask_line() {
    local line="$1"
    echo "$line" | sed -E "s/$TOKEN_PATTERN/$TOKEN_REPLACEMENT/g" | \
                   sed -E "s/$EMAIL_PATTERN/$EMAIL_REPLACEMENT/g" | \
                   sed -E "s/([^0-9:]|^)($PHONE_PATTERN)([^0-9:]|$)/\1$PHONE_REPLACEMENT\3/g"
}

# Function to mask only the message column (column 3) of TSV format
# Input format: timestamp<TAB>role<TAB>message
# Hardened to handle inputs without trailing newlines
mask_tsv_messages() {
    local debug_count=0
    
    # Dual safety approach: ensure input always ends with newline + robust read pattern
    {
        cat
        # Always add a trailing newline (harmless if input already ends with one)
        printf '\n'
    } | while IFS=$'\t' read -r timestamp role message || [[ -n "${timestamp}${role}${message}" ]]; do
        # Process line if any of the three fields has content (robust last-line handling)
        if [[ -n "$timestamp" ]] && [[ -n "$role" ]]; then
            local masked_message="$message"
            
            # Only apply masking if message field exists
            if [[ -n "$message" ]]; then
                # Apply masking in order: tokens, emails, then phones (but exclude timestamp-like patterns)
                masked_message=$(echo "$message" | \
                    sed -E "s/$TOKEN_PATTERN/$TOKEN_REPLACEMENT/g" | \
                    sed -E "s/$EMAIL_PATTERN/$EMAIL_REPLACEMENT/g" | \
                    sed -E "s/([^0-9:]|^)($PHONE_PATTERN)([^0-9:]|$)/\1$PHONE_REPLACEMENT\3/g")
            fi
            
            printf "%s\t%s\t%s\n" "$timestamp" "$role" "$masked_message"
            
            # Debug counting
            if [[ -n "${MASK_DEBUG:-}" ]]; then
                ((debug_count++))
            fi
        fi
        # Skip empty lines or malformed entries silently
    done
    
    # Output debug info if requested
    if [[ -n "${MASK_DEBUG:-}" ]]; then
        echo "MASK_DEBUG: Processed $debug_count TSV lines" >&2
    fi
}

# Export functions for use by other scripts
export -f mask_data mask_line mask_tsv_messages

# If script is called directly, run mask_data
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    mask_data
fi