#!/bin/bash

# Ensure Ansible is installed
if ! command -v ansible &> /dev/null
then
    echo "Ansible not found. Installing via Homebrew..."
    if ! command -v brew &> /dev/null
    then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    brew install ansible
fi

# Run the Ansible playbook (with -K to prompt for sudo password)
ansible-playbook -K ~/.local/share/chezmoi/ansible/playbooks/packages.yml

echo "Ansible installation complete."

