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

if ! [ -d CIDATA/img ]; then
    mkdir -p CIDATA/img
fi

if ! [ -f "CIDATA/img/Arch-Linux-x86_64-cloudimg.qcow2" ]; then
    CLOUDHASH=$(curl -sL "https://geo.mirror.pkgbuild.com/archlinux/images/latest/Arch-Linux-x86_64-cloudimg.qcow2.SHA256")

    log_text "Arch-Linux-x86_64-cloudimg.qcow2"
    if ! wget -O "Arch-Linux-x86_64-cloudimg.qcow2" "https://geo.mirror.pkgbuild.com/archlinux/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"; then
        log_error "Download error"
        exit 1
    fi

    sync
    
    log_text "Validate checksum of Arch-Linux-x86_64-cloudimg.qcow2"
    if ! echo "${CLOUDHASH}" | sha256sum --check --status; then
        log_error "Checksum mismatch"
        exit 1
    fi

    mv "Arch-Linux-x86_64-cloudimg.qcow2" "CIDATA/img/Arch-Linux-x86_64-cloudimg.qcow2"
fi

if ! [ -f CIDATA/meta-data ]; then
    log_error "no cidata present, aborting"
    exit 1
fi

CLOUDINITISO="cloud-init.iso"
[ -f "${CLOUDINITISO}" ] && rm "${CLOUDINITISO}"

log_text "Create INSTALL image to append it to the archiso image"
xorriso -volid "CIDATA" \
        -outdev "${CLOUDINITISO}" \
        -map CIDATA/meta-data /meta-data \
        -map CIDATA/user-data /user-data \
        -map CIDATA/vendor-data /vendor-data \
        -map CIDATA/network-config /network-config \
        -map CIDATA/img/ /img/
