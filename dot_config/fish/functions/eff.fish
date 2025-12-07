# Edit fish function - fuzzy find and edit
function eff
    set -l func_name (ls ~/.config/fish/functions/*.fish | xargs -n1 basename | fzf --preview 'bat --color=always ~/.config/fish/functions/{}' --preview-window=right:60%)

    if test -n "$func_name"
        nvim ~/.config/fish/functions/$func_name
    end
end
