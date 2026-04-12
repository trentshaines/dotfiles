# Sesh + Tmuxinator - fuzzy session selector
function ts
    # Get all tmuxinator templates (excluding default.yml)
    set -l tmuxinator_templates (ls ~/.config/tmuxinator/*.yml 2>/dev/null | xargs -n1 basename | sed 's/\.yml$//' | grep -v "^default\$")

    # Combine: tmuxinator templates + sesh list
    set -l session (printf '%s\n' $tmuxinator_templates (sesh list) | fzf)

    if test -n "$session"
        if tmux has-session -t "$session" 2>/dev/null
            # Session already exists, connect to it
            sesh connect "$session"
        else if test -f ~/.config/tmuxinator/$session.yml
            # It's a tmuxinator template, start it
            tmuxinator start "$session"
        else
            # Use default template for new directories
            tmuxinator start default "$session"
        end
    end
end
