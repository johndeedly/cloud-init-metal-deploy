#!/usr/bin/env bash

LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed net-tools syslinux dnsmasq iptraf-ng ntp step-ca step-cli darkhttpd nfs-utils

DHCP_ADDITIONAL_SETUP=(
  "dhcp-option=option:dns-server,172.26.0.1\n"
  "dhcp-option=option6:dns-server,[fdd5:a799:9326:171d::1]\n"
  "dhcp-option=option:ntp-server,172.26.0.1\n"
  "dhcp-option=option6:ntp-server,[fdd5:a799:9326:171d::1]\n"
  "\n"
  "# Override the default route supplied by dnsmasq, which assumes the"
)

DHCP_RANGES=(
  "dhcp-range=172.27.0.1,172.27.255.254,255.254.0.0,12h\n"
  "dhcp-range=::1,::ffff,constructor:lan0,ra-names,64,12h\n"
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

# eth0 is bridged to macvlan device wan0
tee /etc/systemd/network/15-eth0.network <<EOF
[Match]
Name=eth0

[Network]
MACVLAN=wan0
LinkLocalAddressing=no
LLDP=no
EmitLLDP=no
IPv6AcceptRA=no
IPv6SendRA=no
EOF

# eth1 is bridged to macvlan device lan0
tee /etc/systemd/network/15-eth1.network <<EOF
[Match]
Name=eth1

[Network]
MACVLAN=lan0
LinkLocalAddressing=no
LLDP=no
EmitLLDP=no
IPv6AcceptRA=no
IPv6SendRA=no
EOF

# define virtual devices
tee /etc/systemd/network/20-wan0-bridge.netdev <<EOF
[NetDev]
Name=wan0
Kind=macvlan

[MACVLAN]
Mode=private
EOF
tee /etc/systemd/network/20-lan0-bridge.netdev <<EOF
[NetDev]
Name=lan0
Kind=macvlan

[MACVLAN]
Mode=private
EOF

# configure wan0 and lan0
tee /etc/systemd/network/25-wan0.network <<EOF
[Match]
Name=wan0

[Network]
DHCP=yes
MulticastDNS=yes
DNSOverTLS=opportunistic
DNSSEC=allow-downgrade
IPv4Forwarding=yes
IPv6Forwarding=yes
IPMasquerade=both

[DHCPv4]
RouteMetric=10

[IPv6AcceptRA]
RouteMetric=10

[DHCPPrefixDelegation]
RouteMetric=10

[IPv6Prefix]
RouteMetric=10
EOF
tee /etc/systemd/network/25-lan0.network <<EOF
[Match]
Name=lan0

[Network]
Address=172.26.0.1/15
Address=fdd5:a799:9326:171d::1/64
EOF

# configure dnsmasq
sed -i '0,/^#\?bind-interfaces.*/s//bind-interfaces/' /etc/dnsmasq.conf
sed -i '0,/^#\?except-interface=.*/s//except-interface=eth0\nexcept-interface=wan0/' /etc/dnsmasq.conf
sed -i '0,/^#\?domain-needed.*/s//domain-needed/' /etc/dnsmasq.conf
sed -i '0,/^#\?bogus-priv.*/s//bogus-priv/' /etc/dnsmasq.conf
sed -i '0,/^#\?local=.*/s//local=\/internal\//' /etc/dnsmasq.conf
sed -i '0,/^#\?domain=.*/s//domain=internal/' /etc/dnsmasq.conf
sed -i '0,/^#\?dhcp-range=.*/s//'"${DHCP_RANGES[*]}"'/' /etc/dnsmasq.conf
sed -i '0,/^# Override the default route.*/s//'"${DHCP_ADDITIONAL_SETUP[*]}"'/' /etc/dnsmasq.conf
sed -i '0,/^#\?enable-ra.*/s//enable-ra/' /etc/dnsmasq.conf
sed -i '0,/^#\?enable-tftp.*/s//enable-tftp/' /etc/dnsmasq.conf
sed -i '0,/^#\?tftp-root=.*/s//tftp-root=\/srv\/tftp/' /etc/dnsmasq.conf
sed -i '0,/^#\?log-dhcp.*/s//log-dhcp/' /etc/dnsmasq.conf
sed -i '0,/^#\?log-queries.*/s//log-queries/' /etc/dnsmasq.conf
sed -i '0,/^#\?dhcp-boot=.*/s//'"${PXESETUP[*]}"'/' /etc/dnsmasq.conf
sed -i '0,/^#\?dhcp-option-force=209.*/s//'"${DHCP_209_SETUP[*]}"'/' /etc/dnsmasq.conf
sed -i '0,/^#\?dhcp-option-force=210.*/s//'"${DHCP_210_SETUP[*]}"'/' /etc/dnsmasq.conf

# configure tftp
mkdir -p /srv/tftp/{bios,efi32,efi64}/pxelinux.cfg
rsync -av --chown=root:root --chmod=Du=rwx,Dg=rx,Do=rx,Fu=rw,Fg=r,Fo=r /usr/lib/syslinux/bios/ /srv/tftp/bios/
rsync -av --chown=root:root --chmod=Du=rwx,Dg=rx,Do=rx,Fu=rw,Fg=r,Fo=r /usr/lib/syslinux/efi32/ /srv/tftp/efi32/
rsync -av --chown=root:root --chmod=Du=rwx,Dg=rx,Do=rx,Fu=rw,Fg=r,Fo=r /usr/lib/syslinux/efi64/ /srv/tftp/efi64/
tee /srv/tftp/{bios,efi32,efi64}/pxelinux.cfg/default <<EOF
$(</cidata/install/pxe/pxelinux.cfg.default)
EOF

# configure http
mkdir -p /srv/http/arch/x86_64
mkdir -p /etc/systemd/system/darkhttpd.service.d
tee /etc/systemd/system/darkhttpd.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/darkhttpd /srv/http --ipv6 --addr '::' --port 80 --uid http --gid http --chroot --no-listing --mimetypes /etc/conf.d/mimetypes
EOF
systemctl enable darkhttpd.service

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
step-cli ca init --deployment-type=standalone --name=internal --dns=172.26.0.1 --dns=fdd5:a799:9326:171d::1 --dns=172.28.0.1 --dns=fd97:6274:3c67:7974::1 --dns=router.internal --dns=gateway.internal --address=:8443 --provisioner=step-ca@router.internal --password-file=/srv/step/.step/pwd --acme --ssh
sed -i '0,/"name": "acme".*/s//"name": "acme",\n\t\t\t\t"claims": {\n\t\t\t\t\t"maxTLSCertDuration": "2160h",\n\t\t\t\t\t"defaultTLSCertDuration": "2160h"\n\t\t\t\t}/' /srv/step/.step/config/ca.json
EOS

# update hosts file on startup
tee /usr/local/bin/hosts-calc <<'EOS'
#!/usr/bin/env bash

# Set hostname in etc/hosts
FQDNAME=$(cat /etc/hostname)
HOSTNAME=${FQDNAME%%.*}
tee /tmp/hosts_columns <<EOF
# IPv4/v6|FQDN|HOSTNAME
EOF
ip -f inet addr | awk '/inet / {print $2}' | cut -d'/' -f1 | while read -r PUB_IP_ADDR; do
tee -a /tmp/hosts_columns <<EOF
$PUB_IP_ADDR|$FQDNAME|$HOSTNAME
$PUB_IP_ADDR|router.internal|router
$PUB_IP_ADDR|gateway.internal|gateway
EOF
done
ip -f inet6 addr | awk '/inet6 / {print $2}' | cut -d'/' -f1 | while read -r PUB_IP_ADDR; do
tee -a /tmp/hosts_columns <<EOF
$PUB_IP_ADDR|$FQDNAME|$HOSTNAME
$PUB_IP_ADDR|router.internal|router
$PUB_IP_ADDR|gateway.internal|gateway
EOF
done
tee /etc/hosts <<EOF
# Static table lookup for hostnames.
# See hosts(5) for details.

# https://www.icann.org/en/public-comment/proceeding/proposed-top-level-domain-string-for-private-use-24-01-2024
$(column /tmp/hosts_columns -t -s '|')
EOF
rm /tmp/hosts_columns
EOS
chmod +x /usr/local/bin/hosts-calc
tee /etc/systemd/system/hosts-calc.service <<EOF
[Unit]
Description=Generate hosts file on startup
Wants=network.target
After=network.target

[Service]
ExecStartPre=/usr/lib/systemd/systemd-networkd-wait-online --operational-state=routable --any
ExecStart=/usr/local/bin/hosts-calc

[Install]
WantedBy=multi-user.target
EOF

# configure nfs
# https://www.baeldung.com/linux/firewalld-nfs-connections-settings
mkdir -p /srv/pxe/arch/x86_64
sed -i '0,/^\[mountd\].*/s//[mountd]\nport=20048/' /etc/nfs.conf
sed -i '0,/^\[lockd\].*/s//[lockd]\nport=32767\nudp-port=32767/' /etc/nfs.conf
sed -i '0,/^\[statd\].*/s//[statd]\nport=32765/' /etc/nfs.conf
sed -i '0,/^\[nfsd\].*/s//[nfsd]\nthreads=16/' /etc/nfs.conf

tee /etc/exports <<EOF
/srv        127.0.0.0/8(ro,no_root_squash,no_subtree_check,fsid=0,crossmnt)
/srv        172.26.0.0/15(ro,no_root_squash,no_subtree_check,fsid=0,crossmnt)
/srv        ::1/128(ro,no_root_squash,no_subtree_check,fsid=0,crossmnt)
/srv        fdd5:a799:9326:171d::/64(ro,no_root_squash,no_subtree_check,fsid=0,crossmnt)
/srv/pxe    127.0.0.0/8(ro,no_root_squash,no_subtree_check)
/srv/pxe    172.26.0.0/15(ro,no_root_squash,no_subtree_check)
/srv/pxe    ::1/128(ro,no_root_squash,no_subtree_check)
/srv/pxe    fdd5:a799:9326:171d::/64(ro,no_root_squash,no_subtree_check)
EOF

# Enable all configured services
systemctl enable dnsmasq ntpd.timer step-ca hosts-calc nfs-server rpc-statd

# configure the firewall
firewall-offline-cmd --zone=public --add-service=dhcp
firewall-offline-cmd --zone=public --add-service=proxy-dhcp
firewall-offline-cmd --zone=public --add-service=dhcpv6
firewall-offline-cmd --zone=public --add-service=dns
firewall-offline-cmd --zone=public --add-service=ntp
firewall-offline-cmd --zone=public --add-service=tftp
firewall-offline-cmd --zone=public --add-service=http
firewall-offline-cmd --zone=public --add-port=8443/tcp
firewall-offline-cmd --zone=public --add-service=nfs
firewall-offline-cmd --zone=public --add-service=rpc-bind
firewall-offline-cmd --zone=public --add-service=mountd
firewall-offline-cmd --zone=public --add-port=32767/tcp
firewall-offline-cmd --zone=public --add-port=32767/udp
firewall-offline-cmd --zone=public --add-port=32765/tcp
firewall-offline-cmd --zone=public --add-port=32765/udp

# disable network config in cloud init
tee /etc/cloud/cloud.cfg.d/99-custom-networking.cfg <<EOF
network: {config: disabled}
EOF
find /etc/systemd/network -name "05-wired.network" -print -delete
find /etc/systemd/network -name "10-cloud-init*.network" -print -delete
