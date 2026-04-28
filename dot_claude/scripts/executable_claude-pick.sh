#!/bin/bash
# Claude notification picker using fzf.
# enter: switch  ·  ctrl-d: dismiss (hover or tab-select multiple)

TMUX_BIN="/opt/homebrew/bin/tmux"
QUEUE_FILE="/tmp/claude-notifications.queue"
SWITCH_SCRIPT="$HOME/.claude/scripts/claude-switch.sh"
DELETE_SCRIPT="$HOME/.claude/scripts/claude-delete.sh"
LINES_SCRIPT="$HOME/.claude/scripts/claude-fzf-lines.sh"

[[ ! -f "$QUEUE_FILE" ]] || [[ ! -s "$QUEUE_FILE" ]] && {
    $TMUX_BIN display-message "No pending Claude notifications"
    exit 0
}

RELOAD_CMD="bash '$LINES_SCRIPT'"

SELECTION=$(bash "$LINES_SCRIPT" | fzf \
    --delimiter=$'\t' \
    --with-nth=3.. \
    --multi \
    --prompt="  " \
    --header=" enter: switch  ·  ctrl-d: dismiss" \
    --bind "ctrl-d:execute-silent($DELETE_SCRIPT {+1})+reload($RELOAD_CMD)+deselect-all" \
    --reverse \
    --border=rounded \
    --border-label=" Claude Notifications ")

[[ -z "$SELECTION" ]] && exit 0

TARGET=$(echo "$SELECTION" | head -1 | cut -f1)
CLIENT=$(echo "$SELECTION" | head -1 | cut -f2)
"$SWITCH_SCRIPT" "$TARGET" "$CLIENT"
