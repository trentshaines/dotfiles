#!/bin/bash
RESULT=$(~/bin/claude-notify-picker)
if [[ -n "$RESULT" ]]; then
    TARGET=$(echo "$RESULT" | cut -f1)
    CLIENT=$(echo "$RESULT" | cut -f2)
    ~/.claude/scripts/claude-switch.sh "$TARGET" "$CLIENT"
fi
