# Proof of concept deploying cloud ready images on metal via USB Stick, CD Drive or PXE Boot

## WARNING

Some of the scripts in this project **will** destroy all data on your system. So be careful! **I will not take any responsibility for any of your lost files!**

# Installation Process

After the preamble: how to install everything? I assume after this point you want to try everything out first before going the steps to install everything onto your production machine. (**NO!!!**)

Your test environment should include packer for automation, swtpm for TPM emulation and either QEMU (Linux), VirtualBox (Windows) or Proxmox for virtualization.

Supported cloud images are Arch Linux, Ubuntu, Debian and Rocky Linux. They must be placed inside the CIDATA/img folder. Additional installation scripts can be placed in CIDATA/img/install. You can even put all the images in one place together and "disable" the ones you don't need by appending a ".disabled" or similar after the file extension.

Just execute pipeline.ps1 on either Windows or Linux and let the setup process build everything fully automated via archiso (Arch Linux install medium) as pxe bootable, cloud-init capable environment. After the disk is prepared, archiso isn't needed anymore.

⚠️ WORK IN PROGRESS ⚠️


That's all for now. Happy deployment. --johndeedly
