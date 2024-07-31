#!/usr/bin/env bash

# ⚠️ WORK IN PROGRESS ⚠️
# this script does work mostly, but the quality is pretty bad,
# it just works on Debian or apps are missing.

# remove line to enable build
exit 0
if ! [ -f /bin/apt ]; then
    exit 0
fi

# Debian does work, Ubuntu does not... Canonical surpasses itself again...
if grep -q Ubuntu /proc/version; then
    exit 0
fi

LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt -y install \
  pipewire pipewire-pulse pipewire-jack pipewire-alsa wireplumber pamixer pavucontrol playerctl alsa-utils qpwgraph rtkit \
  xserver-xorg xinit lxrandr xautolock slock xclip xsel brightnessctl gammastep arandr dunst libnotify-bin xarchiver \
  flameshot libinput-bin xserver-xorg-input-libinput kitty wofi dex xrdp ibus ibus-typing-booster \
  elementary-icon-theme plasma-workspace-wallpapers \
  cups ipp-usb libreoffice krita evolution seahorse freerdp3-x11 notepadqq gitg keepassxc pdfpc \
  texlive xdg-desktop-portal xdg-desktop-portal-gtk wine winetricks mpv gpicview qalculate-gtk \
  flatpak gnome-keyring \
  cinnamon cinnamon-l10n network-manager system-config-printer

tee /etc/skel/.xinitrc <<EOF
#!/usr/bin/env bash
#
# ~/.xinitrc
#

[[ -f /etc/X11/xinit/.Xresources ]] && xrdb -merge /etc/X11/xinit/.Xresources
[[ -f "$HOME/.Xresources" ]] && xrdb -merge "$HOME/.Xresources"

[[ -f /etc/X11/xinit/.Xmodmap ]] && xmodmap /etc/X11/xinit/.Xmodmap
[[ -f "$HOME/.Xmodmap" ]] && xmodmap "$HOME/.Xmodmap"

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
  for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

# fixed slow startup of gtk applications
# https://wiki.archlinux.org/title/XDG_Desktop_Portal
# https://unix.stackexchange.com/questions/748596/very-slow-launch-for-some-applications-after-update-to-debian-12/748604#748604
export XDG_CURRENT_DESKTOP="cinnamon"
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER="gles2"
export LIBSEAT_BACKEND="logind".
systemctl --user import-environment DISPLAY DBUS_SESSION_BUS_ADDRESS XDG_CURRENT_DESKTOP WLR_NO_HARDWARE_CURSORS WLR_RENDERER LIBSEAT_BACKEND
dbus-update-activation-environment --systemd DISPLAY DBUS_SESSION_BUS_ADDRESS XDG_CURRENT_DESKTOP WLR_NO_HARDWARE_CURSORS WLR_RENDERER LIBSEAT_BACKEND

exec cinnamon-session --session cinnamon
EOF

XDG_CONFIG_HOME=/etc/skel/.config dconf dump /org/cinnamon/ > /etc/skel/dconf-dump.ini
tee -a /etc/skel/dconf-dump.ini <<EOF

[/]
favorite-apps=['org.mozilla.firefox.desktop:flatpak', 'org.chromium.Chromium.desktop:flatpak', 'kitty.desktop', 'cinnamon-settings.desktop', 'nemo.desktop']

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
