#!/usr/bin/env bash

if ! [ -f /bin/apt ] || grep -q Ubuntu /proc/version; then
    ( ( sleep 1 && rm -- "${0}" ) & )
    exit 0
fi

# only after step 3 reboot
if [ -f "/var/lib/cloud/scripts/per-boot/20_proxmox_step3.sh" ]; then
    exit 0
fi

exec 2>&1 &> >(while read -r line; do echo -e "[$(cat /proc/uptime | cut -d' ' -f1)] $line" | tee -a /cidata_log > /dev/tty1; done)

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

# add local users to group admins
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
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up echo 1 > /proc/sys/net/ipv4/conf/vmbr0/proxy_arp
EOF
  fi
  pveum acl modify "/sdn/zones/localnetwork/$brname" --roles PVESDNUser -users "$username" -propagate 1 || true
done
ifreload -a

# removes the nagging "subscription missing" popup on login (no permanent solution)
sed -Ezi 's/(function\(orig_cmd\) \{)/\1\n\torig_cmd\(\);\n\treturn;/g' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# reboot system
( ( sleep 5 && systemctl reboot ) & )

# cleanup
rm -- "${0}"
