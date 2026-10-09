# Install the naming policy before config.fish invokes branch naming.
if status is-interactive; and set -q TMUX
    /opt/homebrew/bin/tmux source-file "$HOME/.config/tmux/window-names.conf"
end
