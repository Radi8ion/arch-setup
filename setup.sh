#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Unwanted BS.
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

validate_input() {
    local input=$1
    local pattern=$2
    if [[ ! $input =~ $pattern ]]; then
        print_message $RED "Invalid input. Please try again."
        exit 1
    fi
}
# install AUR helper (yay)
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

# install packages from packages file
install_packages() {
    print_message $BLUE "Installing packages..."
    
    local packages=($(grep -v '^#' @packages | grep -v '^$'))
    local install_packages=()
    local remove_packages=()
    local in_remove_section=false
    
    for pkg in "${packages[@]}"; do
        if [[ "$pkg" == "Remove" ]]; then
            in_remove_section=true
            continue
        fi
        
        if $in_remove_section; then
            remove_packages+=("$pkg")
        else
            install_packages+=("$pkg")
        fi
    done
    
    if [ ${#install_packages[@]} -gt 0 ]; then
        yay -S --needed --noconfirm "${install_packages[@]}"
    fi
    
    if [ ${#remove_packages[@]} -gt 0 ]; then
        sudo pacman -Rnsc --noconfirm "${remove_packages[@]}"
    fi
    
    print_message $GREEN "Package installation complete."
}

# GNOME desktop environment
setup_gnome() {
    print_message $BLUE "Setting up GNOME desktop environment..."
    install_packages
    sudo systemctl enable gdm
    gnome-extensions enable gsconnect@andyholmes.github.io
    print_message $GREEN "GNOME setup complete."
}

# firewall (ufw)
configure_firewall() {
    print_message $BLUE "Configuring firewall (ufw)..."
    sudo ufw enable
    sudo ufw allow IPP    # Printer port
    sudo ufw allow CIFS   # Samba ports
    sudo ufw allow SSH    # SSH port
    sudo ufw allow Bonjour # Network discovery
    print_message $GREEN "Firewall configured."
}

# Samba Shared Folder
configure_samba() {
    print_message $BLUE "Configuring Samba..."
    echo "[global]
    server string = Samba Server
    " | sudo tee /etc/samba/smb.conf > /dev/null

    sudo smbpasswd -a $(whoami)
    sudo systemctl enable smb nmb
    print_message $GREEN "Samba configured."
}

# Fingerprint sensor
configure_fingerprint_sensor() {
    print_message $BLUE "Configuring fingerprint sensor..."
    sudo pacman -S --needed --noconfirm fprintd libfprint
    sudo systemctl enable fprintd
    print_message $GREEN "Fingerprint sensor configured. Use 'fprintd-enroll' to register your fingerprint."
}

touchpadConfiguration(){
    touchpadConfig='Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
        Option "Tapping" "on"
        Option "NaturalScrolling" "true"
        Option "DisableWhileTyping" "on"
        EndSection'
}
# Libs
install_data_science_tools() {
    print_message $BLUE "Installing some necessary dev packages..."
    sudo pacman -S --needed --noconfirm python python-pip python-numpy python-scipy python-matplotlib python-pandas python-scikit-learn python-jupyterlab
    pip install --user tensorflow keras torch torchvision torchaudio
    print_message $GREEN "Data Science and ML tools installed."
}

# Android Studio and SDK
install_android_studio() {
    print_message $BLUE "Installing Android Studio and SDK..."
    yay -S --needed --noconfirm android-studio
    sudo pacman -S --needed --noconfirm jdk-openjdk
    print_message $GREEN "Android Studio and Java JDK installed."
}

# WhiteSur icon theme
install_whitesur_theme() {
    print_message $BLUE "Installing WhiteSur Icon Theme..."
    git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git --depth=1
    cd WhiteSur-icon-theme/
    sudo ./install.sh -a
    cd ..
    rm -rf WhiteSur-icon-theme/
    print_message $GREEN "WhiteSur Icon Theme installed successfully."
}

#  configure fish shell
configure_fish_shell() {
    print_message $BLUE "Configuring fish shell..."
    sudo chsh -s /usr/bin/fish $(whoami)
    sudo chsh -s /usr/bin/fish
    print_message $GREEN "Fish shell configured as default."
}

#  configure GTK4 renderer
configure_gtk4() {
    if [ "$(pactree -r gtk4)" ]; then
        print_message $BLUE "Configuring GTK4 renderer..."
        echo -e "GSK_RENDERER=ngl" | sudo tee -a /etc/environment > /dev/null
        print_message $GREEN "GTK4 renderer configured."
    fi
}

#  install VS Code and marketplace
install_vscode() {
    print_message $BLUE "Installing VS Code and marketplace..."
    sudo pacman -S --needed --noconfirm code
    yay -S --needed --noconfirm code-marketplace
    print_message $GREEN "VS Code and marketplace installed."
}

#  install and configure Cloudflare WARP
setup_cloudflare_warp() {
    print_message $BLUE "Setting up Cloudflare WARP..."
    bash -c "$(curl -Ss https://gist.githubusercontent.com/ayu2805/7ad8100b15699605fbf50291af8df16c/raw/warp-update)"
    warp-cli generate-completions fish | sudo tee /etc/fish/completions/warp-cli.fish > /dev/null
    print_message $GREEN "Cloudflare WARP configured."
}

#  setup gaming packages
setup_gaming() {
    print_message $BLUE "Setting up gaming packages..."
    bash -c "$(curl -Ss https://gist.githubusercontent.com/ayu2805/37d0d1740cd7cc8e1a37b2a1c2ecf7a6/raw/archlinux-gaming-setup)"
    print_message $GREEN "Gaming packages installed."
}

#  configure Qt file dialog
configure_qt_dialog() {
    print_message $BLUE "Configuring Qt file dialog..."
    echo "[FileDialog]
shortcuts=file:, file:///home/$(whoami), file:///home/$(whoami)/Desktop, file:///home/$(whoami)/Documents, file:///home/$(whoami)/Downloads, file:///home/$(whoami)/Music, file:///home/$(whoami)/Pictures, file:///home/$(whoami)/Videos
sidebarWidth=110
viewMode=Detail" | sudo tee ~/.config/QtProject.conf > /dev/null
    print_message $GREEN "Qt file dialog configured."
}

#  apply touchpad configuration
apply_touchpad_config() {
    print_message $BLUE "Configuring touchpad..."
    echo "$touchpadConfig" | sudo tee /etc/X11/xorg.conf.d/30-touchpad.conf > /dev/null
    print_message $GREEN "Touchpad configured."
}

# Main script 
print_message $YELLOW "Welcome to the Minimal Arch Linux Installation Script"

read -p "Enter your Full Name: " full_name
validate_input "$full_name" "^[a-zA-Z ]+$"

read -p "Enter hostname: " hostname
validate_input "$hostname" "^[a-zA-Z0-9-]+$"

read -p "Enter username: " username
validate_input "$username" "^[a-z_][a-z0-9_-]*$"

if [ -n "$full_name" ]; then
    sudo chfn -f "$full_name" "$(whoami)"
fi

grep -qF "Include = /etc/pacman.d/custom" /etc/pacman.conf || echo "Include = /etc/pacman.d/custom" | sudo tee -a /etc/pacman.conf > /dev/null
echo -e "[options]\nColor\nParallelDownloads = 5\nILoveCandy\n" | sudo tee /etc/pacman.d/custom > /dev/null

sudo pacman -Sy --needed --noconfirm reflector
sudo reflector --save /etc/pacman.d/mirrorlist -p https -c $(echo $LANG | awk -F [_,.] '{print $2}') -f 10
sudo pacman -Syu --needed --noconfirm pacman-contrib

sudo useradd -m -G wheel -s /bin/bash "$username"
echo "$username ALL=(ALL) ALL" | sudo tee -a /etc/sudoers
print_message $GREEN "User $username created."

if [ "$(pactree -r linux)" ]; then   
    sudo pacman -S --needed --noconfirm linux-headers
fi

if [ "$(pactree -r linux-zen)" ]; then   
    sudo pacman -S --needed --noconfirm linux-zen-headers
fi

sudo pacman -S --needed --noconfirm libva-intel intel-media-driver vulkan-intel
nvidia_common(){
    echo -e "options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_UsePageAttributeTable=1" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
    sudo systemctl enable nvidia-persistenced nvidia-hibernate nvidia-resume nvidia-suspend switcheroo-control
}
sudo pacman -S --needed --noconfirm nvidia-open-dkms
nvidia_common

sudo systemctl disable systemd-resolved.service
sudo systemctl enable avahi-daemon.socket cups.socket power-profiles-daemon sshd ufw
sudo systemctl start ufw

read -r -p "Do you want to create a Samba Shared folder? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo -e "[Samba Share]\ncomment = Samba Share\npath = /home/$(whoami)/Samba Share\nread only = no" | sudo tee -a /etc/samba/smb.conf > /dev/null
    rm -rf ~/Samba\ Share
    mkdir ~/Samba\ Share
    sudo systemctl restart smb nmb
fi

echo -e "VISUAL=nvim\nEDITOR=nvim" | sudo tee /etc/environment > /dev/null

grep -qF "set number" /etc/xdg/nvim/sysinit.vim || echo "set number" | sudo tee -a /etc/xdg/nvim/sysinit.vim > /dev/null
grep -qF "set wrap!" /etc/xdg/nvim/sysinit.vim || echo "set wrap!" | sudo tee -a /etc/xdg/nvim/sysinit.vim > /dev/null

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
install_data_science_tools
install_android_studio
setup_gnome
install_whitesur_theme
configure_fish_shell
configure_gtk4
install_vscode
setup_cloudflare_warp
setup_gaming
configure_qt_dialog
apply_touchpad_config
configure_firewall
configure_samba
configure_fingerprint_sensor
touchpadConfiguration
sudo mkdir -p /etc/pacman.d/hooks/
touchpadConfiguration

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

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters" | sudo tee /etc/hosts > /dev/null

sudo sed -i -e 's/^#\?MAKEFLAGS.*/MAKEFLAGS="-j$(nproc)"/' \
           -e 's/^PKGEXT.*/PKGEXT='\''\.pkg\.tar'\''/' /etc/makepkg.conf
sudo sed -i 's/^#MAKEFLAGS.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf
sudo sed -i 's/^MAKEFLAGS.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf

if [ "$(pactree -r chaotic-keyring && pactree -r chaotic-mirrorlist)" ]; then
    print_message $BLUE "Chaotic-AUR is already set up."
else
    print_message $BLUE "Setting up Chaotic-AUR..."
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --needed --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    sudo pacman -U --needed --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    echo -e "[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" | sudo tee -a /etc/pacman.d/custom > /dev/null
    sudo pacman -Syu --noconfirm
fi

install_packages() {
    local packages=("$@")
    sudo pacman -S --needed --noconfirm "${packages[@]}" &
    wait
}

cleanup() {
    rm -rf /tmp/setup_* 2>/dev/null
    cd "$original_dir"
}

setup_logging() {
    exec 3>&1 4>&2
    trap 'exec 2>&4 1>&3' 0 1 2 3
    exec 1>/tmp/setup_log.out 2>&1
}

read -r -p "Setup complete. Do you want to reboot now? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo reboot
fi
