# Smart session attach/create
function t
    if test -n "$argv[1]"
        # If you pass a name, try to attach; if it doesn't exist, create it
        tmux attach -t "$argv[1]" 2>/dev/null; or tmux new -s "$argv[1]"
    else
        # No name → just attach to the last used session, or create a default one
        tmux attach 2>/dev/null; or tmux new -s default
    end
end
