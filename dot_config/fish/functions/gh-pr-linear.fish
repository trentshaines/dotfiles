# Wrapper for portable bash script - used by Claude Code and interactive fish
# Source of truth: ~/.config/fish/bash-scripts/gh-pr-linear.sh
function gh-pr-linear --description "Create a GitHub PR with Linear ticket info pre-filled"
    ~/.config/fish/bash-scripts/gh-pr-linear.sh $argv
end
