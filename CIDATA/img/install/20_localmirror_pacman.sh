#!/usr/bin/env bash

# remove line to enable build
exit 0
if ! [ -f /bin/pacman ]; then
    exit 0
fi

LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed expac nginx pacman-contrib

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

tee /etc/nginx/nginx.conf <<EOF
user http;
worker_processes auto;
worker_cpu_affinity auto;

events {
    multi_accept on;
    worker_connections 1024;
}

http {
    charset utf-8;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    server_tokens off;
    log_not_found off;
    types_hash_max_size 4096;
    client_max_body_size 16M;

    server {
        listen 8080;
        listen [::]:8080;
        server_name $(cat /etc/hostname);
        root /srv/http;
        location / {
            try_files \$uri \$uri/ =404;
            autoindex on;
        }
    }

    # MIME
    include mime.types;
    default_type application/octet-stream;

    # logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    # load configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

tee -a /etc/fstab <<EOF

overlay /srv/http overlay noauto,x-systemd.automount,lowerdir=/var/cache/pacman/pkg:/var/lib/pacman/sync 0 0
EOF

systemctl enable nginx.service pacsync.timer

firewall-offline-cmd --zone=public --add-port=8080/tcp
