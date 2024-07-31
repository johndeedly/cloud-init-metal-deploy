#!/usr/bin/env bash

# ⚠️ WORK IN PROGRESS ⚠️
# this script does work mostly and for the broken parts it just needs the scripts
# from my other projects to be copied over. please be patient...

# remove line to enable build
exit 0
if ! [ -f /bin/pacman ]; then
    exit 0
fi

LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed \
  pipewire pipewire-pulse pipewire-jack pipewire-alsa wireplumber pamixer pavucontrol playerctl alsa-utils qpwgraph rtkit realtime-privileges \
  xorg-server xorg-xinit xorg-xrandr xautolock slock xclip xsel brightnessctl gammastep arandr dunst libnotify xarchiver \
  flameshot libinput xf86-input-libinput xorg-xinput kitty wofi dex xrdp ibus ibus-typing-booster lightdm lightdm-slick-greeter \
  archlinux-wallpaper elementary-wallpapers elementary-icon-theme ttf-dejavu ttf-dejavu-nerd ttf-liberation ttf-font-awesome ttf-hanazono \
  ttf-hannom ttf-baekmuk noto-fonts-emoji ttf-ms-fonts \
  cups ipp-usb libreoffice-fresh libreoffice-fresh-de krita seahorse freerdp notepadqq gitg keepassxc pdfpc zettlr obsidian \
  texlive-bin xdg-desktop-portal xdg-desktop-portal-gtk wine-wow64 winetricks mpv gpicview qalculate-gtk drawio-desktop code \
  pamac flatpak gnome-keyring \
  cinnamon cinnamon-translations networkmanager system-config-printer

# enable some services
systemctl enable cups NetworkManager
systemctl mask NetworkManager-wait-online

# do not wait for online interfaces
mkdir -p /etc/systemd/system/NetworkManager-wait-online.service.d
tee /etc/systemd/system/NetworkManager-wait-online.service.d/wait-online-never.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/nm-online -x -q
EOF

# add flathub repo to system when not present
flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# install betterbird
flatpak install --system --assumeyes --noninteractive --or-update flathub eu.betterbird.Betterbird

# set slick greeter as default
sed -i 's/^#\?greeter-show-manual-login=.*/greeter-show-manual-login=true/' /etc/lightdm/lightdm.conf
sed -i 's/^#\?greeter-hide-users=.*/greeter-hide-users=true/' /etc/lightdm/lightdm.conf
sed -i 's/^#\?greeter-session=.*/greeter-session=lightdm-slick-greeter/' /etc/lightdm/lightdm.conf

# configuration for slick-greeter
tee /etc/lightdm/slick-greeter.conf <<EOF
[Greeter]
# LightDM GTK+ Configuration
#
background=/usr/share/backgrounds/elementaryos-default
show-hostname=true
clock-format=%H:%M
EOF

# enable lightdm
rm /etc/systemd/system/display-manager.service || true
ln -s /usr/lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service

# create profile for X11 sessions
tee /etc/skel/.xprofile <<EOF
#!/bin/sh
[ -f ~/.bash_profile ] && . ~/.bash_profile
EOF

# menu key is equal to super key
tee /etc/skel/.Xmodmap <<EOF
keysym Menu = Super_R
EOF

# configure cinnamon desktop
XDG_CONFIG_HOME=/etc/skel/.config dconf dump /org/cinnamon/ > /etc/skel/dconf-dump.ini
tee -a /etc/skel/dconf-dump.ini <<EOF

[/]
favorite-apps=['org.mozilla.firefox.desktop:flatpak', 'eu.betterbird.Betterbird.desktop:flatpak', 'kitty.desktop', 'cinnamon-settings.desktop', 'nemo.desktop']

[desktop/background]
picture-uri='file:///usr/share/backgrounds/elementaryos-default'
picture-options='zoom'
primary-color='000000'
secondary-color='000000'
draw-background=true

[desktop/interface]
icon-theme='elementary'

[desktop/applications/calculator]
exec='qalculate-gtk'

[desktop/applications/terminal]
exec='kitty'
exec-arg='--'

[desktop/keybindings]
custom-list=['__dummy__', 'custom0', 'custom1', 'custom2', 'custom3', 'custom4']
looking-glass-keybinding=@as []
pointer-next-monitor=@as []
pointer-previous-monitor=@as []
show-desklets=@as []

[desktop/keybindings/custom-keybindings/custom0]
binding=['<Shift><Super>Return', '<Shift><Super>KP_Enter']
command='wofi --fork --normal-window --insensitive --allow-images --allow-markup --show drun'
name='wofi'

[desktop/keybindings/custom-keybindings/custom1]
binding=['<Super>p', 'XF86Display']
command='arandr'
name='arandr'

[desktop/keybindings/custom-keybindings/custom2]
binding=['<Alt>e']
command='kitty /usr/bin/lf'
name='lf'

[desktop/keybindings/custom-keybindings/custom3]
binding=['<Alt>w']
command='flatpak run org.chromium.Chromium'
name='chromium'

[desktop/keybindings/custom-keybindings/custom4]
binding=['<Control><Shift>e']
command='ibus emoji'
name='emoji picker'

[desktop/keybindings/media-keys]
calculator=['<Super>period']
email=@as []
home=['<Super>e']
screensaver=['<Super>l', 'XF86ScreenSaver']
search=@as []
terminal=['<Super>Return', '<Super>KP_Enter']
www=['<Super>w']

[desktop/keybindings/wm]
activate-window-menu=@as []
begin-move=@as []
begin-resize=@as []
close=['<Super>q']
move-to-monitor-down=['<Ctrl><Shift><Super>Down']
move-to-monitor-left=['<Ctrl><Shift><Super>Left']
move-to-monitor-right=['<Ctrl><Shift><Super>Right']
move-to-monitor-up=['<Ctrl><Shift><Super>Up']
move-to-workspace-1=['<Shift><Super>1']
move-to-workspace-2=['<Shift><Super>2']
move-to-workspace-3=['<Shift><Super>3']
move-to-workspace-4=['<Shift><Super>4']
move-to-workspace-5=['<Shift><Super>5']
move-to-workspace-6=['<Shift><Super>6']
move-to-workspace-7=['<Shift><Super>7']
move-to-workspace-8=['<Shift><Super>8']
move-to-workspace-9=['<Shift><Super>9']
move-to-workspace-10=@as []
move-to-workspace-11=@as []
move-to-workspace-12=@as []
move-to-workspace-down=['<Shift><Super>Down']
move-to-workspace-left=['<Shift><Super>Left']
move-to-workspace-right=['<Shift><Super>Right']
move-to-workspace-up=['<Shift><Super>Up']
panel-run-dialog=@as []
push-tile-down=['<Ctrl><Super>Down']
push-tile-left=['<Ctrl><Super>Left']
push-tile-right=['<Ctrl><Super>Right']
push-tile-up=['<Ctrl><Super>Up']
show-desktop=@as []
switch-group=@as []
switch-group-backward=@as []
switch-monitor=@as []
switch-panels=@as []
switch-panels-backward=@as []
switch-to-workspace-1=['<Super>1']
switch-to-workspace-2=['<Super>2']
switch-to-workspace-3=['<Super>3']
switch-to-workspace-4=['<Super>4']
switch-to-workspace-5=['<Super>5']
switch-to-workspace-6=['<Super>6']
switch-to-workspace-7=['<Super>7']
switch-to-workspace-8=['<Super>8']
switch-to-workspace-9=['<Super>9']
switch-to-workspace-10=@as []
switch-to-workspace-11=@as []
switch-to-workspace-12=@as []
switch-to-workspace-down=['<Super>Down']
switch-to-workspace-left=['<Super>Left']
switch-to-workspace-right=['<Super>Right']
switch-to-workspace-up=['<Super>Up']
switch-windows=['<Super>Tab']
switch-windows-backward=['<Shift><Super>Tab']
toggle-maximized=['<Super>f']
unmaximize=@as []

[settings-daemon/plugins/power]
button-power='shutdown'

[muffin]
placement-mode='center'

[desktop/wm/preferences]
mouse-button-modifier='<Super>'
EOF
dbus-run-session -- bash -c 'XDG_CONFIG_HOME=/etc/skel/.config dconf load /org/cinnamon/ < /etc/skel/dconf-dump.ini'
rm /etc/skel/dconf-dump.ini

# install code-oss extensions for user"
( HOME=/etc/skel /bin/bash -c '
# csharp
code --install-extension muhammad-sammy.csharp --force
# xml
code --install-extension dotjoshjohnson.xml --force
# better comments
code --install-extension aaron-bond.better-comments --force
# git graph
code --install-extension mhutchie.git-graph --force
# git blame
code --install-extension waderyan.gitblame --force
# yara
code --install-extension infosec-intern.yara --force
# hex editor
code --install-extension ms-vscode.hexeditor --force
# german language pack
code --install-extension ms-ceintl.vscode-language-pack-de --force
# color code highlighter
code --install-extension naumovs.color-highlight --force
' ) &
pid=$!
wait $pid

echo ":: append gnome keyring to pam login"
# see https://wiki.archlinux.org/title/GNOME/Keyring#PAM_step
if [ -f /etc/pam.d/login ]; then
  sed -i 's/auth\s\+include\s\+system-local-login/auth       include      system-local-login\nauth       optional     pam_gnome_keyring.so/' /etc/pam.d/login
  sed -i 's/session\s\+include\s\+system-local-login/session    include      system-local-login\nsession    optional     pam_gnome_keyring.so auto_start/' /etc/pam.d/login
  systemctl --global disable gnome-keyring-daemon.socket
fi
if [ -f /etc/pam.d/passwd ]; then
  sed -i 's/password\s\+include\s\+system-auth/password        include         system-auth\npassword        optional        pam_gnome_keyring.so/' /etc/pam.d/passwd
fi
