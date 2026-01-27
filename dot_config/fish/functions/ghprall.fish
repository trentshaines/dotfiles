# Wrapper for portable bash script
# Source of truth: ~/.config/fish/bash-scripts/ghprall.sh
function ghprall --description "Commits, pushes, and creates a GitHub PR"
    ~/.config/fish/bash-scripts/ghprall.sh $argv
end
