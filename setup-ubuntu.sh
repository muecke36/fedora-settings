#!/bin/bash

# Erkennung der Distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo "Distribution konnte nicht erkannt werden."
    exit 1
fi

echo "Running on $OS $VER."

install_basics() {
    if [ "$OS" = "fedora" ]; then
        sudo dnf copr enable jstaf/onedriver -y
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo dnf config-manager addrepo --from-repofile=https://packages.microsoft.com/yumrepos/edge/config.repo
        echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
        sudo dnf install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm
        sudo dnf install -y azure-cli seahorse audacity easyeffects gnome-extensions-app onedriver \
            gnome-tweaks keepassxc git chromium firefox nodejs microsoft-edge-stable code \
            zsh snapd setzer crudini ydotool --setopt=strict=0
    
    elif [ "$OS" = "ubuntu" ]; then
        sudo apt update && sudo apt install -y curl gpg software-properties-common apt-transport-https
        
        # Onedriver (PPA für Ubuntu)
        sudo add-apt-repository ppa:jstaf/onedriver -y
        
        # Microsoft Repo (VS Code & Edge)
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list
        rm -f packages.microsoft.gpg

        # Azure CLI
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

        sudo apt update
        sudo apt install -y seahorse audacity easyeffects gnome-shell-extension-prefs onedriver \
            gnome-tweaks keepassxc git chromium-browser firefox nodejs microsoft-edge-stable code \
            zsh snapd setzer crudini ydotool
    fi

    az extension add --name azure-devops
    git config --global user.name "Michael Mücke"
    git config --global user.email "michael.muecke@auronet.de"
    git config --global credential.helper store
}

clone_repos() {
    mkdir -p ~/git/PlainStaff
    # Nutze HTTPS-Auth oder SSH, falls hinterlegt
    git clone https://auronet@dev.azure.com/auronet/PlainStaff/_git/PlainStaff ~/git/PlainStaff/Web
    git clone https://auronet@dev.azure.com/auronet/PlainStaff%20Admin/_git/PlainStaff%20Admin ~/git/PlainStaff/Admin
    git clone https://auronet@dev.azure.com/auronet/PlainStaff%20API/_git/PlainStaff%20API ~/git/PlainStaff/Api
    git clone https://auronet@dev.azure.com/auronet/PlainStaff%20Mobile/_git/Expo ~/git/PlainStaff/Mobile
    git clone https://auronet@dev.azure.com/auronet/PlainStaff%20Shared/_git/PlainStaff%20Shared ~/git/PlainStaff/Shared
}

install_gnome_extensions() {
    # Benötigt jq und curl
    sudo apt install -y jq curl || sudo dnf install -y jq curl
    
    array=(https://extensions.gnome.org/extension/545/hide-top-bar/
        https://extensions.gnome.org/extension/7065/tiling-shell/
        https://extensions.gnome.org/extension/6281/wallpaper-slideshow/
        https://extensions.gnome.org/extension/4709/another-window-session-manager/
        https://extensions.gnome.org/extension/5021/activate-window-by-title/)

    for i in "${array[@]}"; do
        EXTENSION_ID=$(curl -s $i | grep -oP 'data-uuid="\K[^"]+')
        VERSION_TAG=$(curl -Lfs "https://extensions.gnome.org/extension-query/?search=$EXTENSION_ID" | jq '.extensions[0] | .shell_version_map | map(.pk) | max')
        wget -O ${EXTENSION_ID}.zip "https://extensions.gnome.org/download-extension/${EXTENSION_ID}.shell-extension.zip?version_tag=$VERSION_TAG"
        gnome-extensions install --force ${EXTENSION_ID}.zip
        
        # Bus-Call um die Shell zu refreshen (funktioniert nur in X11 zuverlässig, unter Wayland oft manuelle Aktivierung nötig)
        busctl --user call org.gnome.Shell.Extensions /org/gnome/Shell/Extensions org.gnome.Shell.Extensions InstallRemoteExtension s ${EXTENSION_ID} || true
        gnome-extensions enable ${EXTENSION_ID} || echo "Bitte Extension $EXTENSION_ID manuell aktivieren."
        rm ${EXTENSION_ID}.zip
    done
}

install_npm_packages() {
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts
    npm install -g expo-cli gulp-cli azure-functions-core-tools@4 --unsafe-perm true
}

install_zsh() {
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
}

install_android_emulator() {
    destination="$HOME/android/"
    # In Ubuntu heißt das Paket oft anders oder muss via Snap kommen, wir bleiben beim manuellen Download
    toolsDownloadUrl=$(curl -s https://developer.android.com/studio | grep -o "https:\/\/dl.google.com\/android\/repository\/commandlinetools\-linux\-[0-9]*_latest\.zip" | head -1)

    curl --location -o android.zip $toolsDownloadUrl
    unzip -q android.zip -d ./android-temp
    mkdir -p "$destination/cmdline-tools/latest"
    mv ./android-temp/cmdline-tools/* "$destination/cmdline-tools/latest"
    rm -rf ./android-temp android.zip

    # Pfade setzen für die aktuelle Session
    export ANDROID_HOME=$destination
    export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator

    yes | sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" "emulator" "platforms;android-36" "system-images;android-36;google_apis;x86_64"
    avdmanager create avd --name phone --package "system-images;android-36;google_apis;x86_64" -d "pixel_9_pro" --force

    crudini --set ~/.android/avd/phone.avd/config.ini "fastboot.forceColdBoot" "yes"
    crudini --set ~/.android/avd/phone.avd/config.ini "hw.keyboard" "yes"
}

install_texlive_packages() {
    if [ "$OS" = "fedora" ]; then
        sudo dnf install -y texlive-scheme-medium pdfpc xdotool fedtex proselint
    else
        sudo apt install -y texlive-latex-extra texlive-extra-utils texlive-fonts-recommended \
            texlive-bibtex-extra biber pdfpc xdotool latexindent
    fi
}

install_flatpaks() {
    flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak --user install -y flathub com.freerdp.FreeRDP com.github.tchx84.Flatseal
    sudo snap install ngrok postman onlyoffice-desktopeditors
    sudo snap install chromium # Falls apt nur ein Wrapper ist
}

setup_grub() {
    wget -P /tmp https://github.com/shvchk/fallout-grub-theme/raw/master/install.sh
    sudo bash /tmp/install.sh

    sudo crudini --set "/etc/default/grub" "GRUB_GFXMODE" "1024x768,800x600,640x480,auto"
    sudo crudini --set "/etc/default/grub" "GRUB_TIMEOUT" "20"
    
    if [ "$OS" = "fedora" ]; then
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    else
        sudo update-grub
    fi
}

# ... (Rest der Logik/getopts bleibt gleich)
