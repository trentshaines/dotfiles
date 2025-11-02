---
name: chezmoi
description: Help with chezmoi dotfile management, syncing configs, and pushing changes to the dotfiles repository. Use when modifying configuration files in ~/.config, ~/, or other managed locations. ALWAYS prompt the user about syncing to chezmoi after making config changes.
---

# Chezmoi Dotfile Management Skill

## Overview

Chezmoi manages dotfiles and system configuration, syncing them to a Git repository for version control and portability across machines.

## Key Locations

- **Chezmoi source**: `/Users/trent/.local/share/chezmoi/`
- **Git repository**: `https://github.com/trentshaines/dotfiles.git`
- **Home directory**: `~/` (managed files)
- **Config directory**: `~/.config/` (managed files)

## Managed Files

Important files tracked by chezmoi (in source directory):

### Dotfiles
- `dot_zshrc` → `~/.zshrc`
- `dot_tmux.conf` → `~/.tmux.conf`
- `dot_gitconfig` → `~/.gitconfig`
- `dot_gitignore_global` → `~/.gitignore_global`
- `dot_fzf.zsh` → `~/.fzf.zsh`
- `dot_ideavimrc` → `~/.ideavimrc`
- `dot_aerospace.toml` → `~/.aerospace.toml`

### Directories
- `dot_config/` → `~/.config/` (includes tmuxinator, gh, etc.)
- `dot_claude/` → `~/.claude/` (skills, settings, etc.)
- `dot_cursor/` → `~/.cursor/`
- `dot_local/` → `~/.local/`
- `private_Documents/` → `~/Documents/` (private, encrypted)
- `private_Library/` → `~/Library/` (private, encrypted)

## Common Commands

### User's Aliases (from ~/.zshrc)

```bash
cadd      # chezmoi re-add (sync changes back to source)
capply    # chezmoi apply (apply changes from source to home)
```

### Essential Chezmoi Commands

```bash
# Sync changes FROM home TO chezmoi source
chezmoi re-add                    # Re-add all managed files
chezmoi re-add ~/.zshrc           # Re-add specific file
chezmoi re-add ~/.config/tmuxinator/admin.yml  # Re-add specific config

# Apply changes FROM chezmoi source TO home
chezmoi apply                     # Apply all changes
chezmoi apply ~/.zshrc            # Apply specific file

# View changes
chezmoi diff                      # See what would change
chezmoi status                    # See modified files

# Git operations (in chezmoi source)
chezmoi cd                        # cd to source directory
chezmoi git -- status             # Git status
chezmoi git -- add .              # Git add
chezmoi git -- commit -m "msg"    # Git commit
chezmoi git -- push               # Git push
exit                              # Exit chezmoi source directory

# Or use this workflow:
cd ~/.local/share/chezmoi         # Go to source
git status                        # Check changes
git add .                         # Stage changes
git commit -m "Update configs"    # Commit
git push                          # Push to GitHub
cd -                              # Return to previous directory
```

## Typical Workflow After Config Changes

When Claude (or the user) modifies a config file like `~/.zshrc`, `~/.config/tmuxinator/admin.yml`, or any other managed file:

### Step 1: Re-add the changed file
```bash
chezmoi re-add ~/.zshrc
# or for files in .config:
chezmoi re-add ~/.config/tmuxinator/admin.yml
```

### Step 2: Commit and push to Git
```bash
cd ~/.local/share/chezmoi
git add .
git status  # Review changes
git commit -m "Description of changes"
git push
cd -
```

## Claude's Responsibility

**IMPORTANT**: After making ANY configuration changes to managed files, Claude should:

1. ✅ **Inform the user** that changes were made to a managed file
2. ✅ **Prompt the user** if they want to sync to chezmoi:
   ```
   I've updated ~/.zshrc. Would you like me to sync this to your dotfiles repo?
   This involves:
   1. chezmoi re-add ~/.zshrc
   2. Commit and push to github.com/trentshaines/dotfiles
   ```
3. ⚠️ **Wait for user confirmation** before running chezmoi commands
4. ✅ If user confirms, execute the re-add and git workflow

### Example Prompt Template

After modifying a config file:
```
Updated: ~/.config/tmuxinator/admin.yml

Would you like to sync this change to your dotfiles repo?
- Run: chezmoi re-add ~/.config/tmuxinator/admin.yml
- Commit and push to github.com/trentshaines/dotfiles.git
```

## Chezmoi File Naming Convention

Chezmoi uses special prefixes in the source directory:

- `dot_` → `.` (hidden files)
  - Example: `dot_zshrc` → `~/.zshrc`
  - Example: `dot_config/` → `~/.config/`

- `private_` → Private files (can be encrypted)
  - Example: `private_Documents/` → `~/Documents/`

- Combined: `private_dot_` → Private hidden files
  - Example: `private_dot_ssh/` → `~/.ssh/`

## Checking What's Managed

```bash
chezmoi managed                   # List all managed files
chezmoi managed | grep tmux       # Find tmux-related managed files
```

## Common Scenarios

### 1. Modified a dotfile (e.g., .zshrc)
```bash
chezmoi re-add ~/.zshrc
cd ~/.local/share/chezmoi
git add dot_zshrc
git commit -m "Update zshrc: describe changes"
git push
```

### 2. Added new tmuxinator template
```bash
chezmoi re-add ~/.config/tmuxinator/
cd ~/.local/share/chezmoi
git add dot_config/tmuxinator/
git commit -m "Add new tmuxinator template"
git push
```

### 3. Modified multiple config files
```bash
chezmoi re-add  # Re-add all changed files
cd ~/.local/share/chezmoi
git add .
git status  # Review all changes
git commit -m "Update multiple configs"
git push
```

### 4. Want to see what changed
```bash
chezmoi diff
```

## Files NOT Managed by Chezmoi

Some config files are NOT tracked (check `.chezmoiignore`):
- Temporary files
- Cache directories
- Machine-specific configs (if marked)
- Secrets (should use encrypted templates)

## Best Practices

1. **Always re-add after editing**: Run `chezmoi re-add <file>` after modifying managed files
2. **Commit frequently**: Keep dotfiles repo up to date with descriptive commits
3. **Review diffs**: Use `chezmoi diff` before applying to see what will change
4. **Test changes**: Modify in home directory first, test, then re-add to chezmoi
5. **Use meaningful commit messages**: Describe what changed and why

## Troubleshooting

### File not syncing?
- Check if it's managed: `chezmoi managed | grep filename`
- Check `.chezmoiignore` for exclusions
- Ensure you used `chezmoi re-add` after editing

### Conflicts between source and home?
```bash
chezmoi diff        # See differences
chezmoi apply -v    # Apply with verbose output
chezmoi re-add      # Or re-add to update source
```

### Lost changes?
- Source of truth is in `~/.local/share/chezmoi/`
- Git history: `chezmoi cd && git log`
- Can recover from Git history if needed

## Integration with Other Tools

- **tmuxinator**: Templates in `~/.config/tmuxinator/` are managed
- **Claude skills**: Skills in `~/.claude/skills/` are managed via `dot_claude/`
- **zsh**: `.zshrc` is managed as `dot_zshrc`
- **git**: `.gitconfig` is managed as `dot_gitconfig`

## Security Note

- Private files use `private_` prefix
- Sensitive data should be encrypted (chezmoi supports encryption)
- Never commit secrets in plain text
- Use chezmoi templates for machine-specific values
