# Fuzzy file finder -> nvim
function vf
    set -l file (fzf)
    and nvim "$file"
end
