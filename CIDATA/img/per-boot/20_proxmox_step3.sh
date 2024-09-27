#!/usr/bin/env bash

if ! [ -f /bin/apt ] || grep -q Ubuntu /proc/version; then
    ( ( sleep 1 && rm -- "${0}" ) & )
    exit 0
fi

# only after step 2 reboot
if [ -f "/var/lib/cloud/scripts/per-boot/30_proxmox_step2.sh" ]; then
    exit 0
fi

exec &> >(while IFS=$'\r' read -ra line; do [ -z "${line[@]}" ] && line=( '' ); echo -e "[$(cat /proc/uptime | cut -d' ' -f1)] ${line[-1]}" | tee -a /cidata_log /dev/ttyS0 > /dev/tty1; done)

# wait online
echo ":: wait for any interface to be online"
/usr/lib/systemd/systemd-networkd-wait-online --operational-state=routable --any

# install the main proxmox packages
LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt install proxmox-ve postfix open-iscsi chrony

# apply the new settings to grub
update-grub

# one bridge per interface, dhcp setup on first device
cnt=$((-1))
ip -j link show | jq -r '.[] | select(.link_type != "loopback" and (.ifname | startswith("vmbr") | not)) | .ifname' | while read -r line; do
cnt=$((cnt+1))
tee -a /etc/network/interfaces <<EOF

iface $line inet manual

auto vmbr$cnt
iface vmbr$cnt inet $(if [ $cnt -eq 0 ]; then echo "dhcp"; else echo "manual"; fi)
    bridge-ports $line
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
    $(if [ $cnt -eq 0 ]; then echo "post-up /usr/local/bin/ifroute.sh vmbr$cnt yes"; fi)
EOF
done

tee /etc/dhcp/dhclient-exit-hooks.d/99-ifroute.sh <<'EOF'
#!/usr/bin/env bash

case "${reason}" in BOUND|RENEW|REBIND|REBOOT)
  /usr/local/bin/ifroute.sh "${interface}"
  ;;
esac
EOF
chmod +x /etc/dhcp/dhclient-exit-hooks.d/99-ifroute.sh

tee /usr/local/bin/ifroute.sh <<'EOF'
#!/usr/bin/env bash

IFNAME="$1"
if [ -z "$IFNAME" ]; then
  echo 1>&2 "An interface name must be provided."
  exit 1
fi

if ! ip link show dev "$IFNAME" >/dev/null 2>&1; then
  echo 1>&2 "Interface with name '$IFNAME' not present."
  exit 2
fi

IFDEFAULT="$2"
case $IFDEFAULT in
  yes|YES|on|ON|1)
  IFDEFAULT='ON'
  ;;
  *)
  IFDEFAULT=''
  ;;
esac

if ! grep -q "$IFNAME" /etc/iproute2/rt_tables; then
  IFNUM=$(ip -j link show dev "$IFNAME" | jq '.[0].ifindex')
tee -a /etc/iproute2/rt_tables <<EOX
$IFNUM  $IFNAME
EOX
fi

ip route flush table "$IFNAME"

ip -j addr show dev "$IFNAME" | jq -r '[.[].addr_info[] | select(.scope == "global")] | .[0] | .local' | while read -r ipaddr; do
  [ -z "$ipaddr" ] && continue
  ip -j route show dev "$IFNAME" | jq -r '[.[] | select(.prefsrc == "'"$ipaddr"'")] | .[0] | .dst' | while read -r subnet; do
    [ -z "$subnet" ] && continue
    ip -j route show dev "$IFNAME" | jq -r '[.[].gateway | select(. != null)] | .[0]' | while read -r gateway; do
      [ -z "$gateway" ] && continue
      [ "null" == "$gateway" ] && continue
      IFNUM=$(ip -j link show dev "$IFNAME" | jq '.[0].ifindex')
      echo 1>&2 "[$IFNUM] $IFNAME: ip $ipaddr, subnet $subnet, gateway $gateway"
      ip route add "$subnet" dev "$IFNAME" src "$ipaddr" table "$IFNAME"
      # may be present already, added by the kernel
      ip route add "$subnet" dev "$IFNAME" src "$ipaddr" table main >/dev/zero 2>&1 || true
      ip route add default via "$gateway" dev "$IFNAME" table "$IFNAME"
      PRIO=$((1000 + $IFNUM))
      ip rule del from "$ipaddr"/32 table "$IFNAME" prio $PRIO >/dev/zero 2>&1 || true
      ip rule del to "$ipaddr"/32 table "$IFNAME" prio $PRIO >/dev/zero 2>&1 || true
      ip rule add from "$ipaddr"/32 table "$IFNAME" prio $PRIO
      ip rule add to "$ipaddr"/32 table "$IFNAME" prio $PRIO
    done
  done
done

if [ -n "$IFDEFAULT" ]; then
  echo 1>&2 "$IFNAME: default outbound route"
  IFNUM=$(ip -j link show dev "$IFNAME" | jq '.[0].ifindex')
  PRIO=$((2000 + $IFNUM))
  ip rule del from all table "$IFNAME" prio $PRIO >/dev/zero 2>&1 || true
  ip rule add from all table "$IFNAME" prio $PRIO
fi

ip route flush cache
EOF
chmod +x /usr/local/bin/ifroute.sh

# do not wait for online interfaces
systemctl mask systemd-networkd-wait-online
systemctl mask NetworkManager-wait-online

# open up the port for the proxmox webinterface
firewall-offline-cmd --zone=public --add-port=8006/tcp

# sync everything to disk
sync

# reboot system
( ( sleep 5 && systemctl reboot ) & )

# cleanup
rm -- "${0}"
