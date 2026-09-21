#!/usr/bin/env bash
# Stable runtime paths for tmux hooks started before fish/mise initialization.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH:/usr/bin:/bin:/usr/sbin:/sbin"
exec python3 "$HOME/.config/tmux/assistant-state.py" "$@"
