#!/usr/bin/env bash

# error handling
set -E -o functrace
err_report() {
  echo "errexit command '${1}' returned ${2} on line $(caller)" 1>&2
  exit "${2}"
}
trap 'err_report "${BASH_COMMAND}" "${?}"' ERR

function log_text() {
    # bold yellow
    echo -e "\033[1;33m:: $*\033[0m"
}

function log_error() {
    # bold red
    echo -e "\033[1;31m!! $*\033[0m"
}

if ! [ -f "archlinux-x86_64.iso" ]; then
    ARCHISOHASH=$(curl -sL "https://geo.mirror.pkgbuild.com/iso/latest/sha256sums.txt" | grep -oE "^.*?archlinux-x86_64.iso$")

    log_text "Downloading archlinux-x86_64.iso"
    if ! wget -c -N --progress=dot:mega "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"; then
        log_error "Download error"
        exit 1
    fi

    sync
    
    log_text "Validate checksum of archlinux-x86_64.iso"
    if ! echo "${ARCHISOHASH}" | sha256sum --check --status; then
        log_error "Checksum mismatch"
        exit 1
    fi
fi

if ! [ -d CIDATA/img ]; then
    mkdir -p CIDATA/img
fi

if ! [ -f CIDATA/meta-data ]; then
    log_error "no cidata present, aborting"
    exit 1
fi

CLOUDINITISO="cloud-init.iso"
source package-cidata.sh

ARCHISOMODDED="archlinux-x86_64-with-cidata.iso"
[ -f "${ARCHISOMODDED}" ] && rm "${ARCHISOMODDED}"

log_text "Create the modified archiso image"
xorriso -indev "archlinux-x86_64.iso" \
        -outdev "${ARCHISOMODDED}" \
        -append_partition 3 0x83 "${CLOUDINITISO}" \
        -boot_image any replay
