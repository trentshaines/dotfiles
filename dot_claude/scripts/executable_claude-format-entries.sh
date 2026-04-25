#!/bin/bash
# Formats pending Claude notifications for fzf display.
# TMUX_CLIENT_WIDTH injected by display-popup bind; popup is -w 70%.

QUEUE_FILE="/tmp/claude-notifications.queue"
[[ ! -f "$QUEUE_FILE" ]] && exit 0

if [[ -n "$TMUX_CLIENT_WIDTH" ]]; then
    cols=$(( TMUX_CLIENT_WIDTH * 70 / 100 ))
else
    cols=${COLUMNS:-80}
fi

python3 "$HOME/.claude/scripts/claude-format-entries.py" \
    "$QUEUE_FILE" "$(date +%s)" "$cols"
