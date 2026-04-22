function wtc --description "Clean up merged worktrees across all ~/git repos"
    set -l git_root ~/git
    set -l dry_run false

    for arg in $argv
        if test "$arg" = --dry-run -o "$arg" = -n
            set dry_run true
        end
    end

    set -l total_removed 0
    set -l total_switched 0

    for repo_path in $git_root/*/
        # Only process main repos (.git directory, not .git file used by linked worktrees)
        test -d "$repo_path/.git" || continue

        set -l repo_name (basename $repo_path)

        # Quick skip: no linked worktrees
        set -l wt_count (git -C "$repo_path" worktree list 2>/dev/null | wc -l | string trim)
        test "$wt_count" -le 1 && continue

        git -C "$repo_path" worktree prune 2>/dev/null

        # Detect base branch
        set -l base_branch (git -C "$repo_path" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
            | string replace -r '^origin/' '')
        if test -z "$base_branch"
            for b in main master
                if git -C "$repo_path" show-ref --verify --quiet "refs/heads/$b"
                    set base_branch $b
                    break
                end
            end
        end
        if test -z "$base_branch"
            echo "[$repo_name] cannot detect base branch, skipping"
            continue
        end

        echo ""
        echo "[$repo_name]"

        # Parse worktrees via --porcelain (handles paths with spaces)
        set -l current_path ""
        set -l is_first_wt true
        set -l main_wt_path ""
        set -l wt_paths
        set -l wt_branches

        for line in (git -C "$repo_path" worktree list --porcelain 2>/dev/null)
            if string match -q "worktree *" -- "$line"
                set current_path (string replace "worktree " "" -- "$line")
            else if string match -q "branch *" -- "$line"
                set -l branch (string replace "branch refs/heads/" "" -- "$line")
                if test "$is_first_wt" = true
                    set is_first_wt false
                    set main_wt_path $current_path
                    # Ensure main worktree is on base branch
                    set -l current_branch (git -C "$current_path" rev-parse --abbrev-ref HEAD 2>/dev/null)
                    if test "$current_branch" != "$base_branch"
                        set -l dirty (git -C "$current_path" status --porcelain 2>/dev/null | string trim)
                        if test -n "$dirty"
                            echo "  ⚠ main worktree on '$current_branch' with uncommitted changes, skipping switch"
                        else
                            echo "  → switching main worktree from '$current_branch' to '$base_branch'"
                            if test "$dry_run" = false
                                git -C "$current_path" checkout "$base_branch" 2>/dev/null
                            end
                            set total_switched (math $total_switched + 1)
                        end
                    end
                else
                    set -a wt_paths $current_path
                    set -a wt_branches $branch
                end
            end
            # detached/bare entries have no "branch" line — silently skipped
        end

        test (count $wt_branches) -eq 0 && continue

        # Locally merged branches (fast, no network)
        set -l merged_local (git -C "$repo_path" branch --merged "$base_branch" \
            --format='%(refname:short)' 2>/dev/null)

        # Parallel gh pr checks for branches not caught locally
        set -l tmpdir (mktemp -d)
        set -l gh_repo (cd "$repo_path" && gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)

        if test -n "$gh_repo"
            for branch in $wt_branches
                if not contains -- $branch $merged_local
                    set -l safe (string replace -a '/' '_' -- "$branch")
                    gh pr view "$branch" --repo "$gh_repo" --json state -q '.state' \
                        > "$tmpdir/$safe" 2>/dev/null &
                end
            end
            wait
        end

        # Process each linked worktree
        for i in (seq (count $wt_branches))
            set -l wt_path $wt_paths[$i]
            set -l branch $wt_branches[$i]
            set -l merged false
            set -l reason ""

            if contains -- $branch $merged_local
                set merged true
                set reason "merged"
            else if test -n "$gh_repo"
                set -l safe (string replace -a '/' '_' -- "$branch")
                set -l state (cat "$tmpdir/$safe" 2>/dev/null | string trim | string upper)
                if test "$state" = MERGED
                    set merged true
                    set reason "PR merged"
                end
            end

            if test "$merged" = true
                set total_removed (math $total_removed + 1)
                if test "$dry_run" = true
                    echo "  ~ would remove: $branch ($reason)"
                else
                    echo "  → removing: $branch ($reason)"
                    git -C "$repo_path" worktree remove "$wt_path" --force 2>/dev/null
                    git -C "$repo_path" branch -d "$branch" 2>/dev/null
                end
            else
                echo "  · keeping: $branch"
            end
        end

        rm -rf $tmpdir
    end

    echo ""
    if test "$dry_run" = true
        echo "Dry run complete — would remove $total_removed worktree(s), switch $total_switched repo(s)"
    else
        echo "Done — removed $total_removed worktree(s), switched $total_switched repo(s) to base branch"
    end
end
