# git add, commit, push in one command
function acp
    set -l msg "$argv"
    if test -z "$msg"
        set msg "update"
    end
    git add -A && git commit -m "$msg" && git push
end
