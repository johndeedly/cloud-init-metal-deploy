#!/usr/bin/env bash

# remove line to enable build
exit 0
if ! [ -f /bin/apt ]; then
    exit 0
fi

tee /usr/local/bin/aptsync.sh <<'EOF'
#!/usr/bin/env bash

LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt -y update
/bin/apt list 2>/dev/null | tail -n +2 | cut -d' ' -f1 | xargs /bin/apt download --print-uris 2>/dev/null | cut -d' ' -f1 | tr -d "'" > /tmp/mirror_url_list.txt
wget -c -P /var/cache/apt/archives -i /tmp/mirror_url_list.txt --progress=dot:mega
find /var/cache/apt/archives -name '*.deb' | cut -d'_' -f1 | sort -u | while read -r pkg; do
  pkg_files=( $(ls -t "$pkg"_*.deb) )
  nr=${#pkg_files[@]}
  if ((nr > 1)); then
    unset pkg_files[0]
    rm "${pkg_files[@]}"
  fi
done
EOF
chmod +x /usr/local/bin/aptsync.sh

tee /etc/systemd/system/aptsync.service <<'EOF'
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
WorkingDirectory=/var/cache/apt/archives
ExecStart=/usr/local/bin/aptsync.sh
EOF

tee /etc/systemd/system/aptsync.timer <<EOF
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

overlay /srv/http overlay noauto,x-systemd.automount,lowerdir=/var/cache/apt/archives 0 0
EOF

LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt -y install nginx

systemctl enable nginx.service aptsync.timer

firewall-offline-cmd --zone=public --add-port=8080/tcp
