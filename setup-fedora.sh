#!/bin/bash
REL="$(rpm -E %fedora)"
echo "We are running Fedora $REL."

install_basics() {
    sudo dnf copr enable jstaf/onedriver
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo dnf config-manager addrepo --from-repofile=https://packages.microsoft.com/yumrepos/edge/config.repo
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" \
        | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

    dnf check-update
    
    # Basics
    sudo dnf install seahorse audacity easyeffects gnome-extensions-app onedriver \
    gnome-tweaks keepassxc git chromium firefox nodejs microsoft-edge-stable code edge  \
    --setopt=strict=0
}

install_npm_packages() {
    sudo npm install -g nvm expo-cli gulp-cli azure-functions-core-tools@4 --unsafe-perm true
}

install_configs() {
    mkdir ~/git
    git clone https://github.com/muecke36/fedora-settings.git ~/git/fedora-settings
    cp -R ~/git/fedora-settings/config/* ~/.config
}

install_texlive_packages() {
    # texlive bits
    # some bits for muttprint
    sudo dnf install texlive /usr/bin/pdflatex /usr/bin/latexmk /usr/bin/chktex \
        /usr/bin/lacheck /usr/bin/biber texlive-epstopdf texlive-biblatex-nature \
        /usr/bin/texexpand \
        'tex(array.sty)' 'tex(babel.sty)' 'tex(fancyhdr.sty)' 'tex(fancyvrb.sty)' \
        'tex(fontenc.sty)' 'tex(graphicx.sty)' 'tex(inputenc.sty)' \
        'tex(lastpage.sty)' 'tex(marvosym.sty)' 'tex(textcomp.sty)' \
        texlive-beamertheme-metropolis pdfpc xdotool /usr/bin/latexindent \
        fedtex proselint --setopt=strict=0
}


install_flatpaks() {
    # Flatpaks
    echo "Installing flatpaks from Flathub"
    flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    flatpak --user install flathub com.getpostman.Postman
}

install_nvidia() {
    echo "Installing Nvidia drivers"
    echo "Do remember to disable secure boot"
    sudo dnf install akmod-nvidia
    sudo dnf install xorg-x11-drv-nvidia-cuda
}

enable_services () {
    echo "Starting/enabling syncthing"
    systemctl --user start syncthing.service
    systemctl --user enable syncthing.service

    echo "Starting/enabling psi-notify"
    systemctl --user start psi-notify.service
    systemctl --user enable psi-notify.service

    # https://askubuntu.com/questions/340809/how-can-i-adjust-the-default-passphrase-caching-duration-for-gpg-pgp-ssh-keys/358514#358514
    echo "Configuring gnome-keyring to forget gpg passphrases after 7200 seconds"
    gsettings set org.gnome.crypto.cache gpg-cache-method "idle"
    gsettings set org.gnome.crypto.cache gpg-cache-ttl "7200"
}


usage() {
    echo "$0: Install packages and software"
    echo
    echo "Usage: $0 [-subtfanFh]"
    echo
    echo "-s: set up DNF repos"
    echo "-u: update groups: implies -s"
    echo "-b: install basics: implies -s"
    echo "-t: install TeXlive packages: implies -s"
    echo "-f: install flatpaks from flathub: also sets up flathub"
    echo "-a: do all of the above"
    echo "-n: install nvidia driver"
    echo "-F: install Flash plugin"
    echo "-h: print this usage text and exit"
}

if [ $# -lt 1 ]
then
    usage
    exit 1
fi

# parse options
while getopts "usbtfahnF" OPTION
do
    case $OPTION in
        s)
            setup_repos
            exit 0
            ;;
        u)
            setup_repos
            update_groups
            enable_services
            exit 0
            ;;
        b)
            setup_repos
            install_basics
            enable_services
            exit 0
            ;;
        t)
            setup_repos
            install_texlive_packages
            exit 0
            ;;
        f)
            install_flatpaks
            exit 0
            ;;
        n)
            setup_repos
            install_nvidia
            exit 0
            ;;
        a)
            setup_repos
            update_groups
            install_basics
            install_texlive_packages
            install_flatpaks
            enable_services
            exit 0
            ;;
        e)
            enable_services
            exit 0
            ;;
        h)
            usage
            exit 0
            ;;
        ?)
            usage
            exit 1
            ;;
    esac
done
