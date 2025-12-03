# switch branch fzf
function gs
    git branch \
        | fzf --preview 'git log --graph --topo-order \
                            --pretty="%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N" \
                            --abbrev-commit -n 20 (echo {} | sed "s/^[* ] //")' \
        | sed 's/^[* ] //' \
        | xargs git switch
end
