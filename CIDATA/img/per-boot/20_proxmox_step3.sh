#!/usr/bin/env bash

if ! [ -f /bin/apt ] || grep -q Ubuntu /proc/version; then
    ( ( sleep 1 && rm -- "${0}" ) & )
    exit 0
fi

# only after step 2 reboot
if [ -f "/var/lib/cloud/scripts/per-boot/30_proxmox_step2.sh" ]; then
    exit 0
fi

exec 2>&1 &> >(while read -r line; do echo -e "[$(cat /proc/uptime | cut -d' ' -f1)] $line" | tee -a /cidata_log > /dev/tty1; done)

# install the main proxmox packages
LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt install proxmox-ve postfix open-iscsi chrony

# apply the new settings to grub
update-grub

# default network bridge: private sub network with masquerading to the outwards network
tee -a /etc/network/interfaces <<EOF

auto vmbr0
#private sub network
iface vmbr0 inet static
    address  172.31.100.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    post-up   echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up   iptables -t nat -A POSTROUTING -s '172.31.100.0/24' -o enp0s3 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s '172.31.100.0/24' -o enp0s3 -j MASQUERADE
    post-up   iptables -t raw -I PREROUTING -i fwbr+ -j CT --zone 1
    post-down iptables -t raw -D PREROUTING -i fwbr+ -j CT --zone 1
EOF

# open up the port for the proxmox webinterface
firewall-offline-cmd --zone=public --add-port=8006/tcp

# sync everything to disk
sync

# reboot system
( ( sleep 5 && systemctl reboot ) & )

# cleanup
rm -- "${0}"
