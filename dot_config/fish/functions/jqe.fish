# Interactive JSON explorer with jq
function jqe
    set -l file $argv[1]

    if test -z "$file"
        echo "Usage: jqe <json-file>"
        return 1
    end

    echo '' | fzf --print-query --preview "jq -C {q} '$file'" \
        --preview-window=up:90% \
        --header 'Enter JQ query (start with . for root)' \
        --query '.' \
        --bind "enter:execute(jq -C {q} '$file' | less -R)"
end
