#!/bin/bash
# Claude Code Stop Hook - Send last assistant response to Telegram

# Load environment variables from .env
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

# Read hook data from stdin and extract assistant_message
SUMMARY=$(python3 -c "
import sys, json, html as html_mod

data = json.load(sys.stdin)

# Debug: send hook JSON keys to Telegram instead of normal message
lines = ['[HOOK DEBUG]']
for k, v in data.items():
    if k == 'last_assistant_message':
        preview = str(v)[:80] + '...' if len(str(v)) > 80 else str(v)
    else:
        preview = str(v)
    lines.append(f'{k}: {preview}')
print('\n'.join(lines))
sys.exit(0)

text = data.get('last_assistant_message', '').strip()

if not text:
    sys.exit(0)

# Escape HTML special chars but preserve <b></b> tags (CLAUDE.md output format)
text = html_mod.escape(text)
text = text.replace('&lt;b&gt;', '<b>').replace('&lt;/b&gt;', '</b>')

if len(text) > 4000:
    text = text[:4000] + '...'
print(text)
" 2>/dev/null)

# Only send if we have an actual assistant response
if [ -n "$SUMMARY" ]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "text=${SUMMARY}" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d parse_mode="HTML" \
        > /dev/null 2>&1
fi
