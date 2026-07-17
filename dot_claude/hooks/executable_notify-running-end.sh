#!/bin/bash
# Stop hook: agent finished running in this pane.
# Lifecycle pair with notify-running-start.sh (UserPromptSubmit hook).

RUNNING_FILE="${AGENT_RUNNING_FILE:-/tmp/claude-running.queue}"
PANE_ID="$TMUX_PANE"

[[ -z "$PANE_ID" ]] && exit 0

(
    /usr/bin/lockf -s -t 2 9 || exit 0
    [[ ! -f "$RUNNING_FILE" ]] && exit 0
    TMP=$(mktemp "${RUNNING_FILE}.tmp.XXXXXX") || exit 0
    trap 'rm -f "$TMP"' EXIT
    if awk -F'\t' -v p="$PANE_ID" '$2 != p' "$RUNNING_FILE" > "$TMP"; then
        mv "$TMP" "$RUNNING_FILE"
    fi
) 9>"${RUNNING_FILE}.lock"
