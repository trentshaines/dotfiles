# dotfiles

This repo contains the configuration to set up configuration and install programs.
Uses [chezmoi](https://chezmoi.io) for dotfile management and Ansible for package installation.

todo: vimium — automate backup/restore of settings (keybindings + custom CSS) via chezmoi

## Fresh machine setup

No git, brew, or chezmoi required — just run this one command:

```shell
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply trentshaines
```

This will:
1. Download chezmoi
2. Clone this repo to `~/.local/share/chezmoi/`
3. Apply dotfiles
4. Run the Ansible playbook to install brew, packages, and casks

You will be prompted for your password **twice**: once upfront to pre-warm sudo (so
brew cask installers like Docker and Tailscale can run without a TTY), and once by
Ansible itself for tasks that require privilege escalation (adding fish to `/etc/shells`,
setting default shell).

### Automated macOS settings

`run_onchange_macos-defaults.sh` runs after Ansible and sets: Dock (left, autohide,
size 16, Quick Note hot corner), Finder (list view, sidebar, desktop icons), natural
scrolling off, two-finger page swipe off, tiling margins off, Cmd-Space → Raycast with
Spotlight moved to Option-Space, and login items (Raycast, AeroSpace, Granola, Notion).
`run_onchange_install-pmset-sudoers.sh.tmpl` lets `sudo pmset` run without a password
(used by the Raycast "Toggle Disable Sleep" script).

### Manual steps after setup

macOS does not allow these to be scripted. An agent setting up a new machine should
walk the user through each one, then run the check under it.

#### Permissions (System Settings → Privacy & Security)

| App | Grant | Check |
| --- | --- | --- |
| [Karabiner-Elements](https://karabiner-elements.pqrs.org/) | Open it; approve **System Extension** and **Input Monitoring** | Remapped keys work; config is `~/.config/karabiner/` |
| [AeroSpace](https://nikitabobko.github.io/AeroSpace/guide) | **Accessibility** | `aerospace list-workspaces --all` |
| [Espanso](https://espanso.org/) | **Accessibility**, then `espanso service start` | `espanso status` |
| Raycast | **Accessibility** | Cmd-Space opens Raycast |

The first run of `run_onchange_macos-defaults.sh` asks to let the terminal control
**System Events** (needed for login items). If it was denied, allow it in Privacy &
Security → Automation and rerun:
`chezmoi state delete-bucket --bucket=scriptState && chezmoi apply`.

#### Raycast

1. Sign in to sync extensions and settings (Settings → Account).
2. Settings → Extensions → Script Commands → **Add Directories** → `~/.config/raycast-scripts`.
3. Assign the per-script hotkeys by hand (Raycast stores these encrypted, so chezmoi cannot):
   - Toggle Disable Sleep → _record hotkey here_
4. If Cmd-Space still opens Spotlight, set Raycast's hotkey to Cmd-Space in Settings → General.

#### Default browser

System Settings → Desktop & Dock → Default web browser → **Arc**. macOS always asks the
user to confirm this, so it cannot be scripted silently.

#### Obsidian

Enable the CLI in Settings → General → Advanced → Command line interface.

#### Sign-ins

`gh auth login`, `claude` (log in), Codex, Tailscale, Arc, Notion, Granola, Google Drive.
Credentials are never stored in this repo.
