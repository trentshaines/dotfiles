function awt --description "autowt with auto-confirm"
    # Prune stale worktree refs (e.g. from rm -rf'd worktree dirs)
    git worktree prune 2>/dev/null
    autowt $argv -y

    # Update tmux window name to match branch
    if set -q TMUX
        set -l branch (git rev-parse --abbrev-ref HEAD 2>/dev/null)
        if test -n "$branch" -a "$branch" != main -a "$branch" != master
            set -l wt ""
            if git rev-parse --git-common-dir 2>/dev/null | grep -q worktrees
                set wt "[wt]"
            end
            tmux rename-window "$branch$wt"
        end
    end
end
