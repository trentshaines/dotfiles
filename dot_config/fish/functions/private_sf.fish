# Source Fish config
function sf --description 'Source fish config and local settings'
    source ~/.config/fish/config.fish
    source ~/.config/fish/conf.d/local.fish
    echo "Sourced fish config and local settings"
end
