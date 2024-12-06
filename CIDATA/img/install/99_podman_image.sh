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

LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed buildah

buildah --cap-add=SYS_CHROOT,NET_ADMIN,NET_RAW --name worker from scratch
buildah config --entrypoint "/usr/sbin/init" --cmd '["--log-level=info", "--unit=multi-user.target"]' worker
scratchmnt=$(buildah mount worker)
mount --bind "${scratchmnt}" /mnt

pushd /mnt
unsquashfs -d . /srv/pxe/arch/x86_64/pxeboot.img
popd

fuser -km /mnt || true
sync
umount /mnt || true
buildah umount worker

buildah commit worker cloud-init-metal

mkdir -p /srv/docker
buildah push cloud-init-metal docker-archive:/srv/docker/cloud-init-metal.tar
zstd -4 /srv/docker/cloud-init-metal.tar
buildah rm worker
