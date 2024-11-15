#!/usr/bin/env bash

if [ -z "$ENABLE_PODMAN" ]; then
    LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed docker docker-compose portainer-bin
else
    LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed podman-docker podman-compose docker-compose fuse-overlayfs \
        btrfs-progs portainer-bin cockpit-podman
fi

if [ -f /usr/lib/systemd/system/docker.service ]; then
    # enable br_netfilter for docker
    tee /etc/sysctl.d/br_netfilter.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
    tee /etc/modules-load.d/br_netfilter.conf <<EOF
br_netfilter
EOF
    # Enable all configured services
    systemctl enable docker portainer
else
    # Enable all configured services
    systemctl enable podman portainer
fi

firewall-offline-cmd --zone=public --add-port=8000/tcp
firewall-offline-cmd --zone=public --add-port=9000/tcp
firewall-offline-cmd --zone=public --add-port=9443/tcp
