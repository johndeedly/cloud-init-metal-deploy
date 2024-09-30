#!/usr/bin/env bash

if ! [ -f /bin/apt ] || grep -q Ubuntu /proc/version; then
    ( ( sleep 1 && rm -- "${0}" ) & )
    exit 0
fi

# only after step 1 reboot
if [ -f "/var/lib/cloud/scripts/per-boot/40_proxmox_step1.sh" ]; then
    exit 0
fi

exec &> >(while IFS=$'\r' read -ra line; do [ -z "${line[@]}" ] && line=( '' ); echo -e "[$(cat /proc/uptime | cut -d' ' -f1)] ${line[-1]}" | tee -a /cidata_log > /dev/tty1; done)

# wait online
echo ":: wait for any interface to be online"
/usr/lib/systemd/systemd-networkd-wait-online --operational-state=routable --any

# ifupdown2 is a pain in the a**
LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive apt update
LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt install --reinstall ifupdown2

# https://www.tecmint.com/install-proxmox/
# as of today, ifupdown2 will fix itself here in a silent and wonderous way
# might break in the future, of course, most probably
LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt install curl software-properties-common apt-transport-https ca-certificates gnupg2

# install proxmox default kernel
LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt install proxmox-default-kernel

# remove all other debian kernels
LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt remove linux-image-amd64 'linux-image-6.1*'

# Set hostname in etc/hosts
FQDNAME=$(cat /etc/hostname)
HOSTNAME=${FQDNAME%%.*}
tee /tmp/hosts_columns <<EOF
# IPv4/v6|FQDN|HOSTNAME
127.0.0.1|$FQDNAME|$HOSTNAME
::1|$FQDNAME|$HOSTNAME
127.0.0.1|localhost.internal|localhost
::1|localhost.internal|localhost
EOF
ip -f inet addr | awk '/inet / {print $2}' | cut -d'/' -f1 | while read -r PUB_IP_ADDR; do
tee -a /tmp/hosts_columns <<EOF
$PUB_IP_ADDR|$FQDNAME|$HOSTNAME
EOF
done
tee /etc/hosts <<EOF
# Static table lookup for hostnames.
# See hosts(5) for details.

# https://www.icann.org/en/public-comment/proceeding/proposed-top-level-domain-string-for-private-use-24-01-2024
$(column /tmp/hosts_columns -t -s '|')
EOF
rm /tmp/hosts_columns

# sync everything to disk
sync

# reboot system
( ( sleep 5 && systemctl reboot ) & )

# cleanup
rm -- "${0}"
