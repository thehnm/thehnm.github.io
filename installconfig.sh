#!/bin/bash

mv installconfig.sh /tmp/installconfig.sh

pacman -S --noconfirm --needed dialog

choice=$(dialog --menu "Choose one:" 10 30 3 1 i3 2 dwm 3>&1 1>&2 2>&3 3>&1) || exit

cd /tmp/
case "$choice" in
    1 ) curl https://raw.githubusercontent.com/thehnm/tarbs/master/install.sh >> install.sh;;
    2 ) curl https://raw.githubusercontent.com/thehnm/tarbs/dwm/install.sh >> install.sh;;
esac
chmod +x install.sh
bash install.sh

rm /tmp/installconfig.sh
