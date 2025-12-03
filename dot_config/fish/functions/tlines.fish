# Clipboard integration
function tlines
    set -l n (test -n "$argv[1]"; and echo $argv[1]; or echo "10")
    tmux capture-pane -p | tail -n (math "$n + 2") | head -n "$n" | pbcopy
end
