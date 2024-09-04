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

# add cloud images as lxc and vm templates
lxcid=$((980))
vmid=$((990))
while IFS=, read -r cloud_image cloud_url; do
  if [ -z "$cloud_image" ]; then
    continue
  fi
  pushd /var/lib/vz/template/cache
    echo ":: download $cloud_url"
    wget --progress=dot:mega -O "$cloud_image.qcow2" "$cloud_url"
    echo ":: convert $cloud_image.qcow2 to $cloud_image.raw"
    qemu-img convert -O raw "$cloud_image.qcow2" "$cloud_image.raw"
    echo ":: detect root partition in $cloud_image.raw"
    losetup -P /dev/loop0 "$cloud_image.raw"
    sleep 1
    ROOT_PART=( $(lsblk -no PATH,PARTTYPENAME /dev/loop0 | sed -e '/root\|linux filesystem/I!d' | head -n1) )
    if [ -z "${ROOT_PART[0]}" ]; then
      echo "!! error detecting root partition in $cloud_image.raw"
      popd
      unset cloud_image
      unset cloud_url
      continue
    fi
    echo ":: mount root partition ${ROOT_PART[0]}"
    mount "${ROOT_PART[0]}" /mnt
    echo ":: build $cloud_image.tar.zst"
    find /mnt/ -printf "%P\n" | tar --zstd -cf "$cloud_image.tar.zst" --no-recursion -C /mnt/ -T -
    umount -l /mnt/
    sleep 1
    losetup -d /dev/loop0
    rm "$cloud_image.raw"
    echo ":: create container template $lxcid named $cloud_image"
    pct create $lxcid "local:vztmpl/$cloud_image.tar.zst" --hostname "$cloud_image" --pool pool1 --cores 4 --memory 512 --net0 name=eth0,bridge=vmbr0
    pct template $lxcid
    echo ":: create vm template $vmid named $cloud_image"
    qm create $vmid --name "$cloud_image" --pool pool1 --machine q35 --cores 4 --memory 512 --boot order=virtio0 --virtio0 "local:0,discard=on,snapshot=1,import-from=/var/lib/vz/template/cache/$cloud_image.qcow2" --net0 virtio,bridge=vmbr0
    qm template $vmid
  popd
  unset cloud_image
  unset cloud_url
  unset ROOT_PART
  lxcid=$((lxcid+1))
  vmid=$((vmid+1))
done <<'EOF'
archlinux-cloudimg-amd64,https://ftp.halifax.rwth-aachen.de/archlinux/images/latest/Arch-Linux-x86_64-cloudimg.qcow2
noble-server-cloudimg-amd64,https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
debian-12-generic-amd64,https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
rocky-9-genericcloud-amd64,https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2
EOF

# reboot system
( ( sleep 5 && systemctl reboot ) & )

# cleanup
rm -- "${0}"
