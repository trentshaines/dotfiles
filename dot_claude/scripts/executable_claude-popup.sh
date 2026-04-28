#!/bin/bash
CLIENT_WIDTH=$(tmux display-message -p '#{client_width}')

tmux display-popup -E \
    -w 70% \
    -h 50% \
    -e "TMUX_CLIENT_WIDTH=$CLIENT_WIDTH" \
    "/bin/bash $HOME/.claude/scripts/claude-pick.sh"
