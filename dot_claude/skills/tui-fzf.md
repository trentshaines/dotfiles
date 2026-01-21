# TUI and fzf Skill

## Overview

This skill covers creating fast, responsive terminal UI components using fzf and tmux popups.

## Key Principle: Use display-popup with Bash

**Always use `display-popup` with `/bin/bash` for fast tmux popups.**

The issue: `fzf-tmux -p` uses tmux's `default-shell` (fish) for popups, which takes ~1.1s to start. Bash starts in ~5ms.

**Wrong (slow):**
```bash
bind-key "t" run-shell "SHELL=/bin/bash fzf-tmux -p ..."  # Still uses fish!
```

**Right (fast):**
```bash
bind-key "t" display-popup -E -w 80% -h 70% "/bin/bash -c 'your-fzf-command'"
```

## Fast Popup Pattern

```bash
# Use display-popup directly with /bin/bash -c
bind-key "x" display-popup -E -w 80% -h 70% "/bin/bash -c 'echo -e \"opt1\nopt2\" | fzf --prompt=\"Choose > \"'"
```

### With script file
```bash
bind-key "e" display-popup -E -w 70% -h 50% "/bin/bash /path/to/script.sh"
```

### Full example (sesh-like picker)
```bash
bind-key "t" display-popup -E -w 80% -h 70% "/bin/bash -c 'my-command \"\$(my-list | fzf \
    --no-sort --ansi \
    --border-label \" Title \" \
    --prompt \"⚡  \" \
    --preview \"preview-cmd {}\")\"'"
```

## fzf Patterns (inside bash popup)

### Basic picker
```bash
SELECTION=$(echo -e "option1\noption2" | fzf --prompt="Choose > ")
```

### With reload bindings
```bash
fzf --bind "ctrl-r:reload(list-command)" \
    --bind "ctrl-d:execute-silent(delete-cmd {1})+reload(list-command)"
```

### With preview pane
```bash
fzf --preview 'cat {}' --preview-window 'right:50%'
```

## Performance Tips

1. **Use `display-popup` with `/bin/bash`** - Not `fzf-tmux` (which uses default-shell)
2. **Inline awk/sed in fzf bindings** - Don't call external functions
3. **Use `--exit-0`** - Exit immediately if list is empty
4. **Avoid exported bash functions** - fzf subshells can't see them
5. **Preview is lazy** - Doesn't slow initial load

## Common fzf Flags

| Flag | Purpose |
|------|---------|
| `--ansi` | Enable color codes |
| `--no-sort` | Preserve input order |
| `--reverse` | List from top |
| `--with-nth=N..` | Display columns N onwards |
| `--delimiter='\t'` | Set field delimiter |
| `--header 'text'` | Show header line |
| `--border=rounded` | Rounded border (use this for nice popups) |
| `--border-label ' Title '` | Title for popup |
| `--preview 'cmd {}'` | Preview pane command |
| `--preview-window 'right:50%'` | Preview position/size |

## display-popup Flags

| Flag | Purpose |
|------|---------|
| `-E` | Close popup when command exits |
| `-w 80%` | Width (percent or columns) |
| `-h 70%` | Height (percent or rows) |
| `-x C` | Horizontal position (C=center) |
| `-y C` | Vertical position (C=center) |

## Debugging Shell Usage

Test what shell a popup uses:
```bash
# Default (will use fish if that's default-shell)
tmux display-popup -E 'echo $SHELL; ps -p $$ -o comm=; sleep 3'

# Forced bash
tmux display-popup -E '/bin/bash -c "echo \$SHELL; ps -p \$\$ -o comm=; sleep 3"'
```

## Example: Queue-based Picker Script

```bash
#!/bin/bash
# /path/to/picker.sh - run with: display-popup -E "/bin/bash /path/to/picker.sh"

QUEUE_FILE="/tmp/my-queue"

[[ ! -f "$QUEUE_FILE" ]] && echo "No items" && exit 0

# Inline the format command for reload
FORMAT_CMD="awk -F'\t' '{ print \$1, \$2 }' $QUEUE_FILE"

SELECTION=$(eval "$FORMAT_CMD" | fzf \
    --prompt="Pick > " \
    --header="ctrl-d: delete" \
    --bind "ctrl-d:execute-silent(sed -i '' '/{1}/d' $QUEUE_FILE)+reload($FORMAT_CMD)")

[[ -n "$SELECTION" ]] && echo "Selected: $SELECTION"
```
