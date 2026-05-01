#!/bin/bash
# UserPromptSubmit hook: record this pane as actively running an agent.
# Lifecycle pair with notify-running-end.sh (Stop hook).

TMUX_BIN="/opt/homebrew/bin/tmux"
RUNNING_FILE="/tmp/claude-running.queue"
PANE_ID="$TMUX_PANE"

[[ -z "$PANE_ID" ]] && exit 0

CLIENT=$($TMUX_BIN display-message -t "$PANE_ID" -p '#{client_tty}' 2>/dev/null) || exit 0
SESSION=$($TMUX_BIN display-message -t "$PANE_ID" -p '#{session_name}' 2>/dev/null) || exit 0
WINDOW=$($TMUX_BIN display-message -t "$PANE_ID" -p '#{window_index}' 2>/dev/null) || exit 0
WINDOW_NAME=$($TMUX_BIN display-message -t "$PANE_ID" -p '#{window_name}' 2>/dev/null) || exit 0
PANE_INDEX=$($TMUX_BIN display-message -t "$PANE_ID" -p '#{pane_index}' 2>/dev/null) || exit 0
PROJECT=$(basename "$PWD")
TARGET="$SESSION:$WINDOW.$PANE_INDEX"
TIMESTAMP=$(date +%s)

# Remove any existing row for this pane_id (overwrite-on-prompt semantics)
if [[ -f "$RUNNING_FILE" ]]; then
    awk -F'\t' -v p="$PANE_ID" '$2 != p' "$RUNNING_FILE" > "$RUNNING_FILE.tmp" && mv "$RUNNING_FILE.tmp" "$RUNNING_FILE"
fi

# Format: TIMESTAMP PANE_ID TARGET CLIENT PROJECT SESSION WINDOW_NAME PANE_INDEX
echo -e "$TIMESTAMP\t$PANE_ID\t$TARGET\t$CLIENT\t$PROJECT\t$SESSION\t$WINDOW_NAME\t$PANE_INDEX" >> "$RUNNING_FILE"
