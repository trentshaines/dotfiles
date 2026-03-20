# dotfiles

This repo contains the configuration to set up configuration and install programs. 
This is using [Chezmoi](https://chezmoi.io), the dotfile manager to setup the install, as well as Ansible. 

todo: set up ansible script for macos
todo: vimium — automate backup/restore of settings (keybindings + custom CSS) via chezmoi

## How to run

```shell
export GITHUB_USERNAME=trentshaines
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply $GITHUB_USERNAME
```
