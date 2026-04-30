#!/bin/bash
# UserPromptSubmit hook: user has engaged with the agent in this pane,
# so remove any pending notification for it from the picker queue.

TMUX_BIN="/opt/homebrew/bin/tmux"
PANE_ID="$TMUX_PANE"

[[ -z "$PANE_ID" ]] && exit 0

SESSION=$($TMUX_BIN display-message -t "$PANE_ID" -p '#{session_name}' 2>/dev/null) || exit 0
WINDOW=$($TMUX_BIN display-message -t "$PANE_ID" -p '#{window_index}' 2>/dev/null) || exit 0
PANE_INDEX=$($TMUX_BIN display-message -t "$PANE_ID" -p '#{pane_index}' 2>/dev/null) || exit 0

TARGET="$SESSION:$WINDOW.$PANE_INDEX"

exec "$HOME/.claude/scripts/claude-delete.sh" "$TARGET"
