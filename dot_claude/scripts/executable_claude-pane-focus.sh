#!/bin/bash
# Called when a pane gets focus - marks it as visited if in queue

TMUX_BIN="/opt/homebrew/bin/tmux"
QUEUE_FILE="/tmp/claude-notifications.queue"

[[ ! -f "$QUEUE_FILE" ]] && exit 0

# Get current pane info
SESSION=$($TMUX_BIN display-message -p '#{session_name}')
WINDOW=$($TMUX_BIN display-message -p '#{window_index}')
PANE_INDEX=$($TMUX_BIN display-message -p '#{pane_index}')
TARGET="$SESSION:$WINDOW.$PANE_INDEX"
NOW=$(date +%s)

# Update last_visited if this target is in the queue
if grep -q "$TARGET" "$QUEUE_FILE" 2>/dev/null; then
    awk -F'\t' -v target="$TARGET" -v now="$NOW" 'BEGIN{OFS="\t"} {
        if ($2 == target) { $8 = now }
        print
    }' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
fi
