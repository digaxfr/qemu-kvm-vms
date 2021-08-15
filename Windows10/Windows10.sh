#!/bin/bash
# https://k3a.me/boot-windows-partition-virtually-kvm-uefi/
# https://www.linux-kvm.org/page/Change_cdrom
# https://qemu.weilnetz.de/doc/qemu-doc.html#Commands
# https://www.spice-space.org/usbredir.html

qemu-system-x86_64 \
    -enable-kvm \
    -m 2G \
    -machine q35,accel=kvm \
    -smp 2,sockets=1,cores=1,threads=2 \
    -cpu host \
    -vga qxl \
    -spice addr=127.0.0.1,port=5930,disable-ticketing \
    -display none \
    -rtc clock=host,base=localtime \
    -device qemu-xhci,id=xhci \
    -chardev spicevmc,name=usbredir,id=usbredirchardev1 \
    -device usb-redir,chardev=usbredirchardev1,id=usbredirdev1 \
    -device virtio-tablet,wheel-axis=true \
    -device ich9-intel-hda \
    -device hda-output \
    -netdev user,id=win10 \
    -device virtio-net,netdev=win10 \
    -drive file=/usr/share/OVMF/OVMF_CODE.fd,if=pflash,format=raw,unit=0,readonly=on \
    -drive file=/home/dchin/VirtualMachines/Windows10/Windows10.nvram,if=pflash,format=raw,unit=1 \
    -drive file=/home/dchin/VirtualMachines/Windows10/Windows10.qcow2,if=virtio,format=qcow2 \
    -cdrom /home/dchin/VirtualMachines/Win10_1909_English_x64.iso \
    -monitor stdio

# During installation, you can use the qemu monitor to change cdrom
#   (qemu) info block
#   (qemu) change ide2-cd0 /path/to/new.iso

# To attach an iPhone, the whole point of this VM....
#   (qemu) info usbhost
#   ...
#   (qemu) device_add usb-host,vendorid=0x05ac,productid=0x12a8
#
# Or just use spice USB redirection...
