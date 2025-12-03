# Cursor Find
function cf
    echo "Scanning for directories (~/git/*, ~/git/*/services/*, ~/git/*/libs/*) for Cursor..."

    set -l selected_dir (find ~/git -maxdepth 1 -mindepth 1 -type d; \
                         find ~/git -mindepth 3 -maxdepth 3 -path '*/services/*' -type d; \
                         find ~/git -mindepth 3 -maxdepth 3 -path '*/libs/*' -type d 2>/dev/null \
                         | sort -u \
                         | fzf --prompt="Select Project/Service/Lib Dir > ")

    if test -n "$selected_dir"
        if test -d "$selected_dir"
            echo "Opening '$selected_dir' with Cursor..."
            cursor "$selected_dir"
        else
            echo "Error: '$selected_dir' is not a valid directory." >&2
            return 1
        end
    else
        echo "No directory selected for Cursor."
    end
end
