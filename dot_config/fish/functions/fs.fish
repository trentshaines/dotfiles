# Fuzzy select and execute a fish function
function fs --description "Fuzzy find and run a fish function"
    set -l func_name (ls ~/.config/fish/functions/*.fish | xargs -n1 basename | sed 's/\.fish$//' | fzf --preview 'bat --color=always ~/.config/fish/functions/{}.fish' --preview-window=right:60%)

    if test -n "$func_name"
        echo "Running: $func_name"
        eval $func_name $argv
    end
end
