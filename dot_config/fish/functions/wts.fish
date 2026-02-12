# Switch worktree - fuzzy find by branch, create worktree if needed
function wts --description "Fuzzy switch between branches (creates worktree if needed)"
    # Prune stale worktree entries
    git worktree prune 2>/dev/null

    # Use awk to efficiently join branches with worktrees
    set -l entries (begin
        # First output worktree branches with paths
        git worktree list 2>/dev/null | awk '{gsub(/\[|\]/, "", $3); print $3 "\t" $1}'
        # Then output all remote branches
        git branch -r 2>/dev/null | grep -v HEAD | sed 's/.*origin\///'
    end | awk -F'\t' '
        NF == 2 { wt[$1] = $2; next }
        {
            branch = $1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", branch)
            if (branch in wt) {
                print "✓ " branch " -> " wt[branch]
                delete wt[branch]
            } else {
                print "  " branch
            }
        }
        END {
            for (branch in wt) {
                print "✓ " branch " -> " wt[branch]
            }
        }
    ' | sort -u)

    if test -z "$entries"
        echo "No branches found (not in a git repo?)"
        return 1
    end

    # fzf select
    set -l selected (printf '%s\n' $entries \
        | fzf --preview 'branch=$(echo {} | sed "s/^[✓ ]* //;s/ -> .*//"); git log --oneline --graph -n 10 origin/$branch 2>/dev/null || git log --oneline --graph -n 10 $branch 2>/dev/null || echo "No commits"' \
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
end
