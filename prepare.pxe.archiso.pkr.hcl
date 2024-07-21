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
  build_name_qemu       = join(".", ["prepare_pxe_archiso-x86_64", replace(timestamp(), ":", "꞉"), "qcow2"]) # unicode replacement char for colon
  build_name_virtualbox = join(".", ["prepare_pxe_archiso-x86_64", replace(timestamp(), ":", "꞉")]) # unicode replacement char for colon
}


source "qemu" "default" {
  shutdown_command     = "/sbin/poweroff"
  cd_files             = ["CIDATA_PREPARE_PXE/*","CIDATA"]
  cd_label             = "CIDATA"
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
  output_directory     = "output/prepare_pxe_archiso"
  ssh_username         = "root"
  ssh_password         = "packer-build-passwd"
  ssh_timeout          = "10m"
  vm_name              = local.build_name_qemu
}


source "virtualbox-iso" "default" {
  shutdown_command         = "/sbin/poweroff"
  cd_files                 = ["CIDATA_PREPARE_PXE/*","CIDATA"]
  cd_label                 = "CIDATA"
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
  output_directory         = "output/prepare_pxe_archiso-x86_64"
  output_filename          = "../prepare_pxe_archiso-x86_64"
  ssh_username             = "root"
  ssh_password             = "packer-build-passwd"
  ssh_timeout              = "10m"
  vboxmanage               = [["modifyvm", "{{ .Name }}", "--chipset", "ich9", "--firmware", "efi", "--cpus", "${var.cpu_cores}", "--audio-driver", "${var.sound_driver}", "--audio-out", "on", "--audio-enabled", "on", "--usb", "on", "--usb-xhci", "on", "--clipboard", "hosttoguest", "--draganddrop", "hosttoguest", "--graphicscontroller", "vmsvga", "--acpi", "on", "--ioapic", "on", "--apic", "on", "--accelerate3d", "${var.accel_graphics}", "--accelerate2dvideo", "on", "--vram", "128", "--pae", "on", "--nested-hw-virt", "on", "--paravirtprovider", "kvm", "--hpet", "on", "--hwvirtex", "on", "--largepages", "on", "--vtxvpid", "on", "--vtxux", "on", "--biosbootmenu", "messageandmenu", "--rtcuseutc", "on", "--nictype1", "virtio", "--macaddress1", "auto"], ["sharedfolder", "add", "{{ .Name }}", "--name", "host.0", "--hostpath", "output/"]]
  vboxmanage_post          = [["modifyvm", "{{ .Name }}", "--macaddress1", "auto"], ["sharedfolder", "remove", "{{ .Name }}", "--name", "host.0"]]
  vm_name                  = local.build_name_virtualbox
  skip_export              = true
}


build {
  sources = ["source.qemu.default", "source.virtualbox-iso.default"]

  provisioner "shell" {
    script = "build-pxe.sh"
  }
}
