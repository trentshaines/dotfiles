# Execute fish function with fzf
function xff --description "Execute fish function with fzf"
    set -l func_name (ls ~/.config/fish/functions/*.fish | xargs -n1 basename | sed 's/\.fish$//' | fzf --header '🚀 EXECUTE function' --preview 'functions {}' --preview-window=right:60%)
    if test -n "$func_name"
        echo "Running: $func_name"
        eval $func_name
    end
end
