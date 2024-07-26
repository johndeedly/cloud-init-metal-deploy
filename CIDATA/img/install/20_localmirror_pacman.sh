#!/usr/bin/env bash

# remove line to enable build
exit 0
if ! [ -f /bin/pacman ]; then
    exit 0
fi

mkdir -p /srv/pacmirror/files

tee /usr/local/bin/mirrorsync.sh <<EOF
#!/usr/bin/env bash

SYNC_HOME="/srv/pacmirror"
SYNC_FILES="\$SYNC_HOME/files"
SYNC_REPO=(core extra multilib iso)
SERVER_ARR="\$(curl -S 'https://archlinux.org/mirrors/status/tier/1/json/' | jq -r '[.urls[] | select(.protocol == "rsync" and (.country_code == "AT" or .country_code == "BE" or .country_code == "DK" or .country_code == "FI" or .country_code == "FR" or .country_code == "DE" or .country_code == "IT" or .country_code == "NL" or .country_code == "NO" or .country_code == "PL" or .country_code == "ES" or .country_code == "SE" or .country_code == "CH" or .country_code == "GB") and .active)]')"
SERVER_ARR_LEN="\$(echo -en \$SERVER_ARR | jq '. | length')"
SERVER_SEL="\$(shuf -i1-\$SERVER_ARR_LEN -n1)"
SYNC_SERVER="\$(echo -en \$SERVER_ARR | jq -r ".[\$SERVER_SEL].url")"

if [ ! -d "\$SYNC_FILES" ]; then
  mkdir -p "\$SYNC_FILES"
fi

echo ">> \$SERVER_ARR_LEN tier 1 servers"
echo ">> choosing mirror \$SYNC_SERVER"

for repo in \${SYNC_REPO[@]}; do
  repo=\$(echo "\$repo" | tr [:upper:] [:lower:])
  echo ">> Syncing \$repo to \$SYNC_FILES/\$repo"
  rsync -rptlv --delete-after --safe-links --copy-links --delay-updates "\$SYNC_SERVER/\$repo" "\$SYNC_FILES/"
  echo ">> Syncing \$repo done."
  sleep 5
done
EOF
chmod +x /usr/local/bin/mirrorsync.sh

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
WorkingDirectory=/srv/pacmirror/files
ExecStart=/usr/bin/darkhttpd /srv/pacmirror/files --ipv6 --addr '::' --port 8080 --mimetypes /etc/conf.d/mimetypes

[Install]
WantedBy=multi-user.target
EOF

tee /etc/systemd/system/pacmirror.timer <<EOF
[Unit]
Description=Run mirrorsync daily and on boot

[Timer]
OnBootSec=15min
OnUnitInactiveSec=3h 57min

[Install]
WantedBy=multi-user.target
EOF

tee /etc/systemd/system/pacmirror.service <<EOF
[Unit]
Description=Local mirror sync
StartLimitIntervalSec=30s
StartLimitBurst=5
After=network.target

[Service]
StandardInput=null
StandardOutput=journal
StandardError=journal
Restart=on-failure
RestartSec=2s
WorkingDirectory=/srv/pacmirror
ExecStart=/usr/local/bin/mirrorsync.sh

[Install]
WantedBy=multi-user.target
EOF

LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed darkhttpd

systemctl enable darkhttpd.service pacmirror.timer

firewall-offline-cmd --zone=public --add-port=8080/tcp
