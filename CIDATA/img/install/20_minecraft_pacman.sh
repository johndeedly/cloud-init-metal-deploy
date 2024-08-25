#!/usr/bin/env bash

# ⚠️ WORK IN PROGRESS ⚠️
# this script does work mostly and for the broken parts it just needs the scripts
# from my other projects to be copied over. please be patient...

# remove line to enable build
exit 0
if ! [ -f /bin/pacman ]; then
    exit 0
fi

LC_ALL=C yes | LC_ALL=C pacman -S --noconfirm --needed paru

useradd -m -g users -G wheel minecraft
cp /etc/sudoers /etc/sudoers.bak
tee -a /etc/sudoers <<EOF

minecraft ALL=(ALL) NOPASSWD:ALL
EOF

tee -a /etc/paru.conf <<EOF

[papermc-1-20-4]
Path = /home/minecraft/papermc
EOF

su -s /bin/bash - minecraft <<EOS
git clone https://aur.archlinux.org/papermc.git ~/papermc
pushd ~/papermc
git reset --hard 85df3bf93ddf7ea8ae101bf1caf9098185523145
popd
paru -S --needed --noconfirm papermc-1-20-4/papermc
EOS

# revert sudoers
cp /etc/sudoers.bak /etc/sudoers
rm /etc/sudoers.bak

# start server once to agree to eula
systemctl start papermc
sleep 5
systemctl stop papermc
# server is stopped after this point

# agree to eula
sed -i 's/^eula=.*/eula=true/' /srv/papermc/eula.txt

# installing needed plugins for java/bedrock crossplay
mkdir -p /srv/papermc/plugins
curl -sL --progress-bar -o /srv/papermc/plugins/Geyser-Spigot.jar 'https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot'
curl -sL --progress-bar -o /srv/papermc/plugins/floodgate-spigot.jar 'https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot'
chown -R papermc:papermc /srv/papermc/plugins

# start server once more to enable plugins
systemctl start papermc
sleep 5
systemctl stop papermc
# server is stopped after this point

# configure floodgate to be the plugin handling authentication
sed -i 's/auth-type:.*/auth-type: floodgate/' /srv/papermc/plugins/Geyser-Spigot/config.yml
cp /srv/papermc/plugins/floodgate/key.pem /srv/papermc/plugins/Geyser-Spigot/

# nice additions to minecraft
echo ":: ViaVersion"
curl -sL --progress-bar -o /srv/papermc/plugins/ViaVersion-5.0.3.jar 'https://hangarcdn.papermc.io/plugins/ViaVersion/ViaVersion/versions/5.0.3/PAPER/ViaVersion-5.0.3.jar'
echo ":: ViaBackwards"
curl -sL --progress-bar -o /srv/papermc/plugins/ViaBackwards-5.0.3.jar 'https://hangarcdn.papermc.io/plugins/ViaVersion/ViaBackwards/versions/5.0.3/PAPER/ViaBackwards-5.0.3.jar'
echo ":: ViaRewind"
curl -sL --progress-bar -o /srv/papermc/plugins/ViaRewind-4.0.2.jar 'https://hangarcdn.papermc.io/plugins/ViaVersion/ViaRewind/versions/4.0.2/PAPER/ViaRewind-4.0.2.jar'
echo ":: Vane"
curl -sL --progress-bar -o /srv/papermc/plugins/vane-all-plugins.zip 'https://github.com/oddlama/vane/releases/download/v1.14.0/all-plugins.zip'
pushd /srv/papermc/plugins
  unzip vane-all-plugins.zip
  rm vane-all-plugins.zip
popd
echo ":: InvSee++"
curl -sL --progress-bar -o /srv/papermc/plugins/InvSee++.jar 'https://github.com/Jannyboy11/InvSee-plus-plus/releases/download/v0.29.5/InvSee++.jar'
echo ":: Stargate"
curl -sL --progress-bar -o /srv/papermc/plugins/Stargate-0.11.5.9.jar 'https://hangarcdn.papermc.io/plugins/Stargate/Stargate/versions/0.11.5.9/PAPER/Stargate-0.11.5.9.jar'
echo ":: Chunky"
curl -sL --progress-bar -o /srv/papermc/plugins/Chunky-1.3.146.jar 'https://hangarcdn.papermc.io/plugins/pop4959/Chunky/versions/1.3.146/PAPER/Chunky-1.3.146.jar'
echo ":: voicechat-bukkit"
curl -sL --progress-bar -o /srv/papermc/plugins/voicechat-bukkit-2.5.20.jar 'https://hangarcdn.papermc.io/plugins/henkelmax/SimpleVoiceChat/versions/bukkit-2.5.20/PAPER/voicechat-bukkit-2.5.20.jar'
echo ":: deathchest"
curl -sL --progress-bar -o /srv/papermc/plugins/deathchest.jar 'https://hangarcdn.papermc.io/plugins/CyntrixAlgorithm/DeathChest/versions/2.2.7/PAPER/deathchest.jar'
echo ":: SeeMore"
curl -sL --progress-bar -o /srv/papermc/plugins/SeeMore-1.0.2.jar 'https://hangarcdn.papermc.io/plugins/froobynooby/SeeMore/versions/1.0.2/PAPER/SeeMore-1.0.2.jar'
echo ":: Fancy NPCs"
curl -sL --progress-bar -o /srv/papermc/plugins/FancyNpcs-2.2.2.jar 'https://hangarcdn.papermc.io/plugins/Oliver/FancyNpcs/versions/2.2.2/PAPER/FancyNpcs-2.2.2.jar'
echo ":: KeepChunks"
curl -sL --progress-bar -o /srv/papermc/plugins/KeepChunks-1.7.2.jar 'https://hangarcdn.papermc.io/plugins/Geitenijs/KeepChunks/versions/1.7.2/PAPER/KeepChunks-1.7.2.jar'
echo ":: CommandPanels"
curl -sL --progress-bar -o /srv/papermc/plugins/CommandPanels.jar 'https://hangarcdn.papermc.io/plugins/RockyHawk/CommandPanels/versions/3.21.4.0/PAPER/CommandPanels.jar'
echo ":: ImageFrame and dependency ProtocolLib"
curl -sL --progress-bar -o /srv/papermc/plugins/ImageFrame-1.7.7.0.jar 'https://hangarcdn.papermc.io/plugins/LOOHP/ImageFrame/versions/1.7.7/PAPER/ImageFrame-1.7.7.0.jar'
curl -sL --progress-bar -o /srv/papermc/plugins/ProtocolLib.jar 'https://github.com/dmulloy2/ProtocolLib/releases/download/5.2.0/ProtocolLib.jar'
echo ":: HuskHomes"
curl -sL --progress-bar -o /srv/papermc/plugins/HuskHomes-Paper-4.7.jar 'https://hangarcdn.papermc.io/plugins/William278/HuskHomes/versions/4.7/PAPER/HuskHomes-Paper-4.7.jar'
echo ":: CommandControl"
curl -sL --progress-bar -o /srv/papermc/plugins/commander-3.1.0-all.jar 'https://hangarcdn.papermc.io/plugins/TheNextLvl/CommandControl/versions/3.1.0/PAPER/commander-3.1.0-all.jar'
chown -R papermc:papermc /srv/papermc/plugins

# start server once more
systemctl start papermc
sleep 5
systemctl stop papermc
# server is stopped after this point

# disable autostop of server
pushd /srv/papermc/plugins/vane-admin
yq -iy '.autostop.enabled=false' config.yml
popd
pushd /srv/papermc/plugins/vane-permissions
yq -iy '.enabled=false' config.yml
popd
pushd /srv/papermc/plugins/vane-core
yq -iy '.resource_pack.force=false' config.yml
yq -iy '.resource_pack.message_delaying.enabled=false' config.yml
popd

# remove possible broken world folders to get one generated on real first startup
/usr/bin/rm -r /srv/papermc/world*/

# configure ports for minecraft
firewall-offline-cmd --zone=public --add-port=25565/tcp
firewall-offline-cmd --zone=public --add-port=19132/udp
firewall-offline-cmd --zone=public --add-port=24454/udp

# enable minecraft server on startup
systemctl enable papermc
