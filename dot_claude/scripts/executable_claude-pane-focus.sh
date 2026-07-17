#!/bin/bash
# Called when a pane gets focus - marks it as visited if in queue

TMUX_BIN="/opt/homebrew/bin/tmux"
QUEUE_FILE="${AGENT_NOTIFICATION_FILE:-/tmp/claude-notifications.queue}"

# Get current pane info
SESSION=$($TMUX_BIN display-message -p '#{session_name}')
WINDOW=$($TMUX_BIN display-message -p '#{window_index}')
PANE_INDEX=$($TMUX_BIN display-message -p '#{pane_index}')
TARGET="$SESSION:$WINDOW.$PANE_INDEX"
NOW=$(date +%s)

# Update last_visited if this target is in the queue.
(
    /usr/bin/lockf -s -t 2 9 || exit 0
    [[ ! -f "$QUEUE_FILE" ]] && exit 0
    TMP=$(mktemp "${QUEUE_FILE}.tmp.XXXXXX") || exit 0
    trap 'rm -f "$TMP"' EXIT
    awk -F'\t' -v target="$TARGET" -v now="$NOW" 'BEGIN{OFS="\t"} {
        if ($2 == target) { $8 = now }
        print
    }' "$QUEUE_FILE" > "$TMP" &&
        mv "$TMP" "$QUEUE_FILE"
) 9>"${QUEUE_FILE}.lock"
