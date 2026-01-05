#!/bin/bash
# Switch to a Claude pane and mark as visited

TMUX_BIN="/opt/homebrew/bin/tmux"
QUEUE_FILE="/tmp/claude-notifications.queue"

TARGET="$1"
CLIENT="$2"
NOW=$(date +%s)

# Activate Alacritty and switch tmux
osascript -e 'activate application "Alacritty"'
$TMUX_BIN switch-client -c "$CLIENT" -t "$TARGET"

# Update last_visited timestamp for this target (field 8)
if [[ -f "$QUEUE_FILE" ]]; then
    awk -F'\t' -v target="$TARGET" -v now="$NOW" 'BEGIN{OFS="\t"} {
        if ($2 == target) { $8 = now }
        print
    }' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
fi
