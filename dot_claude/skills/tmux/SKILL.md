---
name: tmux
description: Help with tmux, tmuxinator, and sesh session management. Use when the user asks about tmux sessions, tmuxinator templates, session switching, or terminal multiplexing.
---

# Tmux Session Management Skill

## Overview

This system uses tmux with tmuxinator templates and sesh for powerful session management.

## Configuration Locations

- **Tmuxinator templates**: `~/.config/tmuxinator/*.yml`
- **Tmux config**: `~/.tmux.conf`
- **Zsh tmux aliases/functions**: `~/.zshrc` (lines 37-72)
- **Active sessions**: Check with `tmux ls` or `sesh list`

## CRITICAL: Tmux Pane Indexing

**IMPORTANT**: This tmux configuration uses **1-based indexing** for both windows and panes (set in `~/.tmux.conf`):
```tmux
set -g base-index 1
set -g pane-base-index 1
```

This means:
- **Panes start at 1, not 0**
- First pane created = pane 1
- Second pane = pane 2
- Third pane = pane 3

When writing shell functions or tmux commands that target specific panes, always use 1-based indexing:
```bash
select-pane -t 1  # First pane
select-pane -t 2  # Second pane
select-pane -t 3  # Third pane
```

To check pane numbers visually in tmux: `prefix + q` (Ctrl+Space then q)

## Tmuxinator Templates

### Current Templates

1. **default.yml** - Flexible project template
   - Takes directory argument: `tmuxinator start default ~/path`
   - Layout: nvim (top 70%), terminal + claude (bottom)
   - Dynamic session naming based on directory

2. **admin.yml** - System monitoring
   - Fixed name: "admin"
   - Layout: btop (left column), 2 terminals (right)
   - Purpose: System monitoring and administration

3. **config.yml** - Dotfiles editing
   - Fixed name: "config"
   - Root: `~/.config`
   - Layout: nvim (top 70%), terminal + claude (bottom)

### Template Structure

```yaml
---
name: session-name  # Fixed name (or use <%= File.basename(...) %> for dynamic)
root: ~/path        # Working directory

on_project_start: tmux resize-pane -t name:0.0 -y 70%  # Optional startup commands

windows:
  - window-name:
      layout: main-horizontal  # or main-vertical, tiled, even-horizontal, etc.
      panes:
        - nvim                 # Command to run in pane 1
        - # empty terminal     # Empty pane (interactive shell)
        - claude --resume      # Command for pane 3
```

### Common Layouts

- `main-horizontal` - Top pane large, others stacked below
- `main-vertical` - Left pane large, others stacked right
- `tiled` - All panes equal size
- `even-horizontal` - Panes side-by-side equal width
- `even-vertical` - Panes top-to-bottom equal height

## Session Management with `sf`

The `sf` function (defined in `~/.zshrc:53-72`) is the main session switcher:

```bash
sf  # Opens fzf with: "home" + tmuxinator templates + active sessions
```

### How `sf` Works

1. Lists all tmuxinator templates (except default.yml)
2. Adds "home" as an option
3. Shows all active tmux sessions from `sesh list`
4. On selection:
   - If session exists → attach with `sesh connect`
   - If tmuxinator template exists → `tmuxinator start <template>`
   - Otherwise → `tmuxinator start default <name>` (creates new project session)

### Key Insight

Template names come from the **filename** (e.g., `admin.yml` → "admin" in fzf), but the actual tmux session name comes from the `name:` field in the YAML file.

## Tmux Aliases

From `~/.zshrc`:

```bash
ta <name>   # Attach to session
tn <name>   # Create new session
tls         # List sessions
tk <name>   # Kill session
t [name]    # Smart attach/create - attach if exists, create if not

tcopy       # Copy tmux buffer to clipboard
tlines [n]  # Copy last n lines from tmux pane to clipboard
```

## Common Workflows

### Starting Sessions

```bash
sf                              # Use fzf to select session
tmuxinator start admin          # Start admin monitoring
tmuxinator start config         # Edit dotfiles
tmuxinator start default ~/git/myproject  # New project session
```

### Creating New Templates

1. Create `~/.config/tmuxinator/name.yml`
2. Use existing templates as reference
3. Test with `tmuxinator start name`
4. Now available in `sf` automatically

## Auto-Start Behavior

On terminal startup (from `~/.zshrc:272-275`):
- Creates "home" session if it doesn't exist
- Runs in background (detached)
- Provides a default session to attach to

## Best Practices

1. **Fixed names for utilities**: Use `name: admin` for consistent session names
2. **Dynamic names for projects**: Use `<%= File.basename(...) %>` for project-based naming
3. **Exclude default from sf**: The default template is a fallback, not a session target
4. **Keep layouts simple**: 2-3 panes max for usability
5. **Use comments for empty panes**: `# interactive shell` for clarity

## Troubleshooting

- **Wrong session name**: Check `name:` field in YAML vs filename
- **Template not showing in sf**: Ensure `.yml` extension and not named "default"
- **Layout issues**: Try `tmux kill-session -t name` and restart
- **Pane sizes**: Use `on_project_start` with `tmux resize-pane` commands
