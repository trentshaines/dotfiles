#!/bin/bash

TMUX_BIN="/opt/homebrew/bin/tmux"
QUEUE_FILE="/tmp/claude-notifications.queue"

# $TMUX_PANE is the pane ID where this hook was triggered
PANE_ID="$TMUX_PANE"

# Check if user is already looking at this pane
ACTIVE_PANE=$($TMUX_BIN display-message -p '#{pane_id}')
ALREADY_FOCUSED=false
[[ "$ACTIVE_PANE" == "$PANE_ID" ]] && ALREADY_FOCUSED=true

# Capture tmux context from Claude's pane (not the focused pane)
CLIENT=$($TMUX_BIN display-message -t "$PANE_ID" -p '#{client_tty}')
SESSION=$($TMUX_BIN display-message -t "$PANE_ID" -p '#{session_name}')
WINDOW=$($TMUX_BIN display-message -t "$PANE_ID" -p '#{window_index}')
WINDOW_NAME=$($TMUX_BIN display-message -t "$PANE_ID" -p '#{window_name}')
PANE_INDEX=$($TMUX_BIN display-message -t "$PANE_ID" -p '#{pane_index}')
PROJECT=$(basename "$PWD")
TIMESTAMP=$(date +%s)

# Full target: session:window.pane
TARGET="$SESSION:$WINDOW.$PANE_INDEX"

# Remove old entry for same target using awk (more reliable than grep with tabs)
if [[ -f "$QUEUE_FILE" ]]; then
    awk -F'\t' -v target="$TARGET" '$2 != target' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
fi

# Add new entry: TIMESTAMP TARGET CLIENT PROJECT SESSION WINDOW_NAME PANE_INDEX LAST_VISITED(0=never)
echo -e "$TIMESTAMP\t$TARGET\t$CLIENT\t$PROJECT\t$SESSION\t$WINDOW_NAME\t$PANE_INDEX\t0" >> "$QUEUE_FILE"

# Send notification only if user isn't already looking at this pane
if [[ "$ALREADY_FOCUSED" == "false" ]]; then
  terminal-notifier \
    -title "Claude Code" \
    -subtitle "$PROJECT" \
    -message "$SESSION → $WINDOW_NAME (pane $PANE_INDEX)" 2>/dev/null || true
fi
