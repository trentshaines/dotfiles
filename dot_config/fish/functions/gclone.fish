function gclone --description "Clone a git repo into ~/git/ and add to zoxide"
    if test -z "$argv[1]"
        echo "Usage: gclone <url>"
        return 1
    end

    set url $argv[1]
    set repo_name (basename $url .git)
    set dest ~/git/$repo_name

    git clone $url $dest
    and zoxide add $dest
    and echo "Cloned into $dest"
end
