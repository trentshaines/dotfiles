# Switch worktree - fuzzy find by branch, create worktree if needed
function wts --description "Fuzzy switch between branches (creates worktree if needed)"
    # Prune stale worktree entries
    git worktree prune 2>/dev/null

    # Build worktree lookup: wt_branches[i] -> wt_paths[i]
    set -l wt_branches
    set -l wt_paths
    for line in (git worktree list 2>/dev/null | awk '{gsub(/\[|\]/, "", $3); print $3 "\t" $1}')
        set -a wt_branches (echo $line | cut -f1)
        set -a wt_paths (echo $line | cut -f2)
    end

    # Local branches sorted by most recent commit
    set -l branches (git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads/ 2>/dev/null)

    # Annotate branches with worktree paths
    set -l entries
    for branch in $branches
        set -l path ""
        for i in (seq (count $wt_branches))
            if test "$wt_branches[$i]" = "$branch"
                set path $wt_paths[$i]
                break
            end
        end
        if test -n "$path"
            set -a entries "✓ $branch -> $path"
        else
            set -a entries "  $branch"
        end
    end

    if test -z "$entries"
        echo "No branches found (not in a git repo?)"
        return 1
    end

    # fzf select
    set -l selected (printf '%s\n' $entries \
        | fzf --preview 'branch=$(echo {} | sed "s/^[✓ ]* //;s/ -> .*//"); git log --oneline --graph -n 10 $branch 2>/dev/null || echo "No commits"' \
              --preview-window=right:50% \
              --header '✓ = has worktree | Select branch')

    if test -z "$selected"
        return 0
    end

    # Check if it has a worktree (starts with ✓)
    if string match -q "✓*" -- $selected
        # Extract path and cd
        set -l path (echo $selected | sed 's/.* -> //')
        cd "$path"
        echo "Switched to: $path"
    else
        # No worktree - create one with awt
        set -l branch (echo $selected | sed 's/^  //')
        echo "Creating worktree for: $branch"
        awt $branch
    end

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
