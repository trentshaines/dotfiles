function __update_tmux_window_name --on-variable PWD --description "Auto-rename tmux window to branch name in worktrees"
    set -q TMUX; or return

    # Skip if the window was manually named (not by us)
    set -l prev_branch (tmux show-window-option -v @auto-branch 2>/dev/null)
    set -l prev_claude (tmux show-window-option -v @auto-claude 2>/dev/null)
    set -l current (tmux display-message -p '#W' 2>/dev/null)
    if test -n "$prev_branch" -a "$prev_branch" != "$current"
        # User manually renamed this window — don't touch it
        return
    end

    set -l branch (git rev-parse --abbrev-ref HEAD 2>/dev/null)
    test -n "$branch"; or return

    if test "$branch" = main -o "$branch" = master
        tmux set-option -w automatic-rename on 2>/dev/null
        tmux set-option -wu @auto-branch 2>/dev/null
        return
    end

    # Branch takes over — clear any Claude-set name

    set -l wt ""
    if git rev-parse --git-common-dir 2>/dev/null | grep -q worktrees
        set wt "[wt]"
    end

    set -l name "$branch$wt"
    tmux rename-window "$name"
    tmux set-option -w @auto-branch "$name" 2>/dev/null
    tmux set-option -wu @auto-claude 2>/dev/null
end
