# Create new tmux window with 3-pane layout (nvim, shell, claude)
function tnw
    # Get the session's root directory
    set -l session_path (tmux display-message -p '#{session_path}')

    tmux new-window -c "$session_path" \; \
        split-window -v -c "$session_path" \; \
        split-window -v -c "$session_path" \; \
        select-layout main-horizontal \; \
        select-pane -t 1 \; \
        send-keys 'nvim' C-m \; \
        select-pane -t 3 \; \
        send-keys 'claude --resume' C-m \; \
        select-pane -t 2
end
