# Switch worktree - fuzzy find and cd to worktree
function wts --description "Fuzzy switch between git worktrees"
    # Get worktree list from current repo (works from any worktree or main repo)
    set -l worktrees (git worktree list --porcelain 2>/dev/null | grep "^worktree " | sed 's/^worktree //')

    if test -z "$worktrees"
        echo "❌ No worktrees found (not in a git repo?)"
        return 1
    end

    # Use fzf to select worktree with preview showing recent commits
    set -l selected (printf '%s\n' $worktrees \
        | fzf --preview 'echo "📁 "(basename {})"\n" && git -C {} log --oneline --graph -n 10 2>/dev/null || echo "No commits"' \
              --preview-window=right:50% \
              --header 'Select worktree to switch to')

    if test -n "$selected"
        cd "$selected"
        echo "📂 Switched to: $selected"
    end
end
