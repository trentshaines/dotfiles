#!/bin/bash
# Wrapper that opens the Claude notification picker at the right height.
# Pre-counts queue entries so display-popup gets an exact -h value.

QUEUE="/tmp/claude-notifications.queue"

CLIENT_WIDTH=$(tmux display-message -p '#{client_width}')

COUNT=0
if [[ -f "$QUEUE" ]]; then
    while IFS=$'\t' read -r ts _ _ _ _ _ _ visited; do
        [[ "$visited" == "0" && "$ts" =~ ^[0-9]+$ ]] && (( COUNT++ ))
    done < "$QUEUE"
fi

# gum filter chrome: prompt + header = 2; cap results at 10
RESULTS=$(( COUNT < 10 ? COUNT : 10 ))
HEIGHT=$(( RESULTS + 4 ))
(( HEIGHT < 6 )) && HEIGHT=6

tmux display-popup -E \
    -w 70% \
    -h "$HEIGHT" \
    -e "TMUX_CLIENT_WIDTH=$CLIENT_WIDTH" \
    "/bin/bash $HOME/.claude/scripts/claude-pick.sh"
