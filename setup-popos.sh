#!/usr/bin/env bash
set -e # Bricht das Skript ab, wenn ein kritischer Fehler auftritt

REL="$(lsb_release -d | cut -f2-)"
echo "We are running $REL."

install_basics() {
  echo "Installing basic dependencies and setting up repositories..."
  sudo apt-get update
  sudo apt-get install -y curl wget gpg apt-transport-https lsb-release jq unzip software-properties-common

  # Onedriver via PPA (Ubuntu equivalent to COPR)
  sudo add-apt-repository -y ppa:jstaf/onedriver

  # Setup Microsoft Keyring (Modern apt approach)
  sudo mkdir -p /etc/apt/keyrings
  curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
  sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

  # VS Code Repo
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

  # Edge Repo
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list > /dev/null

  # Azure CLI Repo
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/azure-cli.list > /dev/null

  # .NET Core (packages-microsoft-prod equivalent)
  wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  rm packages-microsoft-prod.deb

  sudo apt-get update

  # Install Packages (Adjusted for Debian/Ubuntu naming)
  sudo apt-get install -y seahorse audacity easyeffects gnome-shell-extension-prefs onedriver \
    gnome-tweaks keepassxc git chromium-browser firefox nodejs microsoft-edge-stable code \
    zsh snapd setzer crudini ydotool azure-cli

  # Add Azure DevOps extension
  az extension add --name azure-devops

  # Git Config
  git config --global user.name "Michael Mücke"
  git config --global user.email "michael.muecke@auronet.de"
  git config --global credential.helper store
}

clone_repos() {
  echo "Cloning repositories..."
  mkdir -p ~/git/PlainStaff
  git clone https://auronet@dev.azure.com/auronet/PlainStaff/_git/PlainStaff ~/git/PlainStaff/Web
  git clone https://auronet@dev.azure.com/auronet/PlainStaff%20Admin/_git/PlainStaff%20Admin ~/git/PlainStaff/Admin
  git clone https://auronet@dev.azure.com/auronet/PlainStaff%20API/_git/PlainStaff%20API ~/git/PlainStaff/Api
  git clone https://auronet@dev.azure.com/auronet/PlainStaff%20Mobile/_git/Expo ~/git/PlainStaff/Mobile
  git clone https://auronet@dev.azure.com/auronet/PlainStaff%20Shared/_git/PlainStaff%20Shared ~/git/PlainStaff/Shared
}

install_gnome_extensions() {
  echo "Installing Gnome Extensions..."
  array=(https://extensions.gnome.org/extension/545/hide-top-bar/
    https://extensions.gnome.org/extension/7065/tiling-shell/
    https://extensions.gnome.org/extension/6281/wallpaper-slideshow/
    https://extensions.gnome.org/extension/4709/another-window-session-manager/
    https://extensions.gnome.org/extension/5021/activate-window-by-title/)

  for i in "${array[@]}"; do
    EXTENSION_ID=$(curl -s $i | grep -oP 'data-uuid="\K[^"]+')
    VERSION_TAG=$(curl -Lfs "https://extensions.gnome.org/extension-query/?search=$EXTENSION_ID" | jq '.extensions[0] | .shell_version_map | map(.pk) | max')
    wget -qO ${EXTENSION_ID}.zip "https://extensions.gnome.org/download-extension/${EXTENSION_ID}.shell-extension.zip?version_tag=$VERSION_TAG"
    gnome-extensions install --force ${EXTENSION_ID}.zip
    if ! gnome-extensions list | grep --quiet ${EXTENSION_ID}; then
      busctl --user call org.gnome.Shell.Extensions /org/gnome/Shell/Extensions org.gnome.Shell.Extensions InstallRemoteExtension s ${EXTENSION_ID}
    fi
    gnome-extensions enable ${EXTENSION_ID}
    rm ${EXTENSION_ID}.zip
  done
}

install_npm_packages() {
  echo "Installing NVM and global NPM packages..."
  export NVM_DIR="$HOME/.nvm"
  wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  
  # Load NVM locally so we can use it immediately without rebooting
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  
  # Install latest LTS node
  nvm install --lts
  nvm use --lts
  
  # Install global packages using NVM (no sudo needed!)
  npm install -g expo-cli gulp-cli azure-functions-core-tools@4
}

install_zsh() {
  echo "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
}

install_android_emulator() {
  echo "Installing Android Emulator..."
  destination="$HOME/android/"
  toolsDownloadUrl=$(curl -s https://developer.android.com/studio | grep -o "https:\/\/dl.google.com\/android\/repository\/commandlinetools\-linux\-[0-9]*_latest\.zip" | head -n 1)

  curl --location -o android.zip $toolsDownloadUrl
  unzip -q android.zip -d ./android-temp

  mkdir -p "$destination/cmdline-tools/tools"
  mv -f ./android-temp/cmdline-tools/* "$destination/cmdline-tools/tools"
  rm -rf ./android-temp
  rm android.zip

  cd "$destination/cmdline-tools/tools/bin"
  yes | ./sdkmanager "platform-tools" "emulator"
  yes | ./sdkmanager "system-images;android-36;google_apis;x86_64" "platforms;android-36"
  echo "no" | ./avdmanager create avd --name phone --package "system-images;android-36;google_apis;x86_64" -d "pixel_9_pro" --force

  crudini --set ~/.android/avd/phone.avd/config.ini "fastboot.forceColdBoot" "yes"
  crudini --set ~/.android/avd/phone.avd/config.ini "hw.keyboard" "yes"
}

install_configs() {
  echo "Copying configurations..."
  # mkdir -p ~/git
  # git clone https://github.com/muecke36/fedora-settings.git ~/git/fedora-settings

  cp -R ~/git/fedora-settings/config/* ~/.config/
  cp -R ~/git/fedora-settings/local/* ~/.local/

  cp ~/git/fedora-settings/.zshrc ~/.zshrc

  mkdir -p ~/bin
  cp -R ~/git/fedora-settings/bin/* ~/bin/
  find ~/bin -type f -exec chmod +x {} \;
}

install_texlive_packages() {
  echo "Installing TeXlive and related tools..."
  sudo apt-get install -y texlive-base texlive-latex-extra texlive-fonts-recommended \
    texlive-science biber latexmk chktex lacheck pdfpc xdotool proselint
}

install_flatpaks() {
  echo "Installing flatpaks from Flathub..."
  # Pop!OS usually comes with flathub enabled, but running this is safe
  flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

  flatpak install --user -y flathub com.freerdp.FreeRDP
  flatpak install --user -y flathub com.github.tchx84.Flatseal

  # Snap is disabled by default on Linux Mint / Pop!OS but we installed snapd in basics.
  # Ensure the snapd socket is ready
  sudo systemctl enable --now snapd.socket
  
  sudo snap install ngrok
  sudo snap install postman
  sudo snap install onlyoffice-desktopeditors
  sudo snap install storage-explorer
}

setup_grub() {
  # NOTE: Pop!OS uses systemd-boot for UEFI. This will only work if you use Legacy BIOS.
  echo "Setting up GRUB (Warning: Pop!OS defaults to systemd-boot on UEFI systems)..."
  wget -P /tmp https://github.com/shvchk/fallout-grub-theme/raw/master/install.sh
  sudo bash /tmp/install.sh

  sudo crudini --set "/etc/default/grub" "GRUB_GFXMODE" "1024x768,800x600,640x480,auto"
  sudo crudini --set "/etc/default/grub" "GRUB_TIMEOUT" "20"
  sudo update-grub
}

usage() {
  echo "$0: Install packages and software for Pop!OS"
  echo
  echo "Usage:"
  echo "-b: install basics"
  echo "-c: install configs"
  echo "-g: install gnome extensions"
  echo "-n: install npm packages"
  echo "-e: install android emulator"
  echo "-z: install zsh"
  echo "-r: clone repos"
  echo "-s: setup grub (Legacy BIOS only)"
  echo "-t: install TeXlive packages"
  echo "-f: install flatpaks and snaps"
  echo "-a: do all of the above"
  echo "-h: print this usage text and exit"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

while getopts "cnegsbtrfzah" OPTION; do
  case $OPTION in
  c) install_configs ;;
  g) install_gnome_extensions ;;
  s) setup_grub ;;
  r) clone_repos ;;
  z) install_zsh ;;
  n) install_npm_packages ;;
  e) install_android_emulator ;;
  b) install_basics ;;
  t) install_texlive_packages ;;
  f) install_flatpaks ;;
  a)
    install_basics
    install_configs
    install_npm_packages
    install_android_emulator
    install_texlive_packages
    install_flatpaks
    install_gnome_extensions
    install_zsh
    ;;
  h) usage ;;
  ?) usage; exit 1 ;;
  esac
done
