packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
    virtualbox = {
      source  = "github.com/hashicorp/virtualbox"
      version = "~> 1"
    }
  }
}


variable "sound_driver" {
  type = string
}

variable "accel_graphics" {
  type = string
}

variable "verbose" {
  type    = bool
  default = false
}

variable "cpu_cores" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 4096
}

variable "headless" {
  type    = bool
  default = false
}

locals {
  build_name_qemu       = join("-", ["cloud_ready-x86_64", replace(timestamp(), ":", "꞉"), ".qcow2"]) # unicode replacement char for colon
  build_name_virtualbox = join("-", ["cloud_ready-x86_64", replace(timestamp(), ":", "꞉")]) # unicode replacement char for colon
}


source "qemu" "default" {
  shutdown_command     = "/sbin/poweroff"
  cd_files             = ["CIDATA/*"]
  cd_label             = "CIDATA"
  disk_size            = "524288M"
  memory               = var.memory
  format               = "qcow2"
  accelerator          = "kvm"
  disk_discard         = "unmap"
  disk_detect_zeroes   = "unmap"
  disk_interface       = "virtio"
  disk_compression     = false
  skip_compaction      = true
  net_device           = "virtio-net"
  vga                  = "virtio"
  machine_type         = "q35"
  cpu_model            = "host"
  vtpm                 = true
  tpm_device_type      = "tpm-tis"
  efi_boot             = true
  efi_firmware_code    = "/usr/share/OVMF/x64/OVMF_CODE.secboot.4m.fd"
  efi_firmware_vars    = "/usr/share/OVMF/x64/OVMF_VARS.4m.fd"
  sockets              = 1
  cores                = var.cpu_cores
  threads              = 1
  qemuargs             = [["-rtc", "base=utc,clock=host"], ["-usbdevice", "mouse"], ["-usbdevice", "keyboard"], ["-virtfs", "local,path=output,mount_tag=host.0,security_model=mapped,id=host.0"]]
  headless             = var.headless
  iso_checksum         = "none"
  iso_url              = "archlinux-x86_64.iso"
  output_directory     = "output/cloud_ready"
  ssh_username         = "root"
  ssh_password         = "packer-build-passwd"
  ssh_timeout          = "10m"
  vm_name              = local.build_name_qemu
}


source "virtualbox-iso" "default" {
  shutdown_command         = "/sbin/poweroff"
  cd_files                 = ["CIDATA/*"]
  cd_label                 = "CIDATA"
  disk_size                = 524288
  memory                   = var.memory
  format                   = "ova"
  guest_additions_mode     = "disable"
  guest_os_type            = "ArchLinux_64"
  hard_drive_discard       = true
  hard_drive_interface     = "virtio"
  hard_drive_nonrotational = true
  headless                 = var.headless
  iso_checksum             = "none"
  iso_interface            = "virtio"
  iso_url                  = "archlinux-x86_64.iso"
  output_directory         = "output/cloud_ready-x86_64"
  output_filename          = "../cloud_ready-x86_64"
  ssh_username             = "root"
  ssh_password             = "packer-build-passwd"
  ssh_timeout              = "10m"
  vboxmanage               = [["modifyvm", "{{ .Name }}", "--chipset", "ich9", "--firmware", "efi", "--cpus", "${var.cpu_cores}", "--audio-driver", "${var.sound_driver}", "--audio-out", "on", "--audio-enabled", "on", "--usb", "on", "--usb-xhci", "on", "--clipboard", "hosttoguest", "--draganddrop", "hosttoguest", "--graphicscontroller", "vmsvga", "--acpi", "on", "--ioapic", "on", "--apic", "on", "--accelerate3d", "${var.accel_graphics}", "--accelerate2dvideo", "on", "--vram", "128", "--pae", "on", "--nested-hw-virt", "on", "--paravirtprovider", "kvm", "--hpet", "on", "--hwvirtex", "on", "--largepages", "on", "--vtxvpid", "on", "--vtxux", "on", "--biosbootmenu", "messageandmenu", "--rtcuseutc", "on", "--nictype1", "virtio", "--macaddress1", "auto"], ["sharedfolder", "add", "{{ .Name }}", "--name", "host.0", "--hostpath", "output/"]]
  vboxmanage_post          = [["modifyvm", "{{ .Name }}", "--macaddress1", "auto"], ["sharedfolder", "remove", "{{ .Name }}", "--name", "host.0"]]
  vm_name                  = local.build_name_virtualbox
  skip_export              = true
  keep_registered          = true
}


build {
  sources = ["source.qemu.default", "source.virtualbox-iso.default"]

  provisioner "shell" {
    pause_before = "10s"
    timeout      = "10s"
    max_retries  = 20
    inline = [
      "while ! [ -f /cidata_log ]; do",
      "  sleep 17",
      "done",
      "while ! grep \":: provisioning prepared\" /cidata_log; do",
      "  sleep 17",
      "done"
    ]
  }

  provisioner "shell" {
    pause_before = "10s"
    timeout      = "10s"
    max_retries  = 20
    inline = [
      "systemctl reboot"
    ]
    only    = ["qemu.default"]
  }

  provisioner "shell" {
    pause_before = "10s"
    timeout      = "10s"
    max_retries  = 20
    inline = [
      "while ! [ -f /cidata_log ]; do",
      "  sleep 17",
      "done",
      "while ! grep \":: provisioning completed\" /cidata_log; do",
      "  sleep 17",
      "done"
    ]
    only    = ["qemu.default"]
  }

  provisioner "shell-local" {
    inline = [<<EOS
tee output/cloud_ready/cloud_ready-x86_64.run.sh <<EOF
#!/usr/bin/env bash
trap "trap - SIGTERM && kill -- -\$\$" SIGINT SIGTERM EXIT
mkdir -p "/tmp/swtpm.0" "share"
/usr/bin/swtpm socket --tpm2 --tpmstate dir="/tmp/swtpm.0" --ctrl type=unixio,path="/tmp/swtpm.0/vtpm.sock" &
/usr/bin/qemu-system-x86_64 \\
  -name cloud_ready-x86_64 \\
  -machine type=q35,accel=kvm \\
  -vga virtio \\
  -cpu host \\
  -drive file=${local.build_name_qemu},if=virtio,cache=writeback,discard=unmap,detect-zeroes=unmap,format=qcow2 \\
  -device tpm-tis,tpmdev=tpm0 -tpmdev emulator,id=tpm0,chardev=vtpm -chardev socket,id=vtpm,path=/tmp/swtpm.0/vtpm.sock \\
  -drive file=/usr/share/OVMF/x64/OVMF_CODE.secboot.4m.fd,if=pflash,unit=0,format=raw,readonly=on \\
  -drive file=efivars.fd,if=pflash,unit=1,format=raw \\
  -smp ${var.cpu_cores},sockets=1,cores=${var.cpu_cores},maxcpus=${var.cpu_cores} -m ${var.memory}M \\
  -netdev user,id=user.0,hostfwd=tcp::9091-:9090 -device virtio-net,netdev=user.0 \\
  -audio driver=pa,model=hda,id=snd0 -device hda-output,audiodev=snd0 \\
  -virtfs local,path=share,mount_tag=host.0,security_model=mapped,id=host.0 \\
  -usbdevice mouse -usbdevice keyboard \\
  -rtc base=utc,clock=host
EOF
# -display none, -daemonize, hostfwd=::12345-:22 for running as a daemonized server
chmod +x output/cloud_ready/cloud_ready-x86_64.run.sh
EOS
    ]
    only_on = ["linux"]
    only    = ["qemu.default"]
  }
}
