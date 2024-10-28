#!/usr/bin/env bash

LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed expac nginx pacman-contrib

# prepare mirror cache dir
mkdir -p /var/cache/pacman/mirror

# enable multilib
if grep -q "\[multilib\]" /etc/pacman.conf; then
    sed -i '/^#\?\[multilib\]$/{N;s/^#\?\[multilib\]\n#\?Include.*/[multilib]\nInclude = \/etc\/pacman.d\/mirrorlist/;}' /etc/pacman.conf
else
    tee -a /etc/pacman.conf <<EOS

[multilib]
Include = /etc/pacman.d/mirrorlist
EOS
fi
LC_ALL=C yes | LC_ALL=C pacman -Sy --noconfirm

tee /usr/local/bin/pacsync.sh <<'EOF'
#!/usr/bin/env bash

if [ -f /var/lib/pacman/db.lck ]; then
    killall -SIGINT pacman
    rm /var/lib/pacman/db.lck || true
fi

/usr/bin/pacman -Sy --noconfirm
/usr/bin/pacman -Fy --noconfirm
while read -r repo; do
    mkdir -p "/var/cache/pacman/mirror/$repo"
    ln -s "/var/lib/pacman/sync/$repo.db" "/var/cache/pacman/mirror/$repo/$repo.db" || true
    ln -s "/var/lib/pacman/sync/$repo.files" "/var/cache/pacman/mirror/$repo/$repo.files" || true
    /usr/bin/expac -Ss '%r/%n' | grep "^$repo/" | xargs pacman -Swddp --logfile "/dev/null" --cachedir "/dev/null" | while read -r line; do
      echo "$line"
      echo "$line".sig
    done > /tmp/mirror_url_list.txt
    # continue unfinished downloads and skip already downloaded ones, use timestamps,
    # download to target path, load download list from file, show progress in larger size steps per dot
    wget -c -N -P "/var/cache/pacman/mirror/$repo" -i /tmp/mirror_url_list.txt --progress=dot:mega
    rm /tmp/mirror_url_list.txt
done <<EOX
core
extra
multilib
chaotic-aur
EOX

ARCHIVE_BASE=$(date +%Y/%m/01)
mkdir -p /var/cache/pacman/mirror/month/{core,extra,multilib,iso}
tee /tmp/mirror_url_list.txt <<EOS
https://archive.archlinux.org/repos/${ARCHIVE_BASE}/core/os/x86_64/
EOS
# continue unfinished downloads and skip already downloaded ones, use timestamps, skip first five path elements,
# download to target path, load download list from file, show progress in larger size steps per dot
wget -c -N -r -np -R "index.html*" -e robots=off -P /var/cache/pacman/mirror/month/core -i /tmp/mirror_url_list.txt --progress=dot:mega
tee /tmp/mirror_url_list.txt <<EOS
https://archive.archlinux.org/repos/${ARCHIVE_BASE}/extra/os/x86_64/
EOS
# continue unfinished downloads and skip already downloaded ones, use timestamps, skip first five path elements,
# download to target path, load download list from file, show progress in larger size steps per dot
wget -c -N -r -np -R "index.html*" -e robots=off -P /var/cache/pacman/mirror/month/extra -i /tmp/mirror_url_list.txt --progress=dot:mega
tee /tmp/mirror_url_list.txt <<EOS
https://archive.archlinux.org/repos/${ARCHIVE_BASE}/multilib/os/x86_64/
EOS
# continue unfinished downloads and skip already downloaded ones, use timestamps, skip first five path elements,
# download to target path, load download list from file, show progress in larger size steps per dot
wget -c -N -r -np -R "index.html*" -e robots=off -P /var/cache/pacman/mirror/month/multilib -i /tmp/mirror_url_list.txt --progress=dot:mega
ARCHIVE_BASE=$(date +%Y.%m.01)
tee /tmp/mirror_url_list.txt <<EOS
https://archive.archlinux.org/iso/${ARCHIVE_BASE}/archlinux-x86_64.iso
https://archive.archlinux.org/iso/${ARCHIVE_BASE}/archlinux-x86_64.iso.sig
https://archive.archlinux.org/iso/${ARCHIVE_BASE}/arch/boot/x86_64/initramfs-linux.img
https://archive.archlinux.org/iso/${ARCHIVE_BASE}/arch/boot/x86_64/initramfs-linux.img.ipxe.sig
https://archive.archlinux.org/iso/${ARCHIVE_BASE}/arch/boot/x86_64/vmlinuz-linux
https://archive.archlinux.org/iso/${ARCHIVE_BASE}/arch/boot/x86_64/vmlinuz-linux.ipxe.sig
https://archive.archlinux.org/iso/${ARCHIVE_BASE}/arch/x86_64/airootfs.sfs
https://archive.archlinux.org/iso/${ARCHIVE_BASE}/arch/x86_64/airootfs.sfs.cms.sig
https://archive.archlinux.org/iso/${ARCHIVE_BASE}/arch/x86_64/airootfs.sha512
EOS
# continue unfinished downloads and skip already downloaded ones, use timestamps, skip first five path elements,
# download to target path, load download list from file, show progress in larger size steps per dot
wget -c -N -P /var/cache/pacman/mirror/month/iso -i /tmp/mirror_url_list.txt --progress=dot:mega
rm /tmp/mirror_url_list.txt

# remove older package versions (sort -r: newest first) when packages count is larger than 3 (cnt[key]>3)
find "/var/cache/pacman/mirror" -name '*.pkg.tar.zst' -printf "%P %T+\n" | sort -r -t' ' -k2,2 | awk -F '-' '{
  key=$1
  for (i=2;i<NF-4;i++){key=sprintf("%s-%s",key,$i)}
  cnt[key]++
  if(cnt[key]>3){
    out=$1
    for (i=2;i<=NF;i++){out=sprintf("%s-%s",out,$i)}
    printf "%i %s\n",cnt[key],out
  }
}' | while read -r nr pkg ctm; do
  echo "removing /var/cache/pacman/mirror/$pkg"
  rm "/var/cache/pacman/mirror/$pkg"
  echo "removing /var/cache/pacman/mirror/$pkg".sig
  rm "/var/cache/pacman/mirror/$pkg".sig
done
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

overlay /srv/http overlay noauto,x-systemd.automount,lowerdir=/var/cache/pacman/mirror:/var/empty 0 0
EOF

systemctl enable nginx.service pacsync.timer

firewall-offline-cmd --zone=public --add-port=8080/tcp
