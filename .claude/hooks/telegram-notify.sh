#!/bin/bash
# Claude Code Stop Hook - Send last assistant response to Telegram

# Load environment variables from .env
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

# Read hook data from stdin
HOOK_DATA=$(cat)

# Extract transcript_path from hook data
TRANSCRIPT_PATH=$(echo "$HOOK_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('transcript_path', ''))
" 2>/dev/null)

# Extract last assistant text message from transcript JSONL
SUMMARY=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    SUMMARY=$(python3 -c "
import json, sys

transcript_path = sys.argv[1]
summary = ''

with open(transcript_path, 'r') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if entry.get('type') == 'assistant':
            message = entry.get('message', {})
            content = message.get('content', '')
            if isinstance(content, list):
                texts = [c.get('text', '') for c in content if c.get('type') == 'text' and c.get('text', '').strip()]
                if texts:
                    summary = '\n'.join(texts)
            elif isinstance(content, str) and content.strip():
                summary = content

summary = summary.strip()
if len(summary) > 4000:
    summary = summary[:4000] + '...'
print(summary)
" "$TRANSCRIPT_PATH" 2>/dev/null)
fi

# Only send if we have an actual assistant response
if [ -n "$SUMMARY" ]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "text=${SUMMARY}" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        > /dev/null 2>&1
fi
