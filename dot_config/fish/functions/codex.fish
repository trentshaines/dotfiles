function codex --description 'Keep tmux Codex conversations local to their panes'
    if set -q TMUX_PANE
        bash "$HOME/.config/tmux/codex-launch.sh" $argv
    else
        command codex $argv
    end
end
