# Scratch files
function scratch
    set -l label (test -n "$argv[1]"; and echo $argv[1]; or echo "scratch")
    set -l timestamp (date "+%Y-%m-%d_%H-%M-%S")
    set -l file ~/Documents/Scratch/{$label}_{$timestamp}.txt
    nvim "$file"
end
