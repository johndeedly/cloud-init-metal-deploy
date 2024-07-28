#!/usr/bin/env bash

# Remount copy on write space
mount -o remount,size=75% /run/archiso/cowspace || true

# Make the journal log persistent on ramfs
mkdir -p /var/log/journal
systemd-tmpfiles --create --prefix /var/log/journal
systemctl restart systemd-journald

# search for the CIDATA drive or partition and mount it
CIDATA_DEVICE=$(lsblk -no PATH,LABEL,FSTYPE | sed -e '/cidata/I!d' -e '/iso9660/I!d' | head -n1 | cut -d' ' -f1)

# mount step
mkdir -p /iso
mount "$CIDATA_DEVICE" /iso

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

#CLOUD_IMAGE_PATH=$(find /iso/CIDATA/img/ -type f -size +50M \( -iname '*.qcow2' -o -iname '*.img' -o -iname '*.tar.xz' \) | head -n1)
#echo "CLOUD-IMAGE: ${CLOUD_IMAGE_PATH}"
#
#LC_ALL=C yes | LC_ALL=C pacman -Sy --noconfirm libguestfs qemu-base
#
#modprobe nbd max_part=8
#qemu-nbd --connect=/dev/nbd0 --read-only "${CLOUD_IMAGE_PATH}"
#sleep 1
#partx -u /dev/nbd0
#sleep 1
#
#CLOUD_IMAGE_LAYOUT=$(fdisk /dev/nbd0 -l)
#ROOT_FDISK=( $(echo -en "$CLOUD_IMAGE_LAYOUT" | sed -e '/root/I!d' | head -n1) )
#BIOS_FDISK=( $(echo -en "$CLOUD_IMAGE_LAYOUT" | sed -e '/bios/I!d' | head -n1) )
#EFI_FDISK=( $(echo -en "$CLOUD_IMAGE_LAYOUT" | sed -e '/efi/I!d' | head -n1) )

# create basic pxe boot structure for http and tftp
mkdir -p /share/pxe/http/arch/x86_64
mkdir -p /share/pxe/tftp/{bios,efi32,efi64}
mkdir -p /tmp/{lower,upper,work,root}

# mount "${ROOT_FDISK[0]}" /tmp/lower
mount /run/archiso/bootmnt/arch/x86_64/airootfs.sfs /tmp/lower
mount -t overlay none -olowerdir=/iso/CIDATA:/tmp/lower,upperdir=/tmp/upper,workdir=/tmp/work /tmp/root
mkdir -p /tmp/root/cidata
mv /tmp/root/img /tmp/root/cidata/
mv /tmp/root/meta-data /tmp/root/cidata/
mv /tmp/root/network-config /tmp/root/cidata/
mv /tmp/root/user-data /tmp/root/cidata/
mv /tmp/root/vendor-data /tmp/root/cidata/
find /tmp/root/cidata/img/ -maxdepth 1 -name "*.disabled" -delete
arch-chroot /tmp/root systemctl disable systemd-time-wait-sync.service
arch-chroot /tmp/root systemctl mask time-sync.target

if [ -f /share/pxe/http/arch/x86_64/pxeboot.img ]; then
  rm /share/pxe/http/arch/x86_64/pxeboot.img
fi
mksquashfs /tmp/root /share/pxe/http/arch/x86_64/pxeboot.img -comp zstd -Xcompression-level 4 -b 1M -progress -wildcards \
  -e "boot/*" "dev/*" "etc/fstab" "etc/crypttab" "etc/crypttab.initramfs" "proc/*" "sys/*" "run/*" "mnt/*" "media/*" "tmp/*" "var/tmp/*" "var/cache/pacman/pkg/*"
chown root:root /share/pxe/http/arch/x86_64/pxeboot.img
chmod 644 /share/pxe/http/arch/x86_64/pxeboot.img

# Configure tftp
mkdir -p /share/pxe/tftp/{bios,efi32,efi64}/pxelinux.cfg
cp -ar /usr/lib/syslinux/bios /share/pxe/tftp/
cp -ar /usr/lib/syslinux/efi32 /share/pxe/tftp/
cp -ar /usr/lib/syslinux/efi64 /share/pxe/tftp/
cp /iso/pxecfg_bootdefault /share/pxe/tftp/bios/pxelinux.cfg/default
cp /iso/pxecfg_bootdefault /share/pxe/tftp/efi32/pxelinux.cfg/default
cp /iso/pxecfg_bootdefault /share/pxe/tftp/efi64/pxelinux.cfg/default
sed -i 's/MENU TITLE \(.*\)/MENU TITLE \1 [BIOS 32bit]/' /share/pxe/tftp/bios/pxelinux.cfg/default
sed -i 's/MENU TITLE \(.*\)/MENU TITLE \1 [EFI 32bit]/' /share/pxe/tftp/efi32/pxelinux.cfg/default
sed -i 's/MENU TITLE \(.*\)/MENU TITLE \1 [EFI 64bit]/' /share/pxe/tftp/efi64/pxelinux.cfg/default

LC_ALL=C yes | LC_ALL=C pacman -Sy --noconfirm --needed imagemagick elementary-wallpapers
magick /usr/share/backgrounds/elementaryos-default -resize 640x480 PNG8:/share/pxe/tftp/bios/splash.png
cp /share/pxe/tftp/bios/splash.png /share/pxe/tftp/efi32/splash.png
cp /share/pxe/tftp/bios/splash.png /share/pxe/tftp/efi64/splash.png

# create pxe boot initramfs
mkdir -p /etc/initcpio/{install,hooks} /etc/mkinitcpio{,.conf}.d
cp /iso/pxecfg /etc/pxe.conf
cp /iso/pxepreset /etc/mkinitcpio.d/pxe.preset
cp /iso/install/pxe /etc/initcpio/install/pxe
cp /iso/install/pxe_http /etc/initcpio/install/pxe_http
cp /iso/hooks/pxe /etc/initcpio/hooks/pxe
cp /iso/hooks/pxe_http /etc/initcpio/hooks/pxe_http

mkdir -p /var/tmp/mkinitcpio
mkinitcpio -p pxe -t /var/tmp/mkinitcpio
rm -rf /var/tmp/mkinitcpio

rsync -av --chown=root:root --chmod=Du=rwx,Dg=rx,Do=rx,Fu=rw,Fg=r,Fo=r /boot/initramfs-linux-pxe.img /run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux /share/pxe/http/arch/x86_64/
