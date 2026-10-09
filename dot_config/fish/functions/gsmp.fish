function __gsmp_first_worktree
    git worktree list --porcelain 2>/dev/null | awk '/^worktree / { sub(/^worktree /, ""); print; exit }'
end

function __gsmp_owner_for_branch
    set -l branch_name $argv[1]
    git worktree list --porcelain 2>/dev/null | awk -v branch_name="$branch_name" '
        /^worktree / { worktree_path = substr($0, 10) }
        $0 == "branch refs/heads/" branch_name { print worktree_path; exit }
    '
end

function __gsmp_reclaim_base_branch
    set -l target_branch $argv[1]

    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "gsmp: not in a git repository" >&2
        return 1
    end

    git worktree prune >/dev/null 2>&1

    set -l base_path (__gsmp_first_worktree)
    set -l current_path (git rev-parse --show-toplevel 2>/dev/null)
    or return 1

    if test -n "$base_path" -a "$current_path" != "$base_path"
        cd "$base_path"
        or return 1
        echo "gsmp: switched to base worktree $base_path"
        set current_path "$base_path"
    end

    set -l owner_path (__gsmp_owner_for_branch "$target_branch")
    if test -n "$owner_path" -a "$owner_path" != "$current_path"
        echo "gsmp: removing $owner_path because it owns $target_branch"
        git worktree remove "$owner_path"
        or return $status
    end
end

function gsmp --description "Switch to master/main and pull, reclaiming the base branch from linked worktrees"
    set -l target_branch main
    if git rev-parse --verify --quiet refs/heads/master >/dev/null 2>&1
        set target_branch master
    end

    __gsmp_reclaim_base_branch "$target_branch"
    or return $status

    git switch "$target_branch" && git pull
end
