#!/bin/bash

# Capture tmux context at hook time
SESSION=$(tmux display-message -p '#{session_name}')
WINDOW=$(tmux display-message -p '#{window_index}')
PANE=$TMUX_PANE
PROJECT=$(basename "$PWD")

# Build the switch command
SWITCH_CMD="osascript -e 'activate application \"Alacritty\"' && tmux switch-client -t '$SESSION' && tmux select-window -t '$SESSION:$WINDOW' && tmux select-pane -t '$PANE'"

# Send notification
terminal-notifier \
  -title "Claude Code" \
  -subtitle "$PROJECT" \
  -message "Task completed" \
  -sound Glass \
  -execute "$SWITCH_CMD"
