#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    echo -e "${1}${2}${NC}"
}

validate_input() {
    [[ $1 =~ $2 ]] || { print_message $RED "Invalid input. Please try again."; exit 1; }
}

install_yay() {
    print_message $BLUE "Installing yay (AUR helper)..."
    sudo pacman -S --needed --noconfirm git base-devel
    cd /opt
    sudo git clone https://aur.archlinux.org/yay.git
    sudo chown -R "$username:$username" yay
    cd yay
    sudo -u "$username" makepkg -si --noconfirm
    yay -S --answerclean A --answerdiff N --removemake --cleanafter --save
    yay -Yc --noconfirm
    print_message $GREEN "yay installed successfully."
}

install_packages() {
    print_message $BLUE "Installing packages..."
    local packages=($(grep -v '^#' packages | grep -v '^$'))
    local remove_packages=($(grep -v '^#' remove | grep -v '^$'))
    yay -S --needed --noconfirm "${packages[@]}"
    sudo pacman -Rnsc --noconfirm "${remove[@]}"
    print_message $GREEN "Package installation complete."
}

setup_gnome() {
    print_message $BLUE "Setting up GNOME desktop environment..."
    sudo systemctl enable gdm
    gnome-extensions enable gsconnect@andyholmes.github.io
    print_message $GREEN "GNOME setup complete."
}

configure_firewall() {
    print_message $BLUE "Configuring firewall (ufw)..."
    sudo ufw enable
    sudo ufw allow IPP
    sudo ufw allow CIFS
    sudo ufw allow SSH
    sudo ufw allow Bonjour
    print_message $GREEN "Firewall configured."
}

configure_samba() {
    print_message $BLUE "Configuring Samba..."
    echo "[global]
    server string = Samba Server" | sudo tee /etc/samba/smb.conf > /dev/null
    sudo smbpasswd -a $(whoami)
    sudo systemctl enable smb nmb
    print_message $GREEN "Samba configured."
}

configure_fingerprint_sensor() {
    print_message $BLUE "Configuring fingerprint sensor..."
    sudo pacman -S --needed --noconfirm fprintd libfprint
    sudo systemctl enable fprintd
    print_message $GREEN "Fingerprint sensor configured. Use 'fprintd-enroll' to register your fingerprint."
}

configure_touchpad() {
    print_message $BLUE "Configuring touchpad..."
    echo 'Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
        Option "Tapping" "on"
        Option "NaturalScrolling" "true"
        Option "DisableWhileTyping" "on"
    EndSection' | sudo tee /etc/X11/xorg.conf.d/30-touchpad.conf > /dev/null
    print_message $GREEN "Touchpad configured."
}

configure_fish_shell() {
    print_message $BLUE "Configuring fish shell..."
    sudo chsh -s /usr/bin/fish $(whoami)
    sudo chsh -s /usr/bin/fish
    print_message $GREEN "Fish shell configured as default."
}

configure_gtk4() {
    if pactree -r gtk4 &>/dev/null; then
        print_message $BLUE "Configuring GTK4 renderer..."
        echo "GSK_RENDERER=ngl" | sudo tee -a /etc/environment > /dev/null
        print_message $GREEN "GTK4 renderer configured."
    fi
}

configure_qt_dialog() {
    print_message $BLUE "Configuring Qt file dialog..."
    echo "[FileDialog]
shortcuts=file:, file:///home/$(whoami), file:///home/$(whoami)/Desktop, file:///home/$(whoami)/Documents, file:///home/$(whoami)/Downloads, file:///home/$(whoami)/Music, file:///home/$(whoami)/Pictures, file:///home/$(whoami)/Videos
sidebarWidth=110
viewMode=Detail" | sudo tee ~/.config/QtProject.conf > /dev/null
    print_message $GREEN "Qt file dialog configured."
}

setup_cloudflare_warp() {
    print_message $BLUE "Setting up Cloudflare WARP..."
    if ! command -v warp-cli &>/dev/null; then
        print_message $BLUE "Installing Cloudflare WARP..."
        yay -S --needed --noconfirm cloudflare-warp-bin
    else
        print_message $YELLOW "Cloudflare WARP is already installed."
    fi
    if ! systemctl is-active --quiet warp-svc; then
        print_message $BLUE "Starting Cloudflare WARP service..."
        sudo systemctl enable --now warp-svc
    else
        print_message $YELLOW "Cloudflare WARP service is already running."
    fi

    if ! warp-cli account | grep -q "Registered"; then
        print_message $BLUE "Registering device with Cloudflare WARP..."
        warp-cli register
    else
        print_message $YELLOW "Device is already registered with Cloudflare WARP."
    fi
    read -r -p "Do you want to connect to Cloudflare WARP now? [y/N] " connect_response
    if [[ "$connect_response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        if ! warp-cli status | grep -q "Connected"; then
            print_message $BLUE "Connecting to Cloudflare WARP..."
            warp-cli connect
        else
            print_message $YELLOW "Already connected to Cloudflare WARP."
        fi
    else
        print_message $YELLOW "Skipping Cloudflare WARP connection."
    fi
    if command -v fish &>/dev/null; then
        print_message $BLUE "Generating Fish shell completions for warp-cli..."
        warp-cli generate-completions fish | sudo tee /etc/fish/completions/warp-cli.fish > /dev/null
    fi
    print_message $GREEN "Cloudflare WARP configured."
}

setup_gaming() {
    print_message $BLUE "Setting up gaming packages..."
    curl -#LO https://launcher.mojang.com/download/Minecraft.deb
    ar x Minecraft.deb
    tar -xf data.tar.xz
    sudo cp data/usr/bin/minecraft-launcher /usr/bin/
    sudo cp data/usr/share/icons/hicolor/symbolic/apps/minecraft-launcher.svg /usr/share/icons/hicolor/symbolic/apps/
    sudo cp data/usr/share/applications/minecraft-launcher.desktop /usr/share/applications/
    rm -rf control.tar.xz data.tar.xz Minecraft.deb usr/ debian-binary
    
    flatpak install -y flathub com.valvesoftware.Steam 
    print_message $GREEN "Gaming packages installed."
}

install_blackarch_tools() {
    print_message $BLUE "Do you want to install BlackArch tools? This will not install the full BlackArch repository, only the tools."
    read -r -p "Install BlackArch tools? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_message $BLUE "Installing BlackArch tools..."
        local tools_url="https://github.com/Radi8ion/arch-setup/blob/main/blackarch"
        local tools_file="/tmp/blackarch"
        curl -sSL "$tools_url" -o "$tools_file"
        if [[ ! -f "$tools_file" ]]; then
            print_message $RED "Failed to download the tools list. Please check the URL and try again."
            return 1
        fi
        local blackarch_tools=($(grep -v '^#' "$tools_file" | grep -v '^$'))
        for tool in "${blackarch_tools[@]}"; do
            if yay -Qi "$tool" &>/dev/null; then
                print_message $YELLOW "$tool is already installed. Skipping..."
            else
                print_message $BLUE "Installing $tool..."
                yay -S --needed --noconfirm "$tool"
            fi
        done
        rm -f "$tools_file"
        print_message $GREEN "BlackArch tools installation complete."
    else
        print_message $YELLOW "Skipping BlackArch tools installation."
    fi
}

print_message $YELLOW "Welcome to the Minimal Arch Linux Installation Script"

read -p "Enter your Full Name: " full_name
validate_input "$full_name" "^[a-zA-Z ]+$"

read -p "Enter hostname: " hostname
validate_input "$hostname" "^[a-zA-Z0-9-]+$"

read -p "Enter username: " username
validate_input "$username" "^[a-z_][a-z0-9_-]*$"

sudo chfn -f "$full_name" "$(whoami)"
grep -qF "Include = /etc/pacman.d/custom" /etc/pacman.conf || echo "Include = /etc/pacman.d/custom" | sudo tee -a /etc/pacman.conf > /dev/null
echo -e "[options]\nColor\nParallelDownloads = 5\nILoveCandy\n" | sudo tee /etc/pacman.d/custom > /dev/null

sudo pacman -Sy --needed --noconfirm reflector
sudo reflector --save /etc/pacman.d/mirrorlist -p https -c $(echo $LANG | awk -F [_,.] '{print $2}') -f 10
sudo pacman -Syu --needed --noconfirm pacman-contrib

sudo useradd -m -G wheel -s /bin/bash "$username"
echo "$username ALL=(ALL) ALL" | sudo tee -a /etc/sudoers
print_message $GREEN "User $username created."

sudo pacman -S --needed --noconfirm linux-headers linux-zen-headers libva-intel intel-media-driver vulkan-intel nvidia-open-dkms
echo -e "options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_UsePageAttributeTable=1" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
sudo systemctl enable nvidia-persistenced nvidia-hibernate nvidia-resume nvidia-suspend switcheroo-control

sudo systemctl disable systemd-resolved.service
sudo systemctl enable avahi-daemon.socket cups.socket power-profiles-daemon sshd ufw
sudo systemctl start ufw

echo -e "VISUAL=nvim\nEDITOR=nvim" | sudo tee /etc/environment > /dev/null
echo "set number" | sudo tee -a /etc/xdg/nvim/sysinit.vim > /dev/null
echo "set wrap!" | sudo tee -a /etc/xdg/nvim/sysinit.vim > /dev/null

read -r -p "Do you want to configure git? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    read -p "Enter your Git name: " git_name
    read -p "Enter your Git email: " git_email
    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    git config --global init.defaultBranch main
    ssh-keygen
    git config --global gpg.format ssh
    git config --global user.signingkey /home/$(whoami)/.ssh/id_ed25519.pub
    git config --global commit.gpgsign true
fi

install_yay
install_packages
setup_gnome
configure_firewall
configure_samba
configure_fingerprint_sensor
configure_touchpad
configure_fish_shell
configure_gtk4
configure_qt_dialog
setup_cloudflare_warp
setup_gaming
install_blackarch_tools

echo "[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = gutenprint

[Action]
Depends = gutenprint
When = PostTransaction
Exec = /usr/bin/cups-genppdupdate" | sudo tee /etc/pacman.d/hooks/gutenprint.hook > /dev/null

sudo cp /usr/share/doc/avahi/ssh.service /etc/avahi/services/

echo "127.0.0.1\tlocalhost
127.0.1.1\t$(hostname)

::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters" | sudo tee /etc/hosts > /dev/null

sudo sed -i 's/^#\?MAKEFLAGS.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf

if ! pactree -r chaotic-keyring &>/dev/null || ! pactree -r chaotic-mirrorlist &>/dev/null; then
    print_message $BLUE "Setting up Chaotic-AUR..."
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --needed --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    echo -e "[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" | sudo tee -a /etc/pacman.d/custom > /dev/null
    sudo pacman -Syu --noconfirm
fi

read -r -p "Setup complete. Do you want to reboot now? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo reboot
fi
