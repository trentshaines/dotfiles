# Create new git directory and open with tmuxinator
function tns
    set -l project_path $argv[1]
    set -l template (test -n "$argv[2]"; and echo $argv[2]; or echo "default")

    if test -z "$project_path"
        echo "Usage: tns <path> [template]"
        echo "  Creates ~/git/<path>, initializes git, and opens with tmuxinator"
        echo "  Examples: tns myproject, tns metr/myproject"
        return 1
    end

    set -l project_dir "$HOME/git/$project_path"
    set -l project_name (basename $project_path)

    # Save original directory
    set -l original_dir (pwd)

    # Check if directory already exists
    if test -d "$project_dir"
        echo "Directory $project_dir already exists. Opening with tmuxinator..."
    else
        echo "Creating $project_dir..."
        mkdir -p "$project_dir"
        and cd "$project_dir"
        and git init
        and echo "# $project_name" > README.md
        echo "Initialized git repository at $project_dir"
        # Restore original directory
        cd "$original_dir"
    end

    # Check if tmux session already exists
    if tmux has-session -t "$project_name" 2>/dev/null
        echo "Session $project_name already exists, connecting..."
        sesh connect "$project_name"
    else if test -f ~/.config/tmuxinator/$template.yml
        # Use specified template
        echo "Starting tmuxinator with $template template..."
        tmuxinator start "$template" "$project_dir"
    else
        echo "Template $template not found, using default..."
        tmuxinator start default "$project_dir"
    end
end
