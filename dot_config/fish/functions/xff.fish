# Execute fish function with fzf
function xff --description "Execute fish function with fzf"
    set -l func (functions | fzf --preview 'functions {}' --preview-window=right:60%)
    if test -n "$func"
        echo "Running: $func"
        eval $func
    end
end
