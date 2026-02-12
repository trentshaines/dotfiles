function awt --description "autowt with auto-confirm"
    # Prune stale worktree refs (e.g. from rm -rf'd worktree dirs)
    git worktree prune 2>/dev/null
    autowt $argv -y
end
