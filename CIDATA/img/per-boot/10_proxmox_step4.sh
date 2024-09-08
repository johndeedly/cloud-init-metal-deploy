#!/usr/bin/env bash

if ! [ -f /bin/apt ] || grep -q Ubuntu /proc/version; then
    ( ( sleep 1 && rm -- "${0}" ) & )
    exit 0
fi

# only after step 3 reboot
if [ -f "/var/lib/cloud/scripts/per-boot/20_proxmox_step3.sh" ]; then
    exit 0
fi

exec &> >(while read -r line; do echo -e "[$(cat /proc/uptime | cut -d' ' -f1)] $line" | tee -a /cidata_log > /dev/tty1; done)

# create proxmox groups
pveum group add admins
pveum group add users

# create local user pveadm
USERID=pveadm
USERHASH=$(openssl passwd -6 -salt abcxyz "${USERID}")
useradd -m -r -s /bin/bash "$USERID"
sed -i 's/^'"$USERID"':[^:]*:/'"$USERID"':'"${USERHASH//\//\\/}"':/' /etc/shadow
pveum user add "$USERID"@pam -groups admins

# add permissions to groups and pools
pveum acl modify / --roles Administrator -groups admins -propagate 1
pveum acl modify /mapping --roles PVEMappingUser -groups users -propagate 1
ip -j link show | jq -r '.[] | select(.link_type != "loopback" and (.ifname | startswith("vmbr"))) | .ifname' | while read -r line; do
  pveum acl modify /sdn/zones/localnetwork/$line --roles PVESDNUser -groups users -propagate 1
done
pveum acl modify /storage --roles PVEDatastoreUser -groups users -propagate 1

# add local admins to group admins
for username in root pveadm; do
  pveum user add "$username"@pam || true
  pveum user modify "$username"@pam -groups admins || true
done

# add local users to group users
getent passwd | while IFS=: read -r username x uid gid gecos home shell; do
  if [ -n "$home" ] && [ -d "$home" ] && [ "${home:0:6}" == "/home/" ]; then
    if [ "$uid" -ge 1000 ]; then
      pveum user add "$username"@pam || true
      pveum user modify "$username"@pam -groups users || true
    fi
  fi
done

# create first pool pool1
pveum pool add pool1 || true
pveum acl modify /pool/pool1 --roles PVEPoolUser,PVETemplateUser -groups users -propagate 1 || true

# create user pools and vlans
pveum user list -full | grep " users " | cut -d' ' -f2 | while read -r username; do
  poolname=$(echo -en "pool-$username" | cut -d'@' -f1)
  pveum pool add "$poolname" || true
  pveum acl modify "/pool/$poolname" --roles PVEAdmin -users "$username" -propagate 1 || true
  brname=$(echo -en "br$username" | cut -d'@' -f1)
  if ! grep -qE "$brname" /etc/network/interfaces; then
    tee -a /etc/network/interfaces <<EOF

auto $brname
iface $brname inet static
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
EOF
  fi
  pveum acl modify "/sdn/zones/localnetwork/$brname" --roles PVESDNUser -users "$username" -propagate 1 || true
done
ifreload -a

# removes the nagging "subscription missing" popup on login (no permanent solution)
sed -Ezi 's/(function\(orig_cmd\) \{)/\1\n\torig_cmd\(\);\n\treturn;/g' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# add cloud images as lxc templates
lxcid=$((980))
while IFS=, read -r cloud_image cloud_url; do
  if [ -z "$cloud_image" ]; then
    continue
  fi
  pushd /var/lib/vz/template/cache
    echo ":: download $cloud_url"
    wget --progress=dot:mega -O "$cloud_image.tar.xz" "$cloud_url"
    echo ":: create container template $lxcid named $cloud_image"
    pct create $lxcid "local:vztmpl/$cloud_image.tar.xz" --hostname "$cloud_image" --pool pool1 --memory 512 --net0 name=eth0,bridge=vmbr0
    pct start $lxcid
    pct enter $lxcid <<'EOF'
USERID=root
USERHASH=$(openssl passwd -6 -salt abcxyz 'packer-build-passwd')
sed -i 's/^'"$USERID"':[^:]*:/'"$USERID"':'"${USERHASH//\//\\/}"':/' /etc/shadow
if [ -f /etc/cloud/cloud-init.disabled ]; then
  rm /etc/cloud/cloud-init.disabled
fi
mkdir -p /cidata
touch /cidata/meta-data
touch /cidata/vendor-data
tee /cidata/user-data <<'EOX'
#cloud-config

locale: de_DE
EOX
tee /cidata/network-config <<'EOX'
version: 2
ethernets:
  en:
    match:
      name: en*
    dhcp4: true
  eth:
    match:
      name: eth*
    dhcp4: true
EOX
tee /etc/cloud/cloud.cfg.d/99_nocloud.cfg <<'EOX'
disable_ec2_metadata: true
datasource_list: [ "NoCloud" ]
datasource:
  NoCloud:
    seedfrom: file:///cidata
EOX
cloud-init clean
EOF
    pct stop $lxcid
    pct template $lxcid
  popd
  unset cloud_image
  unset cloud_url
  lxcid=$((lxcid+1))
done <<'EOF'
archlinux-cloudimg-amd64,https://jenkins.linuxcontainers.org/job/image-archlinux/architecture=amd64%2Crelease=current%2Cvariant=cloud/lastCompletedBuild/artifact/rootfs.tar.xz
noble-server-cloudimg-amd64,https://jenkins.linuxcontainers.org/job/image-ubuntu/architecture=amd64%2Crelease=noble%2Cvariant=cloud/lastCompletedBuild/artifact/rootfs.tar.xz
debian-12-generic-amd64,https://jenkins.linuxcontainers.org/job/image-debian/architecture=amd64%2Crelease=bookworm%2Cvariant=cloud/lastCompletedBuild/artifact/rootfs.tar.xz
rocky-9-genericcloud-amd64,https://jenkins.linuxcontainers.org/job/image-rockylinux/architecture=amd64%2Crelease=9%2Cvariant=cloud/lastCompletedBuild/artifact/rootfs.tar.xz
EOF

# add cloud images as vm templates
vmid=$((990))
modprobe nbd max_part=63
while IFS=, read -r cloud_image cloud_url; do
  if [ -z "$cloud_image" ]; then
    continue
  fi
  pushd /var/lib/vz/template/cache
    echo ":: download $cloud_url"
    wget --progress=dot:mega -O "$cloud_image.qcow2" "$cloud_url"
    echo ":: create block device for $cloud_image.qcow2"
    qemu-nbd -c /dev/nbd0 "$cloud_image.qcow2"
    sleep 2
    echo ":: detect root partition in $cloud_image.qcow2"
    ROOT_PART=( $(lsblk -no PATH,PARTTYPENAME /dev/nbd0 | sed -e '/root\|linux filesystem/I!d' | head -n1) )
    if [ -z "${ROOT_PART[0]}" ]; then
      echo "!! error detecting root partition in $cloud_image.qcow2"
      qemu-nbd -d /dev/nbd0
      popd
      unset cloud_image
      unset cloud_url
      continue
    fi
    echo ":: mount root partition ${ROOT_PART[0]}"
    mount -o rw "${ROOT_PART[0]}" /mnt
    echo ":: modify root partition ${ROOT_PART[0]}"
    USERID=root
    USERHASH=$(openssl passwd -6 -salt abcxyz 'packer-build-passwd')
    sed -i 's/^'"$USERID"':[^:]*:/'"$USERID"':'"${USERHASH//\//\\/}"':/' /mnt/etc/shadow
    unset USERID
    unset USERHASH
    echo ":: unmount and unload $cloud_image.qcow2"
    umount /mnt
    qemu-nbd -d /dev/nbd0
    sleep 2
    echo ":: create vm template $vmid named $cloud_image"
    qm create $vmid --name "$cloud_image" --pool pool1 --machine q35 --cores 4 --memory 512 --boot order=virtio0 \
      --virtio0 "local:0,discard=on,snapshot=1,import-from=/var/lib/vz/template/cache/$cloud_image.qcow2" \
      --net0 virtio,bridge=vmbr0 --efidisk0 local:0,efitype=4m,pre-enrolled-keys=1 --tpmstate0 local:0,version=v2.0 \
      --serial0 socket
    qm template $vmid
  popd
  unset cloud_image
  unset cloud_url
  vmid=$((vmid+1))
done <<'EOF'
archlinux-cloudimg-amd64,https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2
noble-server-cloudimg-amd64,https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
debian-12-generic-amd64,https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
rocky-9-genericcloud-amd64,https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2
EOF

# reboot system
( ( sleep 5 && systemctl reboot ) & )

# cleanup
rm -- "${0}"
