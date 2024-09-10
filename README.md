# dotfiles

This repo contains the configuration to set up configuration and install programs. 
This is using [Chezmoi](https://chezmoi.io), the dotfile manager to setup the install, as well as Ansible. 

## How to run

```shell
export GITHUB_USERNAME=trentshaines
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply $GITHUB_USERNAME
```
