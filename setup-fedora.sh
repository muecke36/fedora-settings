#!/bin/bash

# Erkennung der Distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Distribution konnte nicht erkannt werden."
    exit 1
fi

# Prüfung auf WSL
IS_WSL=false
if grep -qi microsoft /proc/version; then
    IS_WSL=true
fi

echo "Running on $OS (WSL: $IS_WSL)."

install_wsl_cli() {
    echo "--- Installing WSL CLI Tools ---"
    if [ "$OS" = "fedora" ]; then
        sudo dnf install -y git zsh nodejs curl wget jq crudini
        # Azure CLI für Fedora
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo dnf install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm
        sudo dnf install -y azure-cli
    elif [ "$OS" = "ubuntu" ]; then
        sudo apt update && sudo apt install -y git zsh nodejs curl wget jq crudini
        # Azure CLI für Ubuntu
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    fi

    # Azure DevOps Extension
    az extension add --name azure-devops || true

    # Git Config
    git config --global user.name "Michael Mücke"
    git config --global user.email "michael.muecke@auronet.de"
    git config --global credential.helper store
    
    # NVM & Node Tools (CLI-spezifisch)
    install_npm_packages
    
    # ZSH Shell (Oh My Zsh)
    install_zsh
    
    echo "WSL Setup abgeschlossen. Bitte starte deine Shell neu (zsh)."
}

install_basics() {
    if $IS_WSL; then
        echo "Warnung: Du versuchst Desktop-Apps in WSL zu installieren. Nutze besser -w."
    fi
    # ... (Rest der install_basics Funktion wie zuvor)
    if [ "$OS" = "fedora" ]; then
        sudo dnf copr enable jstaf/onedriver -y
        # ... [Rest des Fedora-Teils]
    elif [ "$OS" = "ubuntu" ]; then
        # ... [Rest des Ubuntu-Teils]
    fi
}

# [Hier folgen die restlichen Funktionen: clone_repos, install_npm_packages, etc. aus dem vorherigen Skript]

install_npm_packages() {
    echo "--- Installing NVM and Global NPM Packages ---"
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts
    npm install -g gulp-cli azure-functions-core-tools@4 --unsafe-perm true
}

usage() {
    echo "$0: Install packages and software"
    echo
    echo "Usage:"
    echo "  -w: WSL Mode (Only CLI tools, Git, Node, Zsh)"
    echo "  -b: install basics (GUI & Desktop)"
    echo "  -a: do all (Standard Desktop Setup)"
    echo "  -h: print this usage text"
    # ... restliche Optionen
}

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

# parse options
while getopts "cnegsbtrfzahnw" OPTION; do
    case $OPTION in
    w)
        install_wsl_cli
        exit 0
        ;;
    a)
        if $IS_WSL; then
            install_wsl_cli
        else
            install_basics
            install_configs
            install_npm_packages
            install_android_emulator
            install_texlive_packages
            install_flatpaks
            install_gnome_extensions
            install_zsh
        fi
        exit 0
        ;;
    # ... [Restliche Cases wie zuvor]
    h)
        usage
        exit 0
        ;;
    *)
        usage
        exit 1
        ;;
    esac
done
