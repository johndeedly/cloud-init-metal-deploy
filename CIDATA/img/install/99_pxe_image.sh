#!/usr/bin/env bash

# remove line to enable build
exit 0
if ! [ -f /bin/pacman ]; then
    exit 0
fi

exec &> >(while IFS=$'\r' read -ra line; do [ -z "${line[@]}" ] && line=( '' ); echo -e "[$(cat /proc/uptime | cut -d' ' -f1)] ${line[-1]}" | tee -a /cidata_log > /dev/tty1; done)

# create a squashfs snapshot based on rootfs
LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed squashfs-tools
mkdir -p /share/pxe/arch/x86_64
mksquashfs / /share/pxe/arch/x86_64/pxeboot.img -comp zstd -Xcompression-level 4 -b 1M -progress -wildcards \
  -e "boot/*" "cidata*" "dev/*" "etc/fstab" "etc/crypttab" "etc/crypttab.initramfs" "proc/*" "sys/*" "run/*" "mnt/*" "share/*" "media/*" "tmp/*" "var/tmp/*" "var/log/*" "var/cache/pacman/pkg/*"

LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed mkinitcpio-nfs-utils curl ca-certificates-utils cifs-utils nfs-utils nbd open-iscsi nvme-cli

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
cp /boot/vmlinuz-linux /boot/initramfs-linux-pxe.img /share/pxe/arch/x86_64/
