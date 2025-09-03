#!/usr/bin/env bash
# scripts/adapters/summarize_api.sh - API adapter for meeting minutes summarization
# Usage: echo "content" | summarize_api.sh

set -euo pipefail

# Read input content
input_content=$(cat)

# Check for API keys and select provider
if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    PROVIDER="openai"
    API_KEY="$OPENAI_API_KEY"
    ENDPOINT="https://api.openai.com/v1/chat/completions"
elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    PROVIDER="anthropic"
    API_KEY="$ANTHROPIC_API_KEY"
    ENDPOINT="https://api.anthropic.com/v1/messages"
else
    echo "Error: No API key found (OPENAI_API_KEY or ANTHROPIC_API_KEY required)" >&2
    exit 1
fi

# Create the summarization prompt
create_prompt() {
    cat << 'EOF'
You are a meeting minutes summarizer. Please create a concise summary of the following meeting minutes in Japanese, maintaining the same section structure but condensing the content:

1. Keep all section headers (##)
2. Reduce bullet points to the most important ones
3. Combine similar topics
4. Preserve all decision items (決定事項) completely
5. Keep all TODO items
6. Limit 概要 to 3-4 lines maximum
7. Limit 論点 to top 5 discussion points

Please maintain the original markdown format.

Meeting minutes to summarize:
EOF
}

# Make API call based on provider
case "$PROVIDER" in
    "openai")
        curl -s -X POST "$ENDPOINT" \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"gpt-4o-mini\",
                \"messages\": [
                    {
                        \"role\": \"user\",
                        \"content\": \"$(create_prompt)\n\n$input_content\"
                    }
                ],
                \"max_tokens\": 2000,
                \"temperature\": 0.3
            }" | \
        # Extract content from OpenAI response
        sed -n 's/.*"content":"\([^"]*\)".*/\1/p' | \
        # Unescape JSON
        sed 's/\\n/\n/g' | sed 's/\\"/"/g'
        ;;
        
    "anthropic")
        curl -s -X POST "$ENDPOINT" \
            -H "x-api-key: $API_KEY" \
            -H "Content-Type: application/json" \
            -H "anthropic-version: 2023-06-01" \
            -d "{
                \"model\": \"claude-3-haiku-20240307\",
                \"messages\": [
                    {
                        \"role\": \"user\",
                        \"content\": \"$(create_prompt)\n\n$input_content\"
                    }
                ],
                \"max_tokens\": 2000
            }" | \
        # Extract content from Anthropic response
        sed -n 's/.*"text":"\([^"]*\)".*/\1/p' | \
        # Unescape JSON
        sed 's/\\n/\n/g' | sed 's/\\"/"/g'
        ;;
        
    *)
        echo "Error: Unknown provider: $PROVIDER" >&2
        exit 1
        ;;
esac

# Check if we got a response
if [[ $? -ne 0 ]]; then
    echo "Error: API call failed" >&2
    exit 1
fi