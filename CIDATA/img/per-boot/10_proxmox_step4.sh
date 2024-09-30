#!/usr/bin/env bash

if ! [ -f /bin/apt ] || grep -q Ubuntu /proc/version; then
    ( ( sleep 1 && rm -- "${0}" ) & )
    exit 0
fi

# only after step 3 reboot
if [ -f "/var/lib/cloud/scripts/per-boot/20_proxmox_step3.sh" ]; then
    exit 0
fi

exec &> >(while IFS=$'\r' read -ra line; do [ -z "${line[@]}" ] && line=( '' ); echo -e "[$(cat /proc/uptime | cut -d' ' -f1)] ${line[-1]}" | tee -a /cidata_log > /dev/tty1; done)

# create proxmox groups
pveum group add admins
pveum group add users

# create local user pveadm
USERID=pveadm
USERHASH=$(openssl passwd -6 -salt abcxyz "${USERID}")
useradd -m -r -s /bin/bash "$USERID"
sed -i 's/^'"$USERID"':[^:]*:/'"$USERID"':'"${USERHASH//\//\\/}"':/' /etc/shadow
pveum user add "$USERID"@pam -groups admins

# add permissions to groups and pools
pveum acl modify / --roles Administrator -groups admins -propagate 1
pveum acl modify /mapping --roles PVEMappingUser -groups users -propagate 1
ip -j link show | jq -r '.[] | select(.link_type != "loopback" and (.ifname | startswith("vmbr"))) | .ifname' | while read -r line; do
  pveum acl modify /sdn/zones/localnetwork/$line --roles PVESDNUser -groups users -propagate 1
done
pveum acl modify /storage --roles PVEDatastoreUser -groups users -propagate 1

# add local admins to group admins
for username in root pveadm; do
  pveum user add "$username"@pam || true
  pveum user modify "$username"@pam -groups admins || true
done

# add local users to group users
getent passwd | while IFS=: read -r username x uid gid gecos home shell; do
  if [ -n "$home" ] && [ -d "$home" ] && [ "${home:0:6}" == "/home/" ]; then
    if [ "$uid" -ge 1000 ]; then
      pveum user add "$username"@pam || true
      pveum user modify "$username"@pam -groups users || true
    fi
  fi
done

# create first pool pool1
pveum pool add pool1 || true
pveum acl modify /pool/pool1 --roles PVEPoolUser,PVETemplateUser -groups users -propagate 1 || true

# create user pools and vlans
pveum user list -full | grep " users " | cut -d' ' -f2 | while read -r username; do
  poolname=$(echo -en "pool-$username" | cut -d'@' -f1)
  pveum pool add "$poolname" || true
  pveum acl modify "/pool/$poolname" --roles PVEAdmin -users "$username" -propagate 1 || true
  brname=$(echo -en "br$username" | cut -d'@' -f1)
  if ! grep -qE "$brname" /etc/network/interfaces; then
    tee -a /etc/network/interfaces <<EOF

auto $brname
iface $brname inet static
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
EOF
  fi
  pveum acl modify "/sdn/zones/localnetwork/$brname" --roles PVESDNUser -users "$username" -propagate 1 || true
done
ifreload -a

# removes the nagging "subscription missing" popup on login (no permanent solution)
sed -Ezi 's/(function\(orig_cmd\) \{)/\1\n\torig_cmd\(\);\n\treturn;/g' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# add cloud images as lxc templates
lxcid=$((980))
while IFS=, read -r cloud_image cloud_url; do
  if [ -z "$cloud_image" ]; then
    continue
  fi
  pushd /var/lib/vz/template/cache
    echo ":: download $cloud_url"
    wget --progress=dot:mega -O "$cloud_image.tar.xz" "$cloud_url"
    echo ":: create container template $lxcid named $cloud_image"
    pct create $lxcid "local:vztmpl/$cloud_image.tar.xz" --hostname "$cloud_image" --pool pool1 --memory 2048 --net0 name=eth0,bridge=vmbr0
    pct start $lxcid
    pct enter $lxcid <<'EOF'
if [ -f /etc/cloud/cloud-init.disabled ]; then
  rm /etc/cloud/cloud-init.disabled
fi
mkdir -p /cidata
touch /cidata/meta-data
touch /cidata/vendor-data
tee /cidata/user-data <<'EOX'
#cloud-config
ssh_pwauth: true
chpasswd:
  expire: false
  users:
    - name: root
      password: packer-build-passwd
      type: text
locale: de_DE
keyboard:
  layout: de
  model: pc105
timezone: CET
bootcmd:
  - systemctl stop systemd-time-wait-sync.service
  - systemctl disable systemd-time-wait-sync.service
  - systemctl mask time-sync.target
write_files:
  - path: /etc/systemd/system/systemd-networkd-wait-online.service.d/wait-online-any.conf
    content: |
      [Service]
      ExecStart=
      ExecStart=/usr/lib/systemd/systemd-networkd-wait-online --operational-state=routable --any
    owner: 'root:root'
    permissions: '0644'
  - path: /etc/ssh/sshd_config
    content: |
      PermitRootLogin yes
      PasswordAuthentication yes
      UsePAM yes
    owner: 'root:root'
    permissions: '0644'
    append: true
  - path: /etc/default/locale
    content: LANG=de_DE.UTF-8
    owner: 'root:root'
    permissions: '0644'
  - path: /etc/timezone
    content: CET
    owner: 'root:root'
    permissions: '0644'
  - path: /etc/vconsole.conf
    content: |
      KEYMAP=de-latin1
      XKBLAYOUT=de
      XKBMODEL=pc105
      FONT=Lat2-Terminus16
    owner: 'root:root'
    permissions: '0644'
  - path: /etc/default/keyboard
    content: |
      KEYMAP=de-latin1
      XKBLAYOUT=de
      XKBMODEL=pc105
      FONT=Lat2-Terminus16
    owner: 'root:root'
    permissions: '0644'
  - path: /etc/default/console-setup
    content: |
      CHARMAP="UTF-8"
      CODESET="Lat2"
      FONTFACE="Terminus"
      FONTSIZE="16"
    owner: 'root:root'
    permissions: '0644'
  - path: /etc/skel/.inputrc
    content: |
      set enable-keypad on
    owner: 'root:root'
    permissions: '0644'
  - path: /var/lib/cloud/scripts/per-boot/00_firstboot.sh
    content: |
      #!/usr/bin/env bash

      exec &> >(while IFS=$'\r' read -ra line; do [ -z "${line[@]}" ] && line=( '' ); echo -e "[$(cat /proc/uptime | cut -d' ' -f1)] ${line[-1]}" | tee -a /cidata_log > /dev/tty1; done)
      
      # wait online (not on rocky, as rocky does not have wait-online preinstalled)
      if [ -f /usr/lib/systemd/systemd-networkd-wait-online ]; then
        echo ":: wait for any interface to be online"
        /usr/lib/systemd/systemd-networkd-wait-online --operational-state=routable --any
      fi

      # initialize pacman keyring
      if [ -e /bin/pacman ]; then
        sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
        LC_ALL=C yes | LC_ALL=C pacman -Sy --noconfirm archlinux-keyring
      fi

      # speedup apt on ubuntu and debian
      if [ -e /bin/apt ]; then
        APT_CFGS=( /etc/apt/apt.conf.d/* )
        for cfg in "${APT_CFGS[@]}"; do
          sed -i 's/^Acquire::http::Dl-Limit/\/\/Acquire::http::Dl-Limit/' "$cfg" || true
        done
        LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive apt update
        LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive apt -y install eatmydata
      fi

      # Configure keyboard and console
      if [ -e /bin/apt ]; then
        LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive apt update
        LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt -y install locales keyboard-configuration console-setup console-data tzdata
      elif [ -e /bin/yum ]; then
        LC_ALL=C yes | LC_ALL=C yum install -y glibc-common glibc-locale-source glibc-langpack-de
      fi

      # Generate locales
      if [ -e /bin/apt ]; then
        sed -i 's/^#\? \?de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
        dpkg-reconfigure --frontend=noninteractive locales
        update-locale LANG=de_DE.UTF-8
      elif [ -e /bin/pacman ]; then
        sed -i 's/^#\? \?de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
        echo "LANG=de_DE.UTF-8" > /etc/locale.conf
        locale-gen
      elif [ -e /bin/yum ]; then
        sed -i 's/^#\? \?de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
        echo "LANG=de_DE.UTF-8" > /etc/locale.conf
        localedef -c -i de_DE -f UTF-8 de_DE.UTF-8
      fi
      
      # Configure keyboard and console
      if [ -e /bin/apt ]; then
        dpkg-reconfigure --frontend=noninteractive keyboard-configuration
        dpkg-reconfigure --frontend=noninteractive console-setup
        mkdir -p /etc/systemd/system/console-setup.service.d
        tee /etc/systemd/system/console-setup.service.d/override.conf <<EOF
      [Service]
      ExecStartPost=/bin/setupcon
      EOF
      fi

      # cleanup
      rm -- "${0}"
    owner: 'root:root'
    permissions: '0755'
EOX
tee /cidata/network-config <<'EOX'
version: 2
ethernets:
  en:
    match:
      name: en*
    dhcp4: true
  eth:
    match:
      name: eth*
    dhcp4: true
EOX
tee /etc/cloud/cloud.cfg.d/99_nocloud.cfg <<'EOX'
disable_ec2_metadata: true
datasource_list: [ "NoCloud" ]
datasource:
  NoCloud:
    seedfrom: file:///cidata
EOX
cloud-init clean
EOF
    pct stop $lxcid
    pct template $lxcid
  popd
  unset cloud_image
  unset cloud_url
  lxcid=$((lxcid+1))
done <<'EOF'
archlinux-cloudimg-amd64,https://jenkins.linuxcontainers.org/job/image-archlinux/architecture=amd64%2Crelease=current%2Cvariant=cloud/lastCompletedBuild/artifact/rootfs.tar.xz
EOF
#noble-server-cloudimg-amd64,https://jenkins.linuxcontainers.org/job/image-ubuntu/architecture=amd64%2Crelease=noble%2Cvariant=cloud/lastCompletedBuild/artifact/rootfs.tar.xz
#debian-12-generic-amd64,https://jenkins.linuxcontainers.org/job/image-debian/architecture=amd64%2Crelease=bookworm%2Cvariant=cloud/lastCompletedBuild/artifact/rootfs.tar.xz
#rocky-9-genericcloud-amd64,https://jenkins.linuxcontainers.org/job/image-rockylinux/architecture=amd64%2Crelease=9%2Cvariant=cloud/lastCompletedBuild/artifact/rootfs.tar.xz

# add cloud images as vm templates
vmid=$((990))
modprobe nbd max_part=63
while IFS=, read -r cloud_image cloud_url; do
  if [ -z "$cloud_image" ]; then
    continue
  fi
  pushd /var/lib/vz/template/cache
    echo ":: download $cloud_url"
    wget --progress=dot:mega -O "$cloud_image.qcow2" "$cloud_url"
    echo ":: resize $cloud_image.qcow2"
    qemu-img resize "$cloud_image.qcow2" 512G
    echo ":: create block device for $cloud_image.qcow2"
    qemu-nbd -c /dev/nbd0 "$cloud_image.qcow2"
    sleep 2
    echo ":: detect root partition in $cloud_image.qcow2"
    ROOT_PART=( $(lsblk -no PATH,PARTTYPENAME /dev/nbd0 | sed -e '/root\|linux filesystem/I!d' | head -n1) )
    if [ -z "${ROOT_PART[0]}" ]; then
      echo "!! error detecting root partition in $cloud_image.qcow2"
      qemu-nbd -d /dev/nbd0
      popd
      unset cloud_image
      unset cloud_url
      continue
    fi
    echo ":: mount root partition ${ROOT_PART[0]}"
    mount -o rw "${ROOT_PART[0]}" /mnt
    echo ":: modify root partition ${ROOT_PART[0]}"
    USERID=root
    USERHASH=$(openssl passwd -6 -salt abcxyz 'packer-build-passwd')
    sed -i 's/^'"$USERID"':[^:]*:/'"$USERID"':'"${USERHASH//\//\\/}"':/' /mnt/etc/shadow
    if [ -f /mnt/etc/cloud/cloud-init.disabled ]; then
      rm /mnt/etc/cloud/cloud-init.disabled
    fi
    mkdir -p /mnt/cidata
    touch /mnt/cidata/meta-data
    touch /mnt/cidata/vendor-data
    tee /mnt/cidata/user-data <<'EOX'
#cloud-config
ssh_pwauth: true
chpasswd:
  expire: false
  users:
    - name: root
      password: packer-build-passwd
      type: text
locale: de_DE
keyboard:
  layout: de
  model: pc105
timezone: CET
bootcmd:
  - systemctl stop systemd-time-wait-sync.service
  - systemctl disable systemd-time-wait-sync.service
  - systemctl mask time-sync.target
  - loadkeys de-latin1
hostname: archlinux-cloud
create_hostname_file: true
fqdn: archlinux-cloud.internal
prefer_fqdn_over_hostname: true
write_files:
  - path: /etc/systemd/system/systemd-networkd-wait-online.service.d/wait-online-any.conf
    content: |
      [Service]
      ExecStart=
      ExecStart=/usr/lib/systemd/systemd-networkd-wait-online --operational-state=routable --any
    owner: 'root:root'
    permissions: '0644'
  - path: /etc/ssh/sshd_config
    content: |
      PermitRootLogin yes
      PasswordAuthentication yes
      UsePAM yes
    owner: 'root:root'
    permissions: '0644'
    append: true
  - path: /etc/default/locale
    content: LANG=de_DE.UTF-8
    owner: 'root:root'
    permissions: '0644'
  - path: /etc/timezone
    content: CET
    owner: 'root:root'
    permissions: '0644'
  - path: /etc/vconsole.conf
    content: |
      KEYMAP=de-latin1
      XKBLAYOUT=de
      XKBMODEL=pc105
      FONT=Lat2-Terminus16
    owner: 'root:root'
    permissions: '0644'
  - path: /etc/default/keyboard
    content: |
      KEYMAP=de-latin1
      XKBLAYOUT=de
      XKBMODEL=pc105
      FONT=Lat2-Terminus16
    owner: 'root:root'
    permissions: '0644'
  - path: /etc/default/console-setup
    content: |
      CHARMAP="UTF-8"
      CODESET="Lat2"
      FONTFACE="Terminus"
      FONTSIZE="16"
    owner: 'root:root'
    permissions: '0644'
  - path: /etc/skel/.inputrc
    content: |
      set enable-keypad on
    owner: 'root:root'
    permissions: '0644'
  - path: /var/lib/cloud/scripts/per-boot/00_firstboot.sh
    content: |
      #!/usr/bin/env bash

      exec &> >(while IFS=$'\r' read -ra line; do [ -z "${line[@]}" ] && line=( '' ); echo -e "[$(cat /proc/uptime | cut -d' ' -f1)] ${line[-1]}" | tee -a /cidata_log > /dev/tty1; done)
      
      # wait online (not on rocky, as rocky does not have wait-online preinstalled)
      if [ -f /usr/lib/systemd/systemd-networkd-wait-online ]; then
        echo ":: wait for any interface to be online"
        /usr/lib/systemd/systemd-networkd-wait-online --operational-state=routable --any
      fi

      # initialize pacman keyring
      if [ -e /bin/pacman ]; then
        sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
        LC_ALL=C yes | LC_ALL=C pacman -Sy --noconfirm archlinux-keyring
      fi

      # speedup apt on ubuntu and debian
      if [ -e /bin/apt ]; then
        APT_CFGS=( /etc/apt/apt.conf.d/* )
        for cfg in "${APT_CFGS[@]}"; do
          sed -i 's/^Acquire::http::Dl-Limit/\/\/Acquire::http::Dl-Limit/' "$cfg" || true
        done
        LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive apt update
        LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive apt -y install eatmydata
      fi

      # Configure keyboard and console
      if [ -e /bin/apt ]; then
        LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive apt update
        LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt -y install locales keyboard-configuration console-setup console-data tzdata
      elif [ -e /bin/yum ]; then
        LC_ALL=C yes | LC_ALL=C yum install -y glibc-common glibc-locale-source glibc-langpack-de
      fi

      # Generate locales
      if [ -e /bin/apt ]; then
        sed -i 's/^#\? \?de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
        dpkg-reconfigure --frontend=noninteractive locales
        update-locale LANG=de_DE.UTF-8
      elif [ -e /bin/pacman ]; then
        sed -i 's/^#\? \?de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
        echo "LANG=de_DE.UTF-8" > /etc/locale.conf
        locale-gen
      elif [ -e /bin/yum ]; then
        sed -i 's/^#\? \?de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
        echo "LANG=de_DE.UTF-8" > /etc/locale.conf
        localedef -c -i de_DE -f UTF-8 de_DE.UTF-8
      fi
      
      # Configure timezone
      if [ -e /bin/apt ]; then
        rm /etc/localtime || true
        ln -s /usr/share/zoneinfo/CET /etc/localtime
        dpkg-reconfigure --frontend=noninteractive tzdata
      elif [ -e /bin/pacman ]; then
        rm /etc/localtime || true
        ln -s /usr/share/zoneinfo/CET /etc/localtime
      elif [ -e /bin/yum ]; then
        rm /etc/localtime || true
        ln -s /usr/share/zoneinfo/CET /etc/localtime
      fi
      
      # Configure keyboard and console
      if [ -e /bin/apt ]; then
        dpkg-reconfigure --frontend=noninteractive keyboard-configuration
        dpkg-reconfigure --frontend=noninteractive console-setup
        mkdir -p /etc/systemd/system/console-setup.service.d
        tee /etc/systemd/system/console-setup.service.d/override.conf <<EOF
      [Service]
      ExecStartPost=/bin/setupcon
      EOF
      elif [ -e /bin/pacman ]; then
        loadkeys de-latin1 || true
      elif [ -e /bin/yum ]; then
        loadkeys de-latin1 || true
      fi

      # Configure (virtual) environment
      VIRT_ENV=$(systemd-detect-virt)
      if [ -e /bin/apt ]; then
        case $VIRT_ENV in
          qemu | kvm)
            LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt -y install qemu-guest-agent
            ;;
          oracle)
            if grep -q Ubuntu /proc/version; then
              LC_ALL=C yes | LC_ALL=C DEBIAN_FRONTEND=noninteractive eatmydata apt -y install virtualbox-guest-x11
            fi
            ;;
        esac
      elif [ -e /bin/pacman ]; then
        case $VIRT_ENV in
          qemu | kvm)
            LC_ALL=C yes | LC_ALL=C pacman -Syu --noconfirm qemu-guest-agent
            ;;
          oracle)
            LC_ALL=C yes | LC_ALL=C pacman -Syu --noconfirm virtualbox-guest-utils
            systemctl enable vboxservice.service
            ;;
        esac
      elif [ -e /bin/yum ]; then
        case $VIRT_ENV in
          qemu | kvm)
            LC_ALL=C yes | LC_ALL=C yum install -y qemu-guest-agent
            ;;
        esac
      fi

      # modify grub
      GRUB_GLOBAL_CMDLINE="console=tty1 rw loglevel=3 acpi=force acpi_osi=Linux"
      GRUB_CFGS=( /etc/default/grub /etc/default/grub.d/* )
      for cfg in "${GRUB_CFGS[@]}"; do
        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="'"$GRUB_GLOBAL_CMDLINE"'"/' "$cfg" || true
        sed -i 's/^GRUB_CMDLINE_LINUX=/#GRUB_CMDLINE_LINUX=/' "$cfg" || true
        sed -i 's/^GRUB_TERMINAL=.*/GRUB_TERMINAL=console/' "$cfg" || true
      done
      if [ -e /bin/apt ]; then
        grub-mkconfig -o /boot/grub/grub.cfg
        if [ -d /boot/efi/EFI/debian ]; then
          grub-mkconfig -o /boot/efi/EFI/debian/grub.cfg
        elif [ -d /boot/efi/EFI/ubuntu ]; then
          grub-mkconfig -o /boot/efi/EFI/ubuntu/grub.cfg
        fi
      elif [ -e /bin/pacman ]; then
        grub-mkconfig -o /boot/grub/grub.cfg
      elif [ -e /bin/yum ]; then
        grub2-editenv - set "kernelopts=$GRUB_GLOBAL_CMDLINE"
        if [ -e /sbin/grubby ]; then
          grubby --update-kernel=ALL --args="$GRUB_GLOBAL_CMDLINE"
        fi
        grub2-mkconfig -o /boot/grub2/grub.cfg --update-bls-cmdline
        grub2-mkconfig -o /boot/efi/EFI/rocky/grub.cfg --update-bls-cmdline
      fi
    
      # cleanup
      rm -- "${0}"
    owner: 'root:root'
    permissions: '0755'
EOX
    tee /mnt/cidata/network-config <<'EOX'
version: 2
ethernets:
  en:
    match:
      name: en*
    dhcp4: true
  eth:
    match:
      name: eth*
    dhcp4: true
EOX
    tee /mnt/etc/cloud/cloud.cfg.d/99_nocloud.cfg <<'EOX'
disable_ec2_metadata: true
datasource_list: [ "NoCloud" ]
datasource:
  NoCloud:
    seedfrom: file:///cidata
EOX
    unset USERID
    unset USERHASH
    echo ":: unmount and unload $cloud_image.qcow2"
    umount /mnt
    qemu-nbd -d /dev/nbd0
    sleep 2
    echo ":: create vm template $vmid named $cloud_image"
    qm create $vmid --name "$cloud_image" --pool pool1 --machine q35 --cores 4 --memory 2048 --boot order=virtio0 \
      --bios ovmf --virtio0 "local:0,discard=on,import-from=/var/lib/vz/template/cache/$cloud_image.qcow2,format=qcow2" \
      --net0 virtio,bridge=vmbr0 --efidisk0 local:0,efitype=4m --tpmstate0 local:0,version=v2.0 \
      --serial0 socket --vga virtio
    qm template $vmid
  popd
  unset cloud_image
  unset cloud_url
  vmid=$((vmid+1))
done <<'EOF'
archlinux-cloudimg-amd64,https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2
EOF
#noble-server-cloudimg-amd64,https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
#debian-12-generic-amd64,https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
#rocky-9-genericcloud-amd64,https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2

# reboot system
( ( sleep 5 && systemctl reboot ) & )

# cleanup
rm -- "${0}"
