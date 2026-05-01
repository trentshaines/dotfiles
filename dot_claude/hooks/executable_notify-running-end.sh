#!/bin/bash
# Stop hook: agent finished running in this pane.
# Lifecycle pair with notify-running-start.sh (UserPromptSubmit hook).

RUNNING_FILE="/tmp/claude-running.queue"
PANE_ID="$TMUX_PANE"

[[ -z "$PANE_ID" ]] && exit 0
[[ ! -f "$RUNNING_FILE" ]] && exit 0

awk -F'\t' -v p="$PANE_ID" '$2 != p' "$RUNNING_FILE" > "$RUNNING_FILE.tmp" && mv "$RUNNING_FILE.tmp" "$RUNNING_FILE"
