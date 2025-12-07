# Pastebin - fuzzy find and copy saved snippets
function pastebin
    set -l keyfile "$HOME/.pastebin"

    if not test -f "$keyfile"
        echo "Pastebin file not found: $keyfile"
        return 1
    end

    cut -d'=' -f1 "$keyfile" \
        | fzf --preview "grep '^{}=' '$keyfile' | cut -d'=' -f2-" \
              --bind "enter:execute-silent(echo -n (grep '^{}=' '$keyfile' | cut -d'=' -f2-) | pbcopy)+abort"
end
