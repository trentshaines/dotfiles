#!/bin/bash
# UserPromptSubmit hook: record this pane as actively running an agent.
# Lifecycle pair with notify-running-end.sh (Stop hook).

TMUX_BIN="/opt/homebrew/bin/tmux"
RUNNING_FILE="${AGENT_RUNNING_FILE:-/tmp/claude-running.queue}"
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

# Serialize the read-modify-write. Multiple agents commonly start together,
# and an unlocked shared .tmp file can silently discard another pane's row.
(
    /usr/bin/lockf -s -t 2 9 || exit 0
    TMP=$(mktemp "${RUNNING_FILE}.tmp.XXXXXX") || exit 0
    trap 'rm -f "$TMP"' EXIT

    if [[ -f "$RUNNING_FILE" ]]; then
        awk -F'\t' -v p="$PANE_ID" '$2 != p' "$RUNNING_FILE" > "$TMP"
    else
        : > "$TMP"
    fi

    # Format: TIMESTAMP PANE_ID TARGET CLIENT PROJECT SESSION WINDOW_NAME PANE_INDEX
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$TIMESTAMP" "$PANE_ID" "$TARGET" "$CLIENT" "$PROJECT" "$SESSION" "$WINDOW_NAME" "$PANE_INDEX" >> "$TMP"
    mv "$TMP" "$RUNNING_FILE"
) 9>"${RUNNING_FILE}.lock"
