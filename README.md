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

### Manual steps after setup

Some casks require interactive install (accessibility permissions, GUI prompts):

```shell
brew install --cask nikitabobko/tap/aerospace karabiner-elements espanso
```

After installing Obsidian: enable the CLI in Settings → General → Advanced → Command line interface.
