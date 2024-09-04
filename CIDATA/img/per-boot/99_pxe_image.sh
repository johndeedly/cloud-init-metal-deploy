#!/usr/bin/env bash

# remove line to enable build
exit 0
if ! [ -f /bin/pacman ]; then
    ( ( sleep 1 && rm -- "${0}" ) & )
    exit 0
fi

exec &> >(while read -r line; do echo -e "[$(cat /proc/uptime | cut -d' ' -f1)] $line" | tee -a /cidata_log > /dev/tty1; done)

# virtualbox or qemu
VIRTENV=$(systemd-detect-virt)
mkdir -p /share
if [ "oracle" = "$VIRTENV" ]; then
    mount -t vboxsf -o rw host.0 /share
elif [ "kvm" = "$VIRTENV" ] || [ "qemu" = "$VIRTENV" ]; then
    mount -t 9p -o trans=virtio,version=9p2000.L,rw host.0 /share
else
    exit 1
fi

# create a squashfs snapshot based on rootfs
LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed squashfs-tools
mkdir -p /share/pxe/arch/x86_64
mksquashfs / /share/pxe/arch/x86_64/pxeboot.img -comp zstd -Xcompression-level 4 -b 1M -progress -wildcards \
  -e "boot/*" "cidata*" "dev/*" "etc/fstab" "etc/crypttab" "etc/crypttab.initramfs" "proc/*" "sys/*" "run/*" "mnt/*" "media/*" "share/*" "tmp/*" "var/tmp/*" "var/log/*" "var/cache/pacman/pkg/*"

# unmount the shared folder
umount /share

# cleanup
rm -- "${0}"
