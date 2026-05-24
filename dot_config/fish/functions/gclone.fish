function gclone --description "Clone a git repo into ~/git/ (with folder picker) and add to zoxide"
    if test -z "$argv[1]"
        echo "Usage: gclone <url> [folder]"
        return 1
    end

    set -l url $argv[1]
    set -l repo_name (basename $url .git)

    set -l target_dir
    if test -n "$argv[2]"
        set target_dir ~/git/$argv[2]
    else
        set -l choices ". (root)"
        for d in ~/git/*/
            test -d "$d/.git" && continue
            set -a choices (basename $d)
        end

        set -l pick (printf '%s\n' $choices | fzf --prompt="Clone into ~/git/… > ")
        test -z "$pick" && echo "Cancelled." && return 1

        if test "$pick" = ". (root)"
            set target_dir ~/git
        else
            set target_dir ~/git/$pick
        end
    end

    set -l dest $target_dir/$repo_name
    mkdir -p $target_dir
    git clone $url $dest
    and zoxide add $dest
    and echo "Cloned into $dest"
end
