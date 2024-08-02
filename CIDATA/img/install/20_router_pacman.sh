#!/usr/bin/env bash

# remove line to enable build
#exit 0
if ! [ -f /bin/pacman ]; then
    exit 0
fi

LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed dnsmasq iptraf-ng ntp step-ca step-cli

DHCP_ADDITIONAL_SETUP=(
  "dhcp-option=option:dns-server,172.26.0.1\n"
  "dhcp-option=option6:dns-server,[2001:db8:7b:1::]\n"
  "dhcp-option=option:ntp-server,172.26.0.1\n"
  "dhcp-option=option6:ntp-server,[2001:db8:7b:1::]\n"
  "\n"
  "# Override the default route supplied by dnsmasq, which assumes the"
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
IPv4Forwarding=yes
IPv6Forwarding=yes
IPMasquerade=both
IPv6PrivacyExtensions=yes

[DHCPv4]
RouteMetric=10

[IPv6AcceptRA]
RouteMetric=10

[DHCPPrefixDelegation]
RouteMetric=10

[IPv6Prefix]
RouteMetric=10
EOF
tee /etc/systemd/network/20-internal-bridge.netdev <<EOF
[NetDev]
Name=br0
Kind=bridge
EOF
tee /etc/systemd/network/20-internal-bridge.network <<EOF
[Match]
Name=br0

[Network]
Address=172.26.0.1/15
Address=2001:db8:7b:1::/48
EOF
tee /etc/systemd/network/20-internal.network <<EOF
[Match]
Name=eth1

[Network]
Bridge=br0
EOF

# configure dnsmasq
sed -i '0,/^#\?bind-interfaces.*/s//bind-interfaces/' /etc/dnsmasq.conf
sed -i '0,/^#\?except-interface=.*/s//except-interface=eth0/' /etc/dnsmasq.conf
sed -i '0,/^#\?domain-needed.*/s//domain-needed/' /etc/dnsmasq.conf
sed -i '0,/^#\?bogus-priv.*/s//bogus-priv/' /etc/dnsmasq.conf
sed -i '0,/^#\?local=.*/s//local=\/internal\//' /etc/dnsmasq.conf
sed -i '0,/^#\?domain=.*/s//domain=internal/' /etc/dnsmasq.conf
sed -i '0,/^#\?dhcp-range=.*/s//dhcp-range=172.27.0.1,172.27.255.254,255.254.0.0,12h/' /etc/dnsmasq.conf
sed -i '0,/^#\?dhcp-range=.*::.*/s//dhcp-range=2001:db8:7b::1,2001:db8:7b::ffff,64,12h/' /etc/dnsmasq.conf
sed -i '0,/^# Override the default route.*/s//'"${DHCP_ADDITIONAL_SETUP[*]}"'/' /etc/dnsmasq.conf
sed -i '0,/^#\?enable-ra.*/s//enable-ra/' /etc/dnsmasq.conf
sed -i '0,/^#\?log-dhcp.*/s//log-dhcp/' /etc/dnsmasq.conf
sed -i '0,/^#\?log-queries.*/s//log-queries/' /etc/dnsmasq.conf

# configure ntp
tee /etc/ntp.conf <<EOF
server 0.de.pool.ntp.org iburst
server 1.de.pool.ntp.org iburst
server 2.de.pool.ntp.org iburst
server 3.de.pool.ntp.org iburst
tos orphan 15

restrict default kod limited nomodify notrap nopeer noquery
restrict -6 default kod limited nomodify notrap nopeer noquery

restrict 127.0.0.1
restrict -6 ::1  

driftfile /var/lib/ntp/ntp.drift
logfile /var/log/ntp.log
EOF
tee /etc/systemd/system/ntpd.timer <<EOF
[Timer]
OnBootSec=30

[Install]
WantedBy=multi-user.target
EOF
mkdir -p /etc/systemd/system/ntpd.service.d
tee /etc/systemd/system/ntpd.service.d/override.conf <<EOF
[Service]
Restart=on-failure
RestartSec=23
EOF

# the router is it's own acme protocol certificate authority
useradd -d /srv/step step
install -d -m 0755 -o step -g step /srv/step
install -d -m 0755 -o step -g step /srv/step/.step
install -d -m 0755 -o step -g step /var/log/step-ca
tee /etc/systemd/system/step-ca.service <<EOF
[Unit]
Description=step-ca
After=syslog.target network.target

[Service]
User=step
Group=step
StandardInput=null
StandardOutput=journal
StandardError=journal
ExecStart=/bin/sh -c '/bin/step-ca /srv/step/.step/config/ca.json --password-file=/srv/step/.step/pwd'
Type=simple
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

openssl rand -base64 36 | tee /srv/step/.step/pwd
chown step:step /srv/step/.step/pwd
chmod 400 /srv/step/.step/pwd

su -s /bin/bash - step <<EOS
step-cli ca init --deployment-type=standalone --name=locally --dns=172.26.0.1 --dns=2001:db8:7b:1:: --dns=router.locally --address=:8443 --provisioner=step-ca@router.locally --password-file=/srv/step/.step/pwd --acme
sed -i '0,/"name": "acme".*/s//"name": "acme",\n\t\t\t\t"claims": {\n\t\t\t\t\t"maxTLSCertDuration": "2160h",\n\t\t\t\t\t"defaultTLSCertDuration": "2160h"\n\t\t\t\t}/' /srv/step/.step/config/ca.json
EOS

# Enable all configured services
systemctl enable dnsmasq ntpd.timer step-ca

# configure the firewall
firewall-offline-cmd --zone=public --add-service=dhcp
firewall-offline-cmd --zone=public --add-service=proxy-dhcp
firewall-offline-cmd --zone=public --add-service=dhcpv6
firewall-offline-cmd --zone=public --add-service=dns
firewall-offline-cmd --zone=public --add-service=ntp
firewall-offline-cmd --zone=public --add-port=8443/tcp
