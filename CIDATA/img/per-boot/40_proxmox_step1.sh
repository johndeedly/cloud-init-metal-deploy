#!/usr/bin/env bash

if ! [ -f /bin/apt ] || grep -q Ubuntu /proc/version; then
    ( ( sleep 1 && rm -- "${0}" ) & )
    exit 0
fi

exec &> >(while IFS=$'\r' read -ra line; do [ -z "${line[@]}" ] && line=( '' ); echo -e "[$(cat /proc/uptime | cut -d' ' -f1)] ${line[-1]}" | tee -a /cidata_log > /dev/tty1; done)

# wait online
echo ":: wait for any interface to be online"
/usr/lib/systemd/systemd-networkd-wait-online --operational-state=routable --any

# add the proxmox repository and some bookworm related stuff to the package sources
tee -a /etc/apt/sources.list <<EOF

deb http://ftp.debian.org/debian bookworm main contrib
deb http://ftp.debian.org/debian bookworm-updates main contrib

deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription

deb http://security.debian.org/debian-security bookworm-security main contrib
EOF

# verify and install the proxmox repository key
echo ":: download proxmox repository certificate"
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg
CHECKSUM=$(sha512sum /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg | cut -d ' ' -f1)
TARGET="7da6fe34168adc6e479327ba517796d4702fa2f8b4f0a9833f5ea6e6b48f6507a6da403a274fe201595edc86a84463d50383d07f64bdde2e3658108db7d6dc87"
if [ "$TARGET" != "$CHECKSUM" ]; then
    echo "!! checksum mismatch"
    exit 1
fi

# update and upgrade
LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive apt update
LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt upgrade --with-new-pkgs

# ifupdown2 is a special kind of gift by the proxmox devs
# when installed as intended by the docs, it will whine about already running in the background (WHAT THE F***?!)
# the debian version of this package is not good enough or infinite versions behind, of course, so the only known way
# by me to tame this beast is the following stuntshow in two acts including a reboot...
LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt purge ifupdown || true
LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt purge ifupdown2 || true
LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt install ifupdown2

# sync everything to disk
sync

# reboot system
( ( sleep 5 && systemctl reboot ) & )

# cleanup
rm -- "${0}"
