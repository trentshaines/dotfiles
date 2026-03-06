# Switch worktree - fuzzy find by branch, create worktree if needed
function wts --description "Fuzzy switch between branches (creates worktree if needed)"
    # Prune stale worktree entries
    git worktree prune 2>/dev/null

    # Build worktree lookup: wt_branches[i] -> wt_paths[i]
    set -l wt_branches
    set -l wt_paths
    for line in (git worktree list 2>/dev/null | awk '{gsub(/\[|\]/, "", $3); print $3 "\t" $1}')
        set -a wt_branches (string split \t -- $line)[1]
        set -a wt_paths (string split \t -- $line)[2]
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
            set -a entries "+ $branch -> $path"
        else
            set -a entries "  $branch"
        end
    end

    if test (count $entries) -eq 0
        echo "No branches found (not in a git repo?)"
        return 1
    end

    # fzf select - preview script is bash to avoid fish quoting issues
    set -l selected (printf '%s\n' $entries \
        | fzf --preview '~/bin/wts-preview.sh {}' \
              --preview-window=right:50% \
              --header '+ = has worktree | Select branch')

    if test -z "$selected"
        return 0
    end

    # Check if it has a worktree (starts with +)
    if string match -q "+*" -- "$selected"
        set -l path (string replace -r '.* -> ' '' -- "$selected")
        cd "$path"
        echo "Switched to: $path"
    else
        set -l branch (string trim -- "$selected")
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
