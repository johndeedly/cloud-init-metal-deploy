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
mkdir -p /share/pxe/{tftp,http}/arch/x86_64
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

if [ -f /share/pxe/http/arch/x86_64/airootfs.sfs ]; then
  rm /share/pxe/http/arch/x86_64/airootfs.sfs
fi
mksquashfs /tmp/root /share/pxe/http/arch/x86_64/airootfs.sfs -comp zstd -Xcompression-level 4 -b 1M -progress -wildcards \
  -e "boot/*" "dev/*" "etc/fstab" "etc/crypttab" "etc/crypttab.initramfs" "proc/*" "sys/*" "run/*" "mnt/*" "media/*" "tmp/*" "var/tmp/*" "var/cache/pacman/pkg/*"

rsync -av /run/archiso/bootmnt/boot/syslinux/ /share/pxe/tftp/
rsync -av /run/archiso/bootmnt/arch/boot/x86_64/*linux* /share/pxe/tftp/arch/x86_64/

# create pxe boot initramfs
mkdir -p /etc/initcpio/{install,hooks} /etc/mkinitcpio{,.conf}.d
tee /etc/pxe.conf <<EOF
HOOKS=(base udev keyboard modconf pxe pxe_http block filesystems)
COMPRESSION="zstd"
EOF

tee /etc/mkinitcpio.d/pxe.preset <<EOF
ALL_kver="/run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux"
#microcode=(/boot/*-ucode.img)

PRESETS=('pxe')

pxe_config='/etc/pxe.conf'
pxe_image="/boot/initramfs-linux-pxe.img"
EOF

cp /iso/install/pxe /etc/initcpio/install/pxe
cp /iso/install/pxe_http /etc/initcpio/install/pxe_http
cp /iso/hooks/pxe /etc/initcpio/hooks/pxe
cp /iso/hooks/pxe_http /etc/initcpio/hooks/pxe_http

mkdir -p /var/tmp/mkinitcpio
mkinitcpio -p pxe -t /var/tmp/mkinitcpio
rm -rf /var/tmp/mkinitcpio

# create default pxe boot entry to boot from http
mkdir -p /share/pxe/tftp/pxelinux.cfg
tee /share/pxe/tftp/pxelinux.cfg/default <<EOF
UI vesamenu.c32
SERIAL 0 115200
PROMPT 0
TIMEOUT 20
ONTIMEOUT ArchHTTP

MENU TITLE Arch Linux PXE Menu
MENU BACKGROUND splash.png

MENU WIDTH 78
MENU MARGIN 4
MENU ROWS 7
MENU VSHIFT 10
MENU TABMSGROW 14
MENU CMDLINEROW 14
MENU HELPMSGROW 16
MENU HELPMSGENDROW 29

MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #30ffffff #00000000 std

MENU CLEAR
MENU IMMEDIATE


LABEL ArchHTTP
MENU LABEL Boot Arch Linux using HTTP
LINUX arch/x86_64/vmlinuz-linux
INITRD arch/x86_64/initramfs-linux-pxe.img
APPEND pxe_http_srv=http://\${pxeserver}/ cow_spacesize=75% ds=nocloud;s=file:///cidata/
SYSAPPEND 3
EOF
