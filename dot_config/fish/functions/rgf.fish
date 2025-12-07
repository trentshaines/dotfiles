# Search through ripgrep, then filter with fzf after entering
# Usage: rgf [search terms] [-f pattern] [more terms]
function rgf
    set -l file_globs
    set -l terms

    # Parse args
    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case -f --file
                set i (math $i + 1)
                if test $i -gt (count $argv)
                    echo "Error: -f requires a file pattern"
                    return 1
                end
                set -l glob $argv[$i]
                # If user didn't include '*' explicitly, wrap with *
                if not string match -q "*\**" -- $glob
                    set glob "*$glob*"
                end
                set -a file_globs $glob
            case '*'
                set -a terms $argv[$i]
        end
        set i (math $i + 1)
    end

    # Default query if no terms provided
    set -l query (string join " " $terms)
    if test -z "$query"
        set query "TODO"
    end

    # Build ripgrep command
    set -l cmd rg --line-number --no-heading --color=always -S $query
    for glob in $file_globs
        set -a cmd -g $glob
    end

    # Execute ripgrep and pipe to fzf
    $cmd \
        | fzf --ansi --delimiter : \
              --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' \
              --bind 'enter:execute(nvim +{2} {1} < /dev/tty > /dev/tty 2>&1)'
end
