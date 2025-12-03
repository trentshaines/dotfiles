# Sesh + Tmuxinator - fuzzy session selector
function ts
    # Get all tmuxinator templates (excluding default.yml)
    set -l tmuxinator_templates (ls ~/.config/tmuxinator/*.yml 2>/dev/null | xargs -n1 basename | sed 's/\.yml$//' | grep -v "^default\$")

    # Combine: "home" + tmuxinator templates + sesh list
    set -l session (echo -e "home\n$tmuxinator_templates\n"(sesh list) | fzf)

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
