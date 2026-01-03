################################################################################
# Core Shell Setup
################################################################################

# Homebrew (must come first to set PATH)
eval (/opt/homebrew/bin/brew shellenv)

# Environment Variables
set -gx LS_COLORS "di=178:ln=180:so=181:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"
set -gx EDITOR nvim
set -gx PATH "$HOME/.local/bin" $PATH
set -gx PATH "/Applications/Rider.app/Contents/MacOS" $PATH
set -gx PATH "$HOME/bin" $PATH
set -gx PASSWORD_STORE_ENABLE_EXTENSIONS true

# Load secrets (API keys, tokens, etc.) - not tracked in dotfiles
if test -f ~/.config/fish/secrets.fish
    source ~/.config/fish/secrets.fish
end

################################################################################
# Essential Tools
################################################################################

# Starship prompt (after Homebrew PATH is set)
starship init fish | source

# Zoxide (smart cd)
zoxide init fish | source

# fzf (fuzzy finder)
fzf --fish | source

# NVM (Node Version Manager) - fish native version via nvm.fish
# Installed via: fisher install jorgebucaran/nvm.fish
# Usage: nvm install 20, nvm use 20, nvm list
# Auto-installed by fisher, no additional setup needed

################################################################################
# Aliases
################################################################################

# Shell management
alias ef='nvim ~/.config/fish/config.fish'
alias elf='nvim ~/.config/fish/conf.d/local.fish'
alias ez='nvim ~/.zshrc' # Keep for editing zsh if needed
alias sz='source ~/.zshrc' # Keep for zsh
alias clauded='claude --dangerously-skip-permissions'
alias cc='claude'
alias ccr='claude --resume'
alias ccd='claude --dangerously-skip-permissions'
alias ccdc='claude --dangerously-skip-permissions --chrome'
alias ccrd='claude --resume --dangerously-skip-permissions'
alias ccrdc='claude --resume --dangerously-skip-permissions --chrome'

# Better defaults with modern tools
alias cat='bat'
alias ls='eza'
alias ll='eza -l'
alias la='eza -la'
alias tree='eza --tree'

# Chezmoi dotfile management
alias cadd='chezmoi re-add'
alias capply='chezmoi apply'

# Other
alias fcopy='pbcopy < (fzf)'

# Tmux aliases
alias ta='tmux attach -t'
alias tn='tmux new -s'
alias tls='tmux ls'
alias tk='tmux kill-session -t'

# Neovim alias
alias v='nvim'

# IDE Launchers
alias ri='nohup rider . >/dev/null 2>&1 &'

# Git aliases
alias gc='git commit -m'
alias gca='git add . && git commit -a -m'
alias gp='git push origin HEAD'
alias gpu='git pull origin'
alias gst='git status'
alias gdiff='git diff'
alias gco='git checkout'
alias gb='git branch'
alias gba='git branch -a'
alias gadd='git add'
alias ga='git add -p'
alias gcoall='git checkout -- .'
alias gcb='git checkout -b'
alias gr='git remote'
alias gre='git reset'
alias gsmp='git rev-parse --verify --quiet master >/dev/null && git switch master && git pull || git switch main && git pull'
alias ghpr='gh pr create -f --draft && gh pr view --web'
alias ghprw='gh pr view --web'

# Python aliases
alias python='python3'
alias pip='pip3'
alias cvenv='python3 -m venv .venv'
alias svenv='source .venv/bin/activate'

# Other
alias proxyemr='ssh -N -D 18080 tick'
alias uf='fzf-bookmark-opener'
alias fkill='ps -ax | fzf | awk \'{print $1}\' | xargs kill'

################################################################################
# Vi Mode
################################################################################

# Enable vi mode in fish
fish_vi_key_bindings

# Remove mode indicator from prompt (use cursor shape instead)
function fish_mode_prompt
    # Empty function - no text indicator
end

# Change cursor shape for different vi modes
set -g fish_cursor_default block
set -g fish_cursor_insert line
set -g fish_cursor_replace_one underscore
set -g fish_cursor_visual block

# Edit command in vim with 'v' in normal mode (like zsh)
function fish_user_key_bindings
    fish_vi_key_bindings
    # Edit command buffer with 'v' in normal mode
    bind -M default v edit_command_buffer
    # Also keep Ctrl-E as alternative
    bind -M insert \ce edit_command_buffer
    bind -M default \ce edit_command_buffer
end

################################################################################
# Auto-create home tmux session
################################################################################

if command -v tmux &>/dev/null; and not set -q TMUX
    # Create a "home" session if it doesn't exist
    tmux has-session -t home 2>/dev/null; or tmux new-session -d -s home -c ~
end

set -Ux PYENV_ROOT $HOME/.pyenv
fish_add_path $PYENV_ROOT/bin
pyenv init - | source
pyenv virtualenv-init - | source

if [ -f '/Users/trent/Downloads/google-cloud-sdk/path.fish.inc' ]
    . '/Users/trent/Downloads/google-cloud-sdk/path.fish.inc'
end

# Claude Code (conditional on DECAGON env var)
if test "$DECAGON" = true
    bass source ~/git/duet/claude_code.env
end
