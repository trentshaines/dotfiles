# Pass find - fuzzy password search
function pf
    set -l password (find ~/.password-store -name "*.gpg" -type f \
        | sed 's|^.*\.password-store/||' \
        | sed 's|\.gpg$||' \
        | fzf --preview 'pass show {} 2>/dev/null' \
              --preview-window=right:40% \
              --header 'Enter: copy | Ctrl-o: show | Ctrl-e: edit')

    test -n "$password"; and pass -c "$password"
end
