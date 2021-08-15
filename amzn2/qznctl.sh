#!/bin/bash
# qznctl.sh
# A simple script to stand up a single instance of an Amazon2 Linux VM. Uses user-networking

# Configuration variables. Modify as needed.
AMZN2_IMAGE="amzn2-kvm-2.0.20210721.2-x86_64.xfs.gpt.qcow2"
CPU_CORES=4
CPU_THREADS=1
DISK_SIZE="25G"
MEMORY="8192m"
SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0OqzFm/vPZQoMr8kzWHH4wuBf24GXCQNwbO0w9GHJVdmEdhVecUNoVsPPzwj/aHpuY4daxnAxvOVPJdGLszUNSkRvPYnLgl77Zw0WXEVSIk8ReOaFMcLkwOX8FjaRzPoxTMG+BpfJZMHLWvBnIjywvvg5rr8eF2V1PScWCELvkWoZ3haXjVTb0G+0Wb3AhS+PEEGi0jxmkPQwktW31EdbMqQgZtiV3A+iPsHx/q1kB9kOQrGCLfk9ZKxP64w+RMimsw+J42F07wrX9LQ76g8bW5lZpvoZtcRgBweuGPjwNEn/QFdZ6T8pOjdAbbJyvTn680J/2EjRPd2zbKCP43yr"

# Network configuration below. Shouldn't need to modify but you can.
# Use only a /24. IPs are hard coded. Only need to provide the first three octets as "a.b.c."
# RFC5737 - 192.0.2.0/24 TEST-NET-1, 198.51.100.0/24 TEST-NET-2, 203.0.113.0/24 TEST-NET-3
# Too many things are utilizing CGN/100.64.0.0/10 nowadays.
#IP_NET="203.0.133."
IP_NET="192.168.64."
DNS_FWD_PORT=5353
SSH_FWD_PORT=2222

# Don't change me.
OS=$(uname)

# Check args passed is valid.
function check-args() {
    if [[ ${#} -ne 1 ]]; then
        print-help
        exit 1
    fi
    return
}

# Generate cloud-init seed iso.
function generate-cloud-init() {
    mkdir -p seedconfig
    cat << EOF > seedconfig/meta-data
local-hostname: amzn2-devbox.local
network-interfaces: |
  auto eth0
  iface eth0 inet static
  address ${IP_NET}3
  netmask 255.255.255.0
  gateway ${IP_NET}1
  dns-nameservers ${IP_NET}2
EOF

cat << EOF > seedconfig/user-data
#cloud-config

ssh_authorized_keys:
- ${SSH_KEY}

users:
- default
EOF

    rm -f seed.iso

    if [[ ${OS} == "Linux" ]]; then
        pushd seedconfig
        genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data
        popd
    elif [[ ${OS} == "Darwin" ]]; then
        hdiutil makehybrid -o seed.iso -hfs -joliet -iso -default-volume-name cidata seedconfig/
    fi
}

# Clone a new linked disk.
function generate-vda() {
    qemu-img create -f qcow2 -b ${AMZN2_IMAGE} -F qcow2 vda.qcow2 ${DISK_SIZE}
}

# Get the base image.
function get-image() {
    curl -O -L https://cdn.amazonlinux.com/os-images/2.0.20210721.2/kvm/${AMZN2_IMAGE}
}

# Print help
function print-help() {
    echo ""
    echo "Usage: ${0} <argument>"
    echo ""
    echo "Valid arguments:"
    echo "$(declare -F | cut -d ' ' -f 3 | grep -v -E 'main|check-args')"
}

# Start the VM
# Side note, too lazy to write conditional for Linux support at the moment.
function start() {
    qemu-system-x86_64 \
        -name amzn2-devbox.local \
        -machine q35 \
        -cpu host \
        -accel hvf \
        -smp cores=${CPU_CORES},threads=${CPU_THREADS} \
        -m ${MEMORY} \
        -vga virtio \
        -display cocoa,show-cursor=on \
        -drive id=vda,file=vda.qcow2,format=qcow2,if=virtio \
        -netdev user,id=net0,net=${IP_NET}0/29,dhcpstart=${IP_NET}3,host=${IP_NET}1,dns=${IP_NET}2,hostfwd=tcp:127.0.0.1:${SSH_FWD_PORT}-${IP_NET}3:22,hostfwd=tcp:127.0.0.1:${DNS_FWD_PORT}-${IP_NET}3:53 \
        -device virtio-net,netdev=net0 \
        -device virtio-tablet \
        -serial unix:serial.sock,server,nowait \
        -monitor unix:monitor.sock,server,nowait \
        -cdrom seed.iso
}

# Main
function main() {
    check-args ${@}
    case "${1}" in
        get-image)
            get-image
            ;;
        generate-vda)
            generate-vda
            ;;
        generate-cloud-init)
            generate-cloud-init
            ;;
        start)
            start
            ;;
        *)
            print-help
            exit 1
            ;;
    esac
}

main ${@}
