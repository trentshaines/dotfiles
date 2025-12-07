# Browse JSON structure interactively
function jqb
    set -l file $argv[1]

    if test -z "$file"
        echo "Usage: jqb <json-file>"
        return 1
    end

    # Get all paths in the JSON
    jq -r 'paths(scalars) as $p | "\($p | join(".")): \(getpath($p))"' "$file" \
        | fzf --preview "jq -C '.{}' '$file' 2>/dev/null || jq -C '.' '$file' | head -20" \
              --preview-window=right:60% \
              --bind "enter:execute(echo {} | cut -d: -f1 | xargs -I@ jq -C '.@' '$file' | less -R)"
end
