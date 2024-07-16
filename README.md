# Proof of concept deploying cloud ready images on metal via USB Stick, CD Drive or PXE Boot

## WARNING

Some of the scripts in this project **will** destroy all data on your system. So be careful! **I will not take any responsibility for any of your lost files!**

# Installation Process

After the preamble: how to install everything? I assume after this point you want to try everything out first before going the steps to install everything onto your production machine. (**NO!!!**)

Your test environment should include packer for automation and either qemu (Linux), virtualbox (Windows) or proxmox for virtualization.

Supported cloud images are Arch Linux, Ubuntu, Debian and Rocky Linux. They must be placed inside the CIDATA/img folder. Additional installation scripts can be placed in CIDATA/img/install.

Just execute pipeline.sh on either windows or Linux and let the setup process build everything fully automated via archiso (Arch Linux install medium) as pxe bootable, cloud-init capable environment.

⚠️ WORK IN PROGRESS ⚠️


That's all for now. Happy deployment. --johndeedly
