#!/bin/bash
REL="$(rpm -E %fedora)"
echo "We are running Fedora $REL."

install_basics() {
  sudo dnf copr enable jstaf/onedriver
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sudo dnf config-manager addrepo --from-repofile=https://packages.microsoft.com/yumrepos/edge/config.repo
  echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" |
    sudo tee /etc/yum.repos.d/vscode.repo >/dev/null

  dnf check-update

  # Basics
  sudo dnf install seahorse audacity easyeffects gnome-extensions-app onedriver \
    gnome-tweaks keepassxc git chromium firefox nodejs microsoft-edge-stable code \
    zsh snapd \
    --setopt=strict=0

  # Gnome extensions
  gnome-extensions install \
    https://extensions.gnome.org/extension/545/hide-top-bar/ \
    https://extensions.gnome.org/extension/7065/tiling-shell/ \
    https://extensions.gnome.org/extension/6281/wallpaper-slideshow/ \
    https://extensions.gnome.org/extension/5021/activate-window-by-title/

  # Oh My Zsh
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_npm_packages() {
  sudo npm install -g nvm expo-cli gulp-cli azure-functions-core-tools@4 --unsafe-perm true
}

install_android_emulator() {
  destination="$HOME/android/"
  toolsDownloadUrl=$(curl https://developer.android.com/studio | grep -o "https:\/\/dl.google.com\/android\/repository\/commandlinetools\-linux\-[0-9]*_latest\.zip")

  # Download and extract the contents
  curl --location -o android.zip $toolsDownloadUrl
  unzip -q android.zip -d ./android-temp

  mkdir -p "$destination/cmdline-tools/tools"
  mv ./android-temp/cmdline-tools/* "$destination/cmdline-tools/tools"
  rm -rf ./android-temp
  rm android.zip

  cd "$destination/cmdline-tools/tools"
  ./sdkmanager platform-tools emulator
  sdkmanager "system-images;android-36;google_apis;x86_64" "platforms;android-36"
  avdmanager create avd --name phone --package "system-images;android-36;google_apis;x86_64" -d "pixel_9_pro"

  crudini --set "~/.android/avd/phone.avd/config.ini" "fastboot.forceColdBoot" "yes"
  crudini --set "~/.android/avd/phone.avd/config.ini" "hw.keyboard" "yes"
}

install_configs() {
  mkdir ~/git
  git clone https://github.com/muecke36/fedora-settings.git ~/git/fedora-settings

  # copy configs
  cp -R ~/git/fedora-settings/config/* ~/.config
  cp -R ~/git/fedora-settings/local/* ~/.local

  # copy .zshrc
  cp ~/git/fedora-settings/.zshrc ~/.zshrc

  # copy bin files
  cp -R ~/git/fedora-settings/bin/* ~/bin

  # set all files in ~/bin to be executable
  find ~/bin -type f -exec chmod +x {} \;
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
  
  flatpak --user install com.freerdp.FreeRDP
  flatpak --user install com.github.tchx84.Flatseal

  sudo snap install ngrok postman
}

usage() {
  echo "$0: Install packages and software"
  echo
  echo "Usage: $0 [-subtfanFh]"
  echo
  echo "-b: install basics"
  echo "-c: install configs"
  echo "-n: install npm packages"
  echo "-e: install android emulator"
  echo "-t: install TeXlive packages"
  echo "-f: install flatpaks from flathub: also sets up flathub"
  echo "-a: do all of the above"
  echo "-h: print this usage text and exit"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

# parse options
while getopts "cnebtfahnF" OPTION; do
  case $OPTION in
  c)
    install_configs
    exit 0
    ;;
  n)
    install_npm_packages
    exit 0
    ;;
  e)
    install_android_emulator
    exit 0
    ;;
  b)
    install_basics
    exit 0
    ;;
  t)
    install_texlive_packages
    exit 0
    ;;
  f)
    install_flatpaks
    exit 0
    ;;
  a)
    install_basics
    install_configs
    install_npm_packages
    install_android_emulator
    install_texlive_packages
    install_flatpaks
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
