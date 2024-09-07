#!/usr/bin/env bash

# ⚠️ WORK IN PROGRESS ⚠️
# this script does work mostly and for the broken parts it just needs the scripts
# from my other projects to be copied over. please be patient...

# remove line to enable build
exit 0
if ! [ -f /bin/pacman ]; then
    exit 0
fi

useradd -m -g users -G wheel minecraft
cp /etc/sudoers /etc/sudoers.bak
tee -a /etc/sudoers <<EOF

minecraft ALL=(ALL) NOPASSWD:ALL
EOF

LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed jre-openjdk tmux

_fabric=1.20.1
_loader=0.16.4
_launcher=1.0.1
  
mkdir -p /srv/fabric
chown -R minecraft:users /srv/fabric
chmod g+s /srv/fabric
su -s /bin/bash - minecraft <<'EOS'
pushd /srv/fabric
  _fabric=1.20.1
  _loader=0.16.4
  _launcher=1.0.1
  curl -sL -o fabric-server-$_fabric-$_loader-$_launcher-launcher.jar https://meta.fabricmc.net/v2/versions/loader/$_fabric/$_loader/$_launcher/server/jar
  # will abort to tell the user to sign the eula
  echo ":: Start server (will fail as of missing eula)"
  java -Xmx2G -jar fabric-server-$_fabric-$_loader-$_launcher-launcher.jar nogui || true
  # sign eula
  echo ":: sign eula"
  sed -i 's/^eula=.*/eula=true/' /srv/fabric/eula.txt
  
  echo ":: download fabric-api"
  curl -sL --progress-bar -o /srv/fabric/mods/fabric-api-0.92.2+1.20.1.jar 'https://cdn.modrinth.com/data/P7dR8mSH/versions/P7uGFii0/fabric-api-0.92.2%2B1.20.1.jar'
  echo ":: download Geyser"
  curl -sL --progress-bar -o /srv/fabric/mods/geyser-fabric-2.2.0-SNAPSHOT+build.317.jar 'https://cdn.modrinth.com/data/wKkoqHrH/versions/sxF4OIVL/geyser-fabric-2.2.0-SNAPSHOT%2Bbuild.317.jar'
  echo ":: download Floodgate"
  curl -sL --progress-bar -o /srv/fabric/mods/floodgate-fabric.jar 'https://cdn.modrinth.com/data/bWrNNfkb/versions/vIbusVdM/floodgate-fabric.jar'
  echo ":: download ViaFabric"
  curl -sL --progress-bar -o /srv/fabric/mods/ViaFabric-0.4.15+78-main.jar 'https://cdn.modrinth.com/data/YlKdE5VK/versions/dS5UWGlC/ViaFabric-0.4.15%2B78-main.jar'
  echo ":: download performance improvement mods"
  curl -sL --progress-bar -o /srv/fabric/mods/lithium-fabric-mc1.20.1-0.11.2.jar 'https://cdn.modrinth.com/data/gvQqBUqZ/versions/ZSNsJrPI/lithium-fabric-mc1.20.1-0.11.2.jar'
  curl -sL --progress-bar -o /srv/fabric/mods/indium-1.0.34+mc1.20.1.jar 'https://cdn.modrinth.com/data/Orvt0mRa/versions/gofbpynL/indium-1.0.34%2Bmc1.20.1.jar'
  curl -sL --progress-bar -o /srv/fabric/mods/memoryleakfix-fabric-1.17+-1.1.5.jar 'https://cdn.modrinth.com/data/NRjRiSSD/versions/5xvCCRjJ/memoryleakfix-fabric-1.17%2B-1.1.5.jar'
  curl -sL --progress-bar -o /srv/fabric/mods/ferritecore-6.0.1-fabric.jar 'https://cdn.modrinth.com/data/uXXizFIs/versions/unerR5MN/ferritecore-6.0.1-fabric.jar'

  echo ":: download Create"
  curl -sL --progress-bar -o /srv/fabric/mods/create-fabric-0.5.1-f-build.1417+mc1.20.1.jar 'https://cdn.modrinth.com/data/Xbc0uyRg/versions/h2HgGyvA/create-fabric-0.5.1-f-build.1417%2Bmc1.20.1.jar'
  curl -sL --progress-bar -o /srv/fabric/mods/create-structures-0.1.1-1.20.1-FABRIC.jar 'https://cdn.modrinth.com/data/IAnP4np7/versions/nqsTHZwx/create-structures-0.1.1-1.20.1-FABRIC.jar'
  curl -sL --progress-bar -o /srv/fabric/mods/create-new-age-fabric-1.20.1-1.1.2.jar 'https://cdn.modrinth.com/data/FTeXqI9v/versions/rk63oafd/create-new-age-fabric-1.20.1-1.1.2.jar'
  curl -sL --progress-bar -o /srv/fabric/mods/botarium-fabric-1.20.1-2.3.4.jar 'https://cdn.modrinth.com/data/2u6LRnMa/versions/f3ATcSfq/botarium-fabric-1.20.1-2.3.4.jar'
  curl -sL --progress-bar -o /srv/fabric/mods/create_interactive-1.0.3-beta.2+e045de2a48.jar 'https://cdn.modrinth.com/data/MyfCcqiE/versions/VLHAtRBQ/create_interactive-1.0.3-beta.2%2Be045de2a48.jar'
  curl -sL --progress-bar -o /srv/fabric/mods/valkyrienskies-120-2.3.0-beta.5.jar 'https://cdn.modrinth.com/data/V5ujR2yw/versions/wDYLclLS/valkyrienskies-120-2.3.0-beta.5.jar'
  curl -sL --progress-bar -o /srv/fabric/mods/Steam_Rails-1.6.4+fabric-mc1.20.1.jar 'https://cdn.modrinth.com/data/ZzjhlDgM/versions/AJ3IGl3n/Steam_Rails-1.6.4%2Bfabric-mc1.20.1.jar'
  curl -sL --progress-bar -o /srv/fabric/mods/createaddition-fabric+1.20.1-1.2.4.jar 'https://cdn.modrinth.com/data/kU1G12Nn/versions/vV4bZmhm/createaddition-fabric%2B1.20.1-1.2.4.jar'

  echo ":: download Controlify"
  curl -sL --progress-bar -o /srv/fabric/mods/Controlify-1.6.0+1.20.jar 'https://cdn.modrinth.com/data/DOUdJVEm/versions/MSWp1Dsg/Controlify-1.6.0%2B1.20.jar'
  curl -sL --progress-bar -o /srv/fabric/mods/YetAnotherConfigLib-3.5.0+1.20.1-fabric.jar 'https://cdn.modrinth.com/data/1eAoo2KR/versions/gQuF6HNa/YetAnotherConfigLib-3.5.0%2B1.20.1-fabric.jar'
  echo ":: download Chunky"
  curl -sL --progress-bar -o /srv/fabric/mods/Chunky-1.3.146.jar 'https://cdn.modrinth.com/data/fALzjamp/versions/NHWYq9at/Chunky-1.3.146.jar'
  curl -sL --progress-bar -o /srv/fabric/mods/ChunkyBorder-1.1.53.jar 'https://cdn.modrinth.com/data/s86X568j/versions/74w5ono0/ChunkyBorder-1.1.53.jar'
  echo ":: download Gravestones"
  curl -sL --progress-bar -o /srv/fabric/mods/gravestones-1.0.9-1.20.1.jar 'https://cdn.modrinth.com/data/Heh3BbSv/versions/ADj6ezOT/gravestones-1.0.9-1.20.1.jar'
  curl -sL --progress-bar -o /srv/fabric/mods/pneumonocore-1.1.4+1.20.1.jar 'https://cdn.modrinth.com/data/ZLKQjA7t/versions/MtM4xjYo/pneumonocore-1.1.4%2B1.20.1.jar'
  echo ":: download Towns and Towers"
  curl -sL --progress-bar -o /srv/fabric/mods/Towns-and-Towers-1.12-Fabric+Forge.jar 'https://cdn.modrinth.com/data/DjLobEOy/versions/7ZwnSrVW/Towns-and-Towers-1.12-Fabric%2BForge.jar'
  curl -sL --progress-bar -o /srv/fabric/mods/cristellib-1.1.5-fabric.jar 'https://cdn.modrinth.com/data/cl223EMc/versions/tBnivdbu/cristellib-1.1.5-fabric.jar'
  echo ":: download voicechat"
  curl -sL --progress-bar -o /srv/fabric/mods/voicechat-fabric-1.20.1-2.5.21.jar 'https://cdn.modrinth.com/data/9eGKb6K1/versions/amYSgReO/voicechat-fabric-1.20.1-2.5.21.jar'
  echo ":: download LeavesBeGone"
  curl -sL --progress-bar -o /srv/fabric/mods/LeavesBeGone-v8.0.0-1.20.1-Fabric.jar 'https://cdn.modrinth.com/data/AVq17PqV/versions/I6xyij66/LeavesBeGone-v8.0.0-1.20.1-Fabric.jar'
  curl -sL --progress-bar -o /srv/fabric/mods/PuzzlesLib-v8.1.22-1.20.1-Fabric.jar 'https://cdn.modrinth.com/data/QAGBst4M/versions/aytL8HYY/PuzzlesLib-v8.1.22-1.20.1-Fabric.jar'

  echo ":: Restart server"
  timeout 90 /bin/java -Xmx2G -jar fabric-server-$_fabric-$_loader-$_launcher-launcher.jar nogui <<<"stop" || true

  # configure floodgate to be the plugin handling authentication
  sed -i 's/auth-type:.*/auth-type: floodgate/' /srv/fabric/config/Geyser-Fabric/config.yml
  cp /srv/fabric/config/floodgate/key.pem /srv/fabric/config/Geyser-Fabric/
popd
EOS

tee /usr/local/bin/fabric-server.sh <<EOF
#!/usr/bin/env bash
pushd /srv/fabric
  /usr/bin/java -Xmx2G -jar fabric-server-$_fabric-$_loader-$_launcher-launcher.jar nogui
popd
EOF
chmod +x /usr/local/bin/fabric-server.sh

tee /etc/systemd/system/fabric-server.service <<EOF
[Unit]
Description=Fabric server session (detached)
Documentation=man:tmux(1)

[Service]
Type=oneshot
RemainAfterExit=yes
User=minecraft
Group=users
WorkingDirectory=/srv/fabric
ExecStart=/usr/bin/tmux new-session -d -s fabric-server /usr/local/bin/fabric-server.sh
ExecStop=/usr/bin/tmux send-keys -t fabric-server 'stop' ENTER
KillMode=none

[Install]
WantedBy=multi-user.target
EOF

# revert sudoers
cp /etc/sudoers.bak /etc/sudoers
rm /etc/sudoers.bak

# remove possible broken world folders to get one generated on real first startup
/usr/bin/rm -r /srv/fabric/world*/ || true

# configure ports for minecraft
firewall-offline-cmd --zone=public --add-port=25565/tcp
firewall-offline-cmd --zone=public --add-port=19132/udp
firewall-offline-cmd --zone=public --add-port=24454/udp

# enable minecraft server on startup
systemctl enable fabric-server
