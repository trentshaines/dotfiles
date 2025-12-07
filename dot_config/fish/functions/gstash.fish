# Interactive git stash manager with preview
function gstash
    set -l stash (git stash list --format="%C(yellow)%gd%C(reset) - %C(cyan)%cr%C(reset) - %s" \
        | fzf --ansi --no-sort --reverse --preview 'git stash show -p --color=always (echo {} | cut -d" " -f1)' \
              --preview-window=right:60% \
              --bind 'ctrl-d:execute(git stash drop (echo {} | cut -d" " -f1))+reload(git stash list --format="%C(yellow)%gd%C(reset) - %C(cyan)%cr%C(reset) - %s")' \
              --bind 'ctrl-p:execute(git stash pop (echo {} | cut -d" " -f1))' \
              --header 'Enter: apply | Ctrl-p: pop | Ctrl-d: drop' \
        | cut -d" " -f1)

    test -n "$stash"; and git stash apply "$stash"
end
