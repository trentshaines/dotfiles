#!/bin/bash
RESULT_FILE=$(mktemp)
~/bin/claude-notify-picker "$RESULT_FILE"
if [[ -s "$RESULT_FILE" ]]; then
    TARGET=$(cut -f1 "$RESULT_FILE")
    CLIENT=$(cut -f2 "$RESULT_FILE")
    rm -f "$RESULT_FILE"
    ~/.claude/scripts/claude-switch.sh "$TARGET" "$CLIENT"
else
    rm -f "$RESULT_FILE"
fi
