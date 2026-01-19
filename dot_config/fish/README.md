# Fish Shell Configuration

This is a **parallel** configuration alongside your existing zsh setup. Your zsh config remains untouched.

## How to Test Fish

### 1. Just run `fish` from zsh

```bash
fish  # Enter fish shell
exit  # Return to zsh
```

### 2. What's Already Set Up

All your key functionality has been ported:

**✅ Working out of the box:**

- Starship prompt
- Zoxide (z/zi commands)
- FZF (Ctrl-R, Ctrl-T, Alt-C)
- All aliases (ll, la, cat→bat, etc.)
- Git aliases (gc, gp, gst, etc.)
- Tmux functions (t, ts, tns, tnw, tlines)
- IDE launchers (rf, cf)
- Vim integration (vf, ff)
- Vi mode keybindings

**✅ NVM Setup Complete:**

- **Fisher**: Plugin manager installed
- **Bass**: Bash command wrapper installed
- **nvm.fish**: Fish-native NVM installed
- **Node 20**: Installed and active

### 3. NVM Usage

NVM is already set up! Common commands:

```fish
nvm list              # List installed Node versions
nvm install 18        # Install Node 18
nvm use 20            # Switch to Node 20
nvm current           # Show current version
node --version        # Check Node version
```

**Installed via fisher:**

- `jorgebucaran/fisher` - Plugin manager
- `edc/bass` - Run bash commands in fish
- `jorgebucaran/nvm.fish` - Fish-native NVM

### 4. Testing Your Workflow

Try these commands in fish:

```fish
# Navigation
z ~/git          # Zoxide jump
Ctrl-R           # FZF history search
Ctrl-T           # FZF file finder

# Tmux
t                # Attach to tmux
ts               # Fuzzy tmux session selector
tns myproject    # Create new git project

# Git
gs               # Fuzzy branch switcher
glog             # Pretty git log

# Vim
vf               # Fuzzy find file → nvim
v somefile       # nvim alias

# IDE
rf               # Fuzzy find project → Rider
cf               # Fuzzy find project → Cursor
```

### 5. Comparing Shells

**Switch between them anytime:**

```bash
# In zsh:
fish

# In fish:
exit  # or Ctrl-D
```

**Your zsh remains default** - you're not changing anything yet!

### 6. Making Fish Your Default (Optional)

**Only do this if you like it:**

```bash
# Make fish default shell
chsh -s /opt/homebrew/bin/fish

# To revert back to zsh
chsh -s /bin/zsh
```

## Key Differences You'll Notice

### Better Autosuggestions

Fish shows command suggestions as you type (in gray). Press → to accept.

### Better Tab Completion

Tab completion is more intuitive and shows options visually.

### Different Syntax

If you write custom commands, the syntax is different:

- `if test` instead of `if [ ]`
- `set` instead of `export`
- No `source <(cmd)`, use `cmd | source`

## File Locations

- **Fish config**: `~/.config/fish/config.fish`
- **Functions**: `~/.config/fish/functions/*.fish`
- **Zsh config** (unchanged): `~/.zshrc`

## Notes

- Your zsh config is **completely untouched**
- You can run both shells side-by-side indefinitely
- All your CLI tools work in both shells
- Only the shell syntax/features differ

## Reverting

To go back to zsh permanently:

1. `chsh -s /bin/zsh`
2. Optionally delete `~/.config/fish/` if you want

## Next Steps

1. Run `fish` to try it
2. Test your common workflows
3. See if you like the autosuggestions/completion
4. Decide after a few days of testing
5. Keep both configs as long as you want!
