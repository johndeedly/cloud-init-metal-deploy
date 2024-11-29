#!/usr/bin/env bash

if ! [ -f /bin/pacman ]; then
    ( ( sleep 1 && rm -- "${0}" ) & )
    exit 0
fi

exec &> >(while IFS=$'\r' read -ra line; do [ -z "${line[@]}" ] && line=( '' ); TS=$(</proc/uptime); echo -e "[${TS% *}] ${line[-1]}" | tee -a /cidata_log > /dev/tty1; done)

# wait online
echo ":: wait for any interface to be online"
/usr/lib/systemd/systemd-networkd-wait-online --operational-state=routable --any

# gitlab container
mkdir -p /srv/gitlab/{config,logs,data}
tee /srv/gitlab/docker-compose.yml <<'EOF'
version: '3.6'
services:
  gitlab:
    image: gitlab/gitlab-ce
    container_name: gitlab
    restart: always
    hostname: 'gitlab.internal'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        # Add any other gitlab.rb configuration here, each on its own line
        external_url 'https://gitlab.internal'
        gitlab_rails['gitlab_shell_ssh_port'] = 2424
    ports:
      - '80:80'
      - '443:443'
      - '2424:22'
    volumes:
      - '/srv/gitlab/config:/etc/gitlab'
      - '/srv/gitlab/logs:/var/log/gitlab'
      - '/srv/gitlab/data:/var/opt/gitlab'
    shm_size: '256m'
EOF

pushd /srv/gitlab
docker-compose up --build --no-recreate --no-start
popd

# gitlab starter
mkdir -p /etc/systemd/system
tee /etc/systemd/system/gitlab-docker.service <<'EOF'
[Unit]
Description=Gitlab Docker Compose Application Service
Requires=docker.service
After=docker.service
StartLimitIntervalSec=60

[Service]
WorkingDirectory=/srv/gitlab
ExecStart=/bin/docker-compose up --no-recreate --attach-dependencies
ExecStop=/bin/docker-compose down
TimeoutStartSec=0
Restart=on-failure
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF
systemctl enable gitlab-docker

# open firewall
firewall-offline-cmd --zone=public --add-port=80/tcp
firewall-offline-cmd --zone=public --add-port=443/tcp
firewall-offline-cmd --zone=public --add-port=2424/tcp

# sync everything to disk
sync

# reboot system
( ( sleep 5 && systemctl reboot ) & )

# cleanup
rm -- "${0}"
