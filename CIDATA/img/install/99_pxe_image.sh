#!/usr/bin/env bash

# remove line to enable build
#exit 0
if ! [ -f /bin/pacman ]; then
    exit 0
fi

exec &> >(while IFS=$'\r' read -ra line; do [ -z "${line[@]}" ] && line=( '' ); echo -e "[$(cat /proc/uptime | cut -d' ' -f1)] ${line[-1]}" | tee -a /cidata_log /dev/ttyS0 > /dev/tty1; done)

if ! mountpoint -q /mnt; then
    echo "!! no mountpoint at /mnt, aborting"
    exit 1
fi

# create a squashfs snapshot based on rootfs
LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed squashfs-tools
mkdir -p /mnt/pxe/arch/x86_64
mksquashfs / /mnt/pxe/arch/x86_64/pxeboot.img -comp zstd -Xcompression-level 4 -b 1M -progress -wildcards \
  -e "boot/*" "cidata*" "dev/*" "etc/fstab" "etc/crypttab" "etc/crypttab.initramfs" "proc/*" "sys/*" "run/*" "mnt/*" "media/*" "tmp/*" "var/tmp/*" "var/log/*" "var/cache/pacman/pkg/*"

# unmount the shared folder
umount /mnt