# Proof of concept deploying cloud ready images on metal via USB Stick, CD Drive or PXE Boot

## WARNING

Some of the scripts in this project **will** destroy all data on your system. So be careful! **I will not take any responsibility for any of your lost files!**

# Installation Process

After the preamble: how to install everything? I assume after this point you want to try everything out first before going the steps to install everything onto your production machine. (**NO!!!**)

Your test environment should include packer for automation, swtpm for TPM emulation and either QEMU (Linux), VirtualBox (Windows) or Proxmox for virtualization.

Supported cloud images are Arch Linux, Ubuntu, Debian and Rocky Linux. They must be placed inside the CIDATA/img folder. Additional installation scripts can be placed in CIDATA/img/install. You can even put all the images in one place together and "disable" the ones you don't need by appending a ".disabled" or similar after the file extension.

Just execute pipeline.ps1 on either Windows or Linux and let the setup process build everything fully automated via archiso (Arch Linux install medium) as pxe bootable, cloud-init capable environment. After the disk is prepared, archiso isn't needed anymore.

## Optional user scripts

The folder ```install``` can contain scripts that are executed before everything is wrapped up. In them you have a fully logged in session at your disposal with all the good systemd and dbus services up and running. Commands like ```dconf``` and such should work out of the box here. 

The folders ```per-boot```, ```per-instance``` and ```per-once``` will map to the corresponding folders under ```/var/lib/cloud/scripts/```, where you can put scripts that are executed on system startup during the final cloud-init modules. ```per-boot``` is especially nice for scenarios where you are in need of a reboot, e.g. when installing drivers or kernel modules.

# Production use

After testing your setup in a virtual environment, the process of deploying everything on metal is straight forward. First, you need to execute the ```package-archiso.sh``` script, which will take all the scripts in the CIDATA folder and bundles them with the archiso image on a separate partition for cloud-init to detect as a nocloud source. The second step after building the modified iso is to burn it on a dvd-disc or ```dd```'ing the image to a usb stick. Ventoy is known to cause problems, so be prepared to drop the image as is on a stick, deleting all data stored on it in the process. Be careful which drive you ```dd``` (just saying...)!! PXE booting the iso to install it's contents is also a perfectly vaild option. Archiso can help you with that, as it can be booted via PXE, too. You can also take a look at Canonical MaaS.

## ⚠️ WORK IN PROGRESS ⚠️

The following scripts can be used to customize the deployment process:

- ```per-boot/*_proxmox_*.sh```: Build a proxmox instance virtually for testing or on metal for production use.
- ```install/*_graphical_*.sh```: Build a graphical environment with some programs preinstalled. Currently the best supported version is for Arch Linux.
- ```install/*_localmirror_*.sh```: Build a Arch Linux mirror to share packages locally and keep everything in sync automatically.


That's all for now. Happy deployment. --johndeedly
