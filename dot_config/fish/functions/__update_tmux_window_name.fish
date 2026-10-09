function __update_tmux_window_name --on-variable PWD --description "Auto-rename tmux window to branch name in worktrees"
    set -q TMUX; or return
    set -q TMUX_PANE; or return
    set -l target $TMUX_PANE
    test -z (tmux show-options -wqv -t $target @manual-window-name); or return

    # Skip if the window was manually named (not by us)
    set -l prev_branch (tmux show-window-option -t $target -v @auto-branch 2>/dev/null)
    set -l prev_claude (tmux show-window-option -t $target -v @auto-claude 2>/dev/null)
    set -l current (tmux display-message -t $target -p '#W' 2>/dev/null)
    if test -n "$prev_branch" -a "$prev_branch" != "$current"
        # User manually renamed this window — don't touch it
        return
    end
    if test -n "$prev_claude" -a "$prev_claude" != "$current"
        return
    end

    set -l branch (git rev-parse --abbrev-ref HEAD 2>/dev/null)
    test -n "$branch"; or return

    if test "$branch" = main -o "$branch" = master
        tmux set-option -w -t $target automatic-rename on 2>/dev/null
        tmux set-option -wu -t $target @auto-branch 2>/dev/null
        return
    end

    # Branch takes over — clear any Claude-set name

    set -l wt ""
    if git rev-parse --git-common-dir 2>/dev/null | grep -q worktrees
        set wt "[wt]"
    end

    set -l name "$branch$wt"
    tmux rename-window -t $target "$name"
    tmux set-option -w -t $target @auto-branch "$name" 2>/dev/null
    tmux set-option -wu -t $target @auto-claude 2>/dev/null
end
