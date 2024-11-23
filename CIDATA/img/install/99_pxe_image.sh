#!/usr/bin/env bash

# disable systemd-network-generator in pxe image
systemctl mask systemd-network-generator

# create a squashfs snapshot based on rootfs
LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed squashfs-tools
mkdir -p /srv/pxe/arch/x86_64
sync
mksquashfs / /srv/pxe/arch/x86_64/pxeboot.img -comp zstd -Xcompression-level 4 -b 1M -progress -wildcards \
  -e "boot/*" "cidata*" "dev/*" "etc/fstab" "etc/crypttab" "etc/crypttab.initramfs" "proc/*" "sys/*" "run/*" "mnt/*" "share/*" "srv/pxe/*" "media/*" "tmp/*" "var/tmp/*" "var/log/*" "var/cache/pacman/pkg/*"

# reenable systemd-network-generator
systemctl unmask systemd-network-generator

LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed mkinitcpio-nfs-utils curl ca-certificates-utils cifs-utils nfs-utils nbd open-iscsi nvme-cli

# configuring iscsi
sed -e 's/^node.conn[0].timeo.noop_out_interval.*/node.conn[0].timeo.noop_out_interval = 0/' \
    -e 's/^node.conn[0].timeo.noop_out_timeout.*/node.conn[0].timeo.noop_out_timeout = 0/' \
    -e 's/^node.session.timeo.replacement_timeout.*/node.session.timeo.replacement_timeout = 86400/' -i /etc/iscsi/iscsid.conf
tee /etc/udev/rules.d/50-iscsi.rules <<'EOF'
ACTION=="add", SUBSYSTEM=="scsi" , ATTR{type}=="0|7|14", RUN+="/bin/sh -c 'echo Y > /sys$$DEVPATH/timeout'"
EOF

echo ":: create skeleton for pxe boot mkinitcpio"
mkdir -p /etc/initcpio/{install,hooks}
cp /cidata/install/pxe/install/* /etc/initcpio/install/
chmod a+x /etc/initcpio/install/*
cp /cidata/install/pxe/hooks/* /etc/initcpio/hooks/
chmod a+x /etc/initcpio/hooks/*
mkdir -p /etc/mkinitcpio{,.conf}.d
cp /cidata/install/pxe/pxe.conf /etc/
cp /cidata/install/pxe/pxe.preset /etc/mkinitcpio.d/

echo ":: create pxe boot initcpio"
mkdir -p /var/tmp/mkinitcpio
mkinitcpio -p pxe -t /var/tmp/mkinitcpio
cp /boot/vmlinuz-linux /boot/initramfs-linux-pxe.img /srv/pxe/arch/x86_64/
chmod 644 /srv/pxe/arch/x86_64/*
chown root:root /srv/pxe/arch/x86_64/*
