#!/usr/bin/env bash

LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed syslinux darkhttpd dnsmasq

DHCP_ADDITIONAL_SETUP=(
  "dhcp-option=option:dns-server,192.168.123.128\n"
  "dhcp-option=option6:dns-server,[2001:db8:7b:1::]\n"
  "dhcp-option=option:ntp-server,192.168.123.128\n"
  "dhcp-option=option6:ntp-server,[2001:db8:7b:1::]\n"
  "\n"
  "# Override the default route supplied by dnsmasq, which assumes the"
)

PXESETUP=(
  "dhcp-match=set:efi-x86_64,option:client-arch,7\n"
  "dhcp-match=set:efi-x86_64,option:client-arch,9\n"
  "dhcp-match=set:efi-x86,option:client-arch,6\n"
  "dhcp-match=set:bios,option:client-arch,0\n"

  "dhcp-boot=tag:efi-x86_64,efi64\/syslinux.efi\n"
  "dhcp-boot=tag:efi-x86,efi32\/syslinux.efi\n"
  "dhcp-boot=tag:bios,bios\/lpxelinux.0"
)

DHCP_209_SETUP=(
  "dhcp-option-force=tag:efi-x86_64,209,pxelinux.cfg\/default\n"
  "dhcp-option-force=tag:efi-x86,209,pxelinux.cfg\/default\n"
  "dhcp-option-force=tag:bios,209,pxelinux.cfg\/default"
)

DHCP_210_SETUP=(
  "dhcp-option-force=tag:efi-x86_64,210,efi64\/\n"
  "dhcp-option-force=tag:efi-x86,210,efi32\/\n"
  "dhcp-option-force=tag:bios,210,bios\/"
)

# keep all interface names
tee /etc/systemd/network/10-all-keep-names.link <<EOF
[Match]
OriginalName=*

[Link]
NamePolicy=keep
EOF

# configure internal and external network
rm /etc/systemd/network/20-wired.network
tee /etc/systemd/network/20-external.network <<EOF
[Match]
Name=eth0

[Network]
DHCP=yes
MulticastDNS=yes

[DHCPv4]
RouteMetric=10

[IPv6AcceptRA]
RouteMetric=10

[DHCPPrefixDelegation]
RouteMetric=10

[IPv6Prefix]
RouteMetric=10
EOF
tee /etc/systemd/network/20-internal.network <<EOF
[Match]
Name=eth1

[Network]
Address=192.168.123.128/24
Address=2001:db8:7b:1::/48
EOF

# disable dns
sed -i '0,/^#\?port.*/s//port=0/' /etc/dnsmasq.conf
tee /etc/default/dnsmasq <<EOF
DNSMASQ_OPTS="-p0"
EOF

# configure dnsmasq
sed -i '0,/^#\?domain-needed.*/s//domain-needed/' /etc/dnsmasq.conf
sed -i '0,/^#\?bogus-priv.*/s//bogus-priv/' /etc/dnsmasq.conf
sed -i '0,/^#\?local=.*/s//local=\/locally\//' /etc/dnsmasq.conf
sed -i '0,/^#\?domain=.*/s//domain=locally/' /etc/dnsmasq.conf
sed -i '0,/^#\?dhcp-range=.*/s//dhcp-range=192.168.123.1,192.168.123.127,255.255.255.0,12h/' /etc/dnsmasq.conf
sed -i '0,/^#\?dhcp-range=.*::.*/s//dhcp-range=2001:db8:7b::1,2001:db8:7b::ffff,64,12h/' /etc/dnsmasq.conf
sed -i '0,/^# Override the default route.*/s//'"${DHCP_ADDITIONAL_SETUP[*]}"'/' /etc/dnsmasq.conf
sed -i '0,/^#\?enable-ra.*/s//enable-ra/' /etc/dnsmasq.conf
sed -i '0,/^#\?enable-tftp.*/s//enable-tftp/' /etc/dnsmasq.conf
sed -i '0,/^#\?tftp-root=.*/s//tftp-root=\/srv\/tftp/' /etc/dnsmasq.conf
sed -i '0,/^#\?log-dhcp.*/s//log-dhcp/' /etc/dnsmasq.conf
sed -i '0,/^#\?log-queries.*/s//log-queries/' /etc/dnsmasq.conf
sed -i '0,/^#\?dhcp-boot=.*/s//'"${PXESETUP[*]}"'/' /etc/dnsmasq.conf
sed -i '0,/^#\?dhcp-option-force=209.*/s//'"${DHCP_209_SETUP[*]}"'/' /etc/dnsmasq.conf
sed -i '0,/^#\?dhcp-option-force=210.*/s//'"${DHCP_210_SETUP[*]}"'/' /etc/dnsmasq.conf

# Configure tftp
rm -r /srv/tftp/*
cp -ar /usr/lib/syslinux/bios /srv/tftp/
cp -ar /usr/lib/syslinux/efi32 /srv/tftp/
cp -ar /usr/lib/syslinux/efi64 /srv/tftp/
mkdir -p /srv/tftp/{bios,efi32,efi64}/pxelinux.cfg

# Configure http
mkdir -p /srv/pxe/arch/x86_64
# altering the default darkhttpd service file
cp /usr/lib/systemd/system/darkhttpd.service /etc/systemd/system/
sed -i 's|/srv/http|/srv/pxe|g' /etc/systemd/system/darkhttpd.service

# Change default access rights
chown -R root:root /srv/tftp /srv/pxe
setfacl -P -R -d -m u::rwX,g::rX,o::rX /srv/tftp
setfacl -P -R -m u::rwX,g::rX,o::rX /srv/tftp
setfacl -P -R -d -m u::rwX,g::rX,o::rX /srv/pxe
setfacl -P -R -m u::rwX,g::rX,o::rX /srv/pxe

# Enable all configured services
systemctl enable dnsmasq darkhttpd

# configure the firewall
firewall-offline-cmd --zone=public --add-service=dhcp
firewall-offline-cmd --zone=public --add-service=proxy-dhcp
firewall-offline-cmd --zone=public --add-service=dhcpv6
firewall-offline-cmd --zone=public --add-service=tftp
firewall-offline-cmd --zone=public --add-service=http
