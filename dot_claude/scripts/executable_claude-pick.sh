#!/bin/bash
# fzf picker for pending Claude notifications

TMUX_BIN="/opt/homebrew/bin/tmux"
QUEUE_FILE="/tmp/claude-notifications.queue"
FORMAT_SCRIPT="$HOME/.claude/scripts/claude-format-entries.sh"
SWITCH_SCRIPT="$HOME/.claude/scripts/claude-switch.sh"

if [[ ! -f "$QUEUE_FILE" ]] || [[ ! -s "$QUEUE_FILE" ]]; then
    $TMUX_BIN display-message "No pending Claude notifications"
    exit 0
fi

# Output: ts\ttarget\tclient\tdisplay — sorted by recency, unvisited only
format_entries() {
    bash "$FORMAT_SCRIPT"
}

RELOAD_CMD="bash '$FORMAT_SCRIPT' | sort -t$'\t' -k1,1rn | cut -f2-"

# Run fzf. Fields after cut: 1=target, 2=client, 3=display
SELECTION=$(format_entries | sort -t$'\t' -k1,1rn | cut -f2- | fzf \
    --multi \
    --with-nth=3.. \
    --delimiter=$'\t' \
    --prompt="Claude > " \
    --reverse \
    --border=rounded \
    --border-label ' Claude Notifications ' \
    --header 'tab: select | enter: switch | ctrl-d: dismiss selected' \
    --bind "ctrl-d:execute-silent($HOME/.claude/scripts/claude-delete.sh {+1})+reload($RELOAD_CMD)+deselect-all" \
)

if [[ -n "$SELECTION" ]]; then
    TARGET=$(echo "$SELECTION" | cut -d$'\t' -f1)
    CLIENT=$(echo "$SELECTION" | cut -d$'\t' -f2)
    "$SWITCH_SCRIPT" "$TARGET" "$CLIENT"
fi

exit 0
