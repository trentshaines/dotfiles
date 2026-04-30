function gd --description 'Open diffview.nvim from CLI'
    if test (count $argv) -eq 0
        nvim +DiffviewOpen
    else
        nvim "+DiffviewOpen $argv"
    end
end
