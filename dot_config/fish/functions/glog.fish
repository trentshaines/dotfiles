# git log
function glog
    git log \
        --graph \
        --topo-order \
        --pretty='%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N' \
        --abbrev-commit \
        $argv
end
