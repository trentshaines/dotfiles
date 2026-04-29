#!/bin/bash
RESULT_FILE=$(mktemp)
~/bin/pane-picker "$RESULT_FILE"
if [[ -s "$RESULT_FILE" ]]; then
    PANE_ID=$(cat "$RESULT_FILE" | tr -d '\n')
    rm -f "$RESULT_FILE"
    /opt/homebrew/bin/tmux switch-client -t "$PANE_ID"
else
    rm -f "$RESULT_FILE"
fi
