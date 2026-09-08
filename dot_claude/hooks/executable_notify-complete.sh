#!/bin/bash

TMUX_BIN="/opt/homebrew/bin/tmux"
QUEUE_FILE="${AGENT_NOTIFICATION_FILE:-/tmp/claude-notifications.queue}"
AGENT_NAME="${AGENT_NOTIFICATION_AGENT:-${CODEX_THREAD_ID:+Codex}}"
AGENT_NAME="${AGENT_NAME:-Claude}"
NOTIFICATION_TITLE="${AGENT_NOTIFICATION_TITLE:-$AGENT_NAME}"

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

# Atomically replace this pane's row while holding the same lock used by
# picker cleanup, focus updates, and dismissals.
(
    /usr/bin/lockf -s -t 2 9 || exit 0
    TMP=$(mktemp "${QUEUE_FILE}.tmp.XXXXXX") || exit 0
    trap 'rm -f "$TMP"' EXIT

    if [[ -f "$QUEUE_FILE" ]]; then
        awk -F'\t' -v target="$TARGET" '$2 != target' "$QUEUE_FILE" > "$TMP"
    else
        : > "$TMP"
    fi

    # TIMESTAMP TARGET CLIENT PROJECT SESSION WINDOW_NAME PANE_INDEX LAST_VISITED AGENT
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t0\t%s\n' \
        "$TIMESTAMP" "$TARGET" "$CLIENT" "$PROJECT" "$SESSION" "$WINDOW_NAME" "$PANE_INDEX" "$AGENT_NAME" >> "$TMP"
    mv "$TMP" "$QUEUE_FILE"
) 9>"${QUEUE_FILE}.lock"

# Send notification only if user isn't already looking at this pane
if [[ "$ALREADY_FOCUSED" == "false" ]]; then
  terminal-notifier \
    -title "$NOTIFICATION_TITLE" \
    -subtitle "$PROJECT" \
    -message "$SESSION → $WINDOW_NAME (pane $PANE_INDEX)" 2>/dev/null || true
fi
