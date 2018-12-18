#!/bin/bash

[ -z ${dotfilesrepo+x} ] && dotfilesrepo="https://github.com/thehnm/dotfiles-i3.git"
[ -z ${vundlerepo+x} ] && vundlerepo="https://github.com/VundleVim/Vundle.vim.git"

###############################################################################

initialcheck() { pacman -S --noconfirm --needed dialog || { echo "Are you sure you're running this as the root user? Are you sure you're using an Arch-based distro? ;-) Are you sure you have an internet connection?"; exit; } ;}

welcomemsg() { \
  dialog --title "Welcome!" --msgbox "Welcome to thehnm's Arch Linux Installation Script!\\n\\nThis script will automatically install a fully-featured i3wm Arch Linux desktop, which I use as my main machine.\\n\\n-thehnm" 10 60
}

preinstallmsg() { \
    dialog --title "Start installing the script!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "It will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || { clear; exit; }
}

getuserandpass() {
    # Prompts user for new username an password.
    # Checks if username is valid and confirms passwd.
    name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit
    namere="^[a-z_][a-z0-9_-]*$"
    while ! [[ "${name}" =~ ${namere} ]]; do
            name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
    done
    pass1=$(dialog --no-cancel --insecure --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
    pass2=$(dialog --no-cancel --insecure --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    while ! [[ ${pass1} == ${pass2} ]]; do
            unset pass2
            pass1=$(dialog --no-cancel --insecure --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
            pass2=$(dialog --no-cancel --insecure --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    done ;
}

usercheck() { \
    ! (id -u $name &>/dev/null) ||
    dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "The user \`$name\` already exists on this system. This script can install for a user already existing, but it will \\Zboverwrite\\Zn any conflicting settings/dotfiles on the user account.\\n\\nThis script will \\Zbnot\\Zn overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that this script will change $name's password to the one you just gave." 14 70
}

adduserandpass() { \
    # Adds user `$name` with password $pass1.
    dialog --infobox "Adding user \"$name\"..." 4 50
    useradd -m -g wheel -s /bin/bash "$name" &>/dev/null ||
    usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
    echo "$name:$pass1" | chpasswd
    unset pass1 pass2 ;
}

refreshkeys() { \
    dialog --infobox "Refreshing Arch Keyring..." 4 40
    pacman --noconfirm -Sy archlinux-keyring &>/dev/null
}

installyay() {
    dialog --infobox "Installing yay, an AUR helper..." 8 50
    pacman --noconfirm -S git &>/dev/null
    sudo -u $name git clone https://aur.archlinux.org/yay.git /tmp/yay &>/dev/null
    cd /tmp/yay
    sudo -u $name makepkg --noconfirm -si &>/dev/null
}

pacmaninstall() {
    dialog --title "Installation" --infobox "Installing \`$1\` ($n of $total)." 5 70
    pacman --noconfirm --needed -S "$1" &>/dev/null
}

singleinstall() {
    dialog --title "Installation" --infobox "Installing \`$1\`." 5 70
    pacman --noconfirm --needed -S "$1" &>/dev/null
}

aurinstall() {
    dialog --title "Installation" --infobox "Installing \`$1\` ($n of $total) from the AUR." 5 70
    sudo -u $name yay --noconfirm -S "$1" &>/dev/null
}

singleaurinstall() {
    dialog --title "Installation" --infobox "Installing \`$1\` from the AUR." 5 70
    sudo -u $name yay --noconfirm -S "$1" &>/dev/null
}

editpackages() {
    dialog --yesno "Do you want to edit the packages file?" 10 80 3>&2 2>&1 1>&3
    case $? in
        0 ) vim $1
            break;;
        1 ) break;;
    esac
}

install() {
    curl https://raw.githubusercontent.com/thehnm/tarbs/master/packages.csv >> /tmp/packages.csv
    editpackages "/tmp/packages.csv"
    total=$(wc -l < /tmp/packages.csv)
    aurinstalled=$(pacman -Qm | awk '{print $1}')
    while IFS=, read -r tag program; do
    n=$((n+1))
    case "$tag" in
        "") pacmaninstall "$program" ;;
        "A") aurinstall "$program" ;;
    esac
    done < /tmp/packages.csv ;
}

putgitrepo() { # Downlods a gitrepo $1 and places the files in $2 only overwriting conflicts
    dialog --infobox "Downloading and installing config files..." 4 60
    dir=$(mktemp -d)
    chown -R "$name":wheel "$dir"
    sudo -u "$name" git clone "$1" "$dir"/"$3" &>/dev/null &&
    sudo -u "$name" mkdir -p "$2" &&
    sudo -u "$name" cp -rT "$dir"/"$3" "$2"/"$3"
}

installdotfiles() {
    dialog --infobox "Installing my dotfiles..." 4 60
    cd "$1"
    sudo -u "$name" bash "$2"
}

serviceinit() {
    for service in "$@"; do
        dialog --infobox "Enabling \"$service\"..." 4 40
        systemctl enable "$service"
        systemctl start "$service"
    done
}

setxinitrc() {
    dialog --infobox "Setting xinitrc..." 4 40
    echo exec i3 >> $HOME/.xinitrc
}

newperms() { # Set special sudoers settings for install (or after).
    dialog --infobox "Getting rid of that retarded error beep sound..." 10 50
    sed -i "/#SCRIPT/d" /etc/sudoers
    echo -e "$@ #SCRIPT" >> /etc/sudoers
}

systembeepoff() {
    dialog --infobox "Getting rid of that retarded error beep sound..." 10 50
    rmmod pcspkr
    echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf
}

resetpulse() {
    dialog --infobox "Reseting Pulseaudio..." 4 50
    killall pulseaudio
    sudo -n "$name" pulseaudio --start
}

finish() {
    dialog --title "Welcome" --msgbox "The installation is done! You can reboot your system now." 10 80
}

##########################################################################################################################

mv install.sh /tmp/install.sh

# Check if user is root on Arch distro. Install dialog.
initialcheck

# Welcome user.
welcomemsg

# Get and verify username and password.
getuserandpass

# Give warning if user already exists.
usercheck || { clear; exit; }

# Last chance for user to back out before install.
preinstallmsg || { clear; exit; }

adduserandpass

refreshkeys

newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

installyay

install

# Install the dotfiles in the user's home directory
putgitrepo "$dotfilesrepo" "/home/$name" "dotfiles-i3"

installdotfiles "/home/$name/dotfiles-i3" "install_dotfiles.sh"

sudo -u $name betterlockscreen -u /home/$name/Pictures/wallpaper1.png

putgitrepo "$vundlerepo" "/home/$name/.vim/bundle/" "Vundle.vim"

# Pulseaudio, if/when initially installed, often needs a restart to work immediately.
[[ -f /usr/bin/pulseaudio ]] && resetpulse

serviceinit NetworkManager lightdm

systembeepoff

newperms "%wheel ALL=(ALL) ALL\\n%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/yay"

sed -i "s/^#Color/Color/g" /etc/pacman.conf

# Fix audio problem
sed -i 's/^ autospawn/; autospawn/g' /etc/pulse/client.conf

finish && clear
