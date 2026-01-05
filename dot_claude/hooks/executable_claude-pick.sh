#!/bin/bash
# fzf picker for pending Claude notifications

TMUX_BIN="/opt/homebrew/bin/tmux"
QUEUE_FILE="/tmp/claude-notifications.queue"
SWITCH_SCRIPT="$HOME/.claude/hooks/claude-switch.sh"

if [[ ! -f "$QUEUE_FILE" ]] || [[ ! -s "$QUEUE_FILE" ]]; then
    $TMUX_BIN display-message "No pending Claude notifications"
    exit 0
fi

export QUEUE_FILE TMUX_BIN

# Script to format entries (called by fzf reload)
format_entries() {
    local now=$(date +%s)

    format_time() {
        local ts=$1
        if [[ $ts -eq 0 ]]; then
            echo "never"
            return
        fi
        local ago=$(( (now - ts) / 60 ))
        if [[ $ago -lt 1 ]]; then
            echo "just now"
        elif [[ $ago -lt 60 ]]; then
            echo "${ago}m ago"
        else
            local hours=$(( ago / 60 ))
            echo "${hours}h ago"
        fi
    }

    # Only show unvisited items, sorted by oldest first (longest ignored)
    awk -F'\t' '$8 == 0' "$QUEUE_FILE" | sort -t$'\t' -k1,1n | \
    while IFS=$'\t' read -r ts target client project session window_name pane_index last_visited; do
        finished=$(format_time "$ts")
        echo -e "$target\t$client\t$project: $session → $window_name (pane $pane_index) | done: $finished"
    done
}

export -f format_entries

# Action scripts for fzf bindings
mark_visited() {
    local target="$1"
    local now=$(date +%s)
    awk -F'\t' -v target="$target" -v now="$now" 'BEGIN{OFS="\t"} {
        if ($2 == target) { $8 = now }
        print
    }' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
}

delete_entry() {
    local target="$1"
    awk -F'\t' -v target="$target" '$2 != target' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
}

export -f mark_visited delete_entry

# Run fzf with reload bindings
SELECTION=$(format_entries | fzf-tmux -p 70%,50% \
    --with-nth=3.. \
    --delimiter=$'\t' \
    --prompt="Claude > " \
    --reverse \
    --border-label ' Claude Notifications ' \
    --header 'enter: switch | ctrl-v: dismiss | ctrl-d: delete forever' \
    --bind "ctrl-v:execute-silent(mark_visited {1})+reload(format_entries)" \
    --bind "ctrl-d:execute-silent(delete_entry {1})+reload(format_entries)" \
)

if [[ -n "$SELECTION" ]]; then
    TARGET=$(echo "$SELECTION" | cut -d$'\t' -f1)
    CLIENT=$(echo "$SELECTION" | cut -d$'\t' -f2)
    "$SWITCH_SCRIPT" "$TARGET" "$CLIENT"
fi

exit 0
