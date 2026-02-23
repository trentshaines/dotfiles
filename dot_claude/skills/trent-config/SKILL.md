---
name: trent-config
description: Overview of Trent's development environment and dotfiles setup. Use this skill first to understand the overall setup, then reference specific skills for details. CRITICAL - Trent uses fish shell, NOT zsh.
---

# Trent's Development Environment

## Quick Reference

| Tool | Purpose | Skill | Config Location |
|------|---------|-------|-----------------|
| **fish** | Shell (PRIMARY) | `trent-fish` | `~/.config/fish/config.fish` |
| **chezmoi** | Dotfile management | `trent-chezmoi` | `~/.local/share/chezmoi/` |
| **tmux** | Terminal multiplexer | `trent-tmux` | `~/.tmux.conf` |
| **sesh** | Tmux session switcher | `trent-tmux` | - |
| **tmuxinator** | Tmux session templates | `trent-tmux` | `~/.config/tmuxinator/*.yml` |
| **lazyvim** | Neovim distribution | `trent-lazyvim` | `~/.config/nvim/` |
| **aerospace** | Window manager | `trent-aerospace` | `~/.config/aerospace/aerospace.toml` |
| **obsidian** | Notes/Zettelkasten | `trent-obsidian` | `~/Documents/obsidian-vault/` |
| **starship** | Prompt | - | `~/.config/starship.toml` |

## Critical Facts

1. **Fish is the primary shell** - Always add aliases/functions to fish, never zsh
2. **Chezmoi manages dotfiles** - After editing configs, sync with `chezmoi add` or `cadd`
3. **Tmux uses 1-based indexing** - Panes and windows start at 1, not 0
4. **Vi mode everywhere** - Fish, tmux, and nvim all use vi keybindings

## Machines

| Name | Address | Access |
|------|---------|--------|
| Mac Mini | `100.77.152.106` | `mm` alias (SSH + port forward 3000, 8000) |

## Common Paths

```
~/.config/fish/           # Fish shell config
~/.config/nvim/           # Neovim/LazyVim config
~/.config/tmuxinator/     # Tmux session templates
~/.config/aerospace/      # Window manager config
~/.local/share/chezmoi/   # Chezmoi source (dotfiles repo)
~/.claude/skills/         # Claude Code skills
~/git/                    # Git projects
```

## Chezmoi Workflow

After editing any config file:
```fish
cadd                      # Re-add changed files to chezmoi
# or
chezmoi add ~/.config/... # Add specific file
```

Then commit in `~/.local/share/chezmoi/`.

## Key Aliases

```fish
# Config editing
ef                        # Edit fish config
v                         # Neovim

# Chezmoi
cadd                      # chezmoi re-add
capply                    # chezmoi apply

# Tmux
ts                        # Session switcher (fzf)
tnw                       # New window with 3-pane layout

# SSH
mm                        # SSH to Mac Mini with port forwards
```

## Tmuxinator Sessions

- `config` - Dotfiles editing (root: ~/.config)
- `admin` - System monitoring (btop + terminals)
- `default` - Template for project sessions

## When Editing Configs

1. Use the appropriate skill for detailed help (trent-fish, trent-tmux, trent-lazyvim, etc.)
2. Remember to sync to chezmoi after changes
3. Fish syntax differs from bash/zsh:
   - `set -gx VAR value` not `export VAR=value`
   - `(command)` not `$(command)`
   - Functions go in `~/.config/fish/functions/name.fish`

## Skills Index

- **trent-fish** - Shell config, aliases, functions, vi mode
- **trent-tmux** - Sessions, tmuxinator templates, sesh, window layouts
- **trent-chezmoi** - Dotfile management, syncing, ansible playbooks
- **trent-lazyvim** - Neovim config, plugins, LSP, keybindings
- **trent-aerospace** - Window management, workspaces, tiling
- **trent-obsidian** - Zettelkasten notes, vault search
- **trent-claude-skills** - Creating and managing skills
