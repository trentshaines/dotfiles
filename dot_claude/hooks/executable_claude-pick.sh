#!/bin/bash
# fzf picker for pending Claude notifications

TMUX_BIN="/opt/homebrew/bin/tmux"
QUEUE_FILE="/tmp/claude-notifications.queue"
SWITCH_SCRIPT="$HOME/.claude/hooks/claude-switch.sh"

if [[ ! -f "$QUEUE_FILE" ]] || [[ ! -s "$QUEUE_FILE" ]]; then
    $TMUX_BIN display-message "No pending Claude notifications"
    exit 0
fi

# Helper script to format entries - will be called by fzf reload
format_entries() {
    local now=$(date +%s)

    # Only show unvisited items, sorted by oldest first (longest ignored)
    awk -F'\t' -v now="$now" '$8 == 0 {
        ts = $1
        target = $2
        client = $3
        project = $4
        session = $5
        window_name = $6
        pane_index = $7

        # Calculate time ago
        ago_mins = int((now - ts) / 60)
        if (ago_mins < 1) {
            finished = "just now"
        } else if (ago_mins < 60) {
            finished = ago_mins "m ago"
        } else {
            hours = int(ago_mins / 60)
            finished = hours "h ago"
        }

        printf "%s\t%s\t%s: %s → %s (pane %s) | done: %s\n", target, client, project, session, window_name, pane_index, finished
    }' "$QUEUE_FILE" | sort -t$'\t' -k1,1n
}

# Delete entry (pop from queue)
delete_entry() {
    local target="$1"
    awk -F'\t' -v target="$target" '$2 != target' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
}

# Create wrapper script for fzf reload (to avoid "command not found" errors)
RELOAD_CMD="bash -c 'now=\$(date +%s); awk -F'\''\\t'\'' -v now=\"\$now\" '\''\$8 == 0 { ts = \$1; target = \$2; client = \$3; project = \$4; session = \$5; window_name = \$6; pane_index = \$7; ago_mins = int((now - ts) / 60); if (ago_mins < 1) { finished = \"just now\" } else if (ago_mins < 60) { finished = ago_mins \"m ago\" } else { hours = int(ago_mins / 60); finished = hours \"h ago\" }; printf \"%s\\t%s\\t%s: %s → %s (pane %s) | done: %s\\n\", target, client, project, session, window_name, pane_index, finished }'\'' \"$QUEUE_FILE\" | sort -t$'\''\\t'\'' -k1,1n'"

# Run fzf with reload bindings
SELECTION=$(format_entries | fzf-tmux -p 70%,50% \
    --with-nth=3.. \
    --delimiter=$'\t' \
    --prompt="Claude > " \
    --reverse \
    --border-label ' Claude Notifications ' \
    --header 'enter: switch | ctrl-d: dismiss (pop from queue)' \
    --bind "ctrl-d:execute-silent(awk -F'\t' -v target={1} '\$2 != target' \"$QUEUE_FILE\" > \"$QUEUE_FILE.tmp\" && mv \"$QUEUE_FILE.tmp\" \"$QUEUE_FILE\")+reload($RELOAD_CMD)" \
)

if [[ -n "$SELECTION" ]]; then
    TARGET=$(echo "$SELECTION" | cut -d$'\t' -f1)
    CLIENT=$(echo "$SELECTION" | cut -d$'\t' -f2)
    "$SWITCH_SCRIPT" "$TARGET" "$CLIENT"
fi

exit 0
