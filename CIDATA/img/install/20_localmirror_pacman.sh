#!/usr/bin/env bash

# remove line to enable build
exit 0
if ! [ -f /bin/pacman ]; then
    exit 0
fi

LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed expac

tee /usr/local/bin/pacsync.sh <<'EOF'
#!/usr/bin/env bash

if [ -f /var/lib/pacman/db.lck ]; then
    killall -SIGINT pacman
    rm /var/lib/pacman/db.lck || true
fi

/usr/bin/pacman -Sy --noconfirm
/usr/bin/pacman -Fy --noconfirm
/usr/bin/expac -Ss '%r/%n' | xargs pacman -Swdd --noconfirm
/usr/bin/paccache -r
EOF
chmod +x /usr/local/bin/pacsync.sh

tee /etc/systemd/system/pacsync.service <<'EOF'
[Unit]
Description=Download up-to-date packages
StartLimitIntervalSec=30s
StartLimitBurst=5
After=network.target

[Service]
StandardInput=null
StandardOutput=journal
StandardError=journal
Restart=on-failure
RestartSec=2s
WorkingDirectory=/var/cache/pacman/pkg
ExecStart=/usr/local/bin/pacsync.sh
EOF

tee /etc/systemd/system/pacsync.timer <<EOF
[Unit]
Description=Schedule up-to-date packages

[Timer]
OnBootSec=15min
OnCalendar=Tue,Thu,Sat 01:17

[Install]
WantedBy=multi-user.target
EOF

tee /etc/systemd/system/darkhttpd.service <<EOF
[Unit]
Description=Run dualstack webserver for local mirror
StartLimitIntervalSec=30s
StartLimitBurst=5
After=network.target

[Service]
StandardInput=null
StandardOutput=journal
StandardError=journal
Restart=on-failure
RestartSec=2s
WorkingDirectory=/srv/http
ExecStart=/usr/bin/darkhttpd /srv/http --ipv6 --addr '::' --port 8080 --mimetypes /etc/conf.d/mimetypes

[Install]
WantedBy=multi-user.target
EOF

tee -a /etc/fstab <<EOF

overlay /srv/http overlay noauto,x-systemd.automount,lowerdir=/var/cache/pacman/pkg:/var/lib/pacman/sync 0 0
EOF

LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed darkhttpd pacman-contrib

systemctl enable darkhttpd.service pacsync.timer

firewall-offline-cmd --zone=public --add-port=8080/tcp
