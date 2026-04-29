#!/bin/bash
CLIENT_WIDTH=$(tmux display-message -p '#{client_width}')
CLIENT_HEIGHT=$(tmux display-message -p '#{client_height}')

tmux display-popup -E \
    -w 70% \
    -h 50% \
    -b rounded \
    -S "fg=#ff10f0" \
    -e "TMUX_CLIENT_WIDTH=$CLIENT_WIDTH" \
    -e "TMUX_CLIENT_HEIGHT=$CLIENT_HEIGHT" \
    "/bin/bash $HOME/.claude/scripts/claude-pick.sh"
