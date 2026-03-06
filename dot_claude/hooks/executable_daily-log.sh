#!/bin/bash
# Log Claude Code activity to daily JSONL files for end-of-day review
# Structure: ~/.claude/logs/daily/YYYY-MM-DD/SESSION_ID.jsonl

INPUT=$(cat)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PROJECT=$(basename "$PWD")

# Parse event and session_id
eval "$(/usr/bin/python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'EVENT={d.get(\"hook_event_name\",\"\")}')
print(f'SESSION_ID={d.get(\"session_id\",\"unknown\")}')
" <<< "$INPUT" 2>/dev/null)"

LOG_DIR="$HOME/.claude/logs/daily/$(date +%Y-%m-%d)"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$SESSION_ID.jsonl"

if [[ "$EVENT" == "UserPromptSubmit" ]]; then
    PROMPT=$(/usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('prompt',''))" <<< "$INPUT" 2>/dev/null)
    /usr/bin/python3 -c "
import json, sys
entry = {'ts': '$TIMESTAMP', 'event': 'prompt', 'project': '$PROJECT', 'prompt': sys.stdin.read()}
print(json.dumps(entry))
" <<< "$PROMPT" >> "$LOG_FILE"
elif [[ "$EVENT" == "Stop" ]]; then
    echo "{\"ts\":\"$TIMESTAMP\",\"event\":\"stop\",\"project\":\"$PROJECT\"}" >> "$LOG_FILE"
fi

exit 0
