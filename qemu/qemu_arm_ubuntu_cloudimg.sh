#!/bin/bash
# Boot Ubuntu Cloud Images on QEMU ARM
if [ $# -lt 4 ];then
    echo "Usage: ${0} <kernel> <disk> <cloudinit image> <interface>" >&2
    echo "Example: ${0} ubuntu-16.04-server-cloudimg-armhf-vmlinuz-lpae ubuntu-16.04-server-cloudimg-armhf-disk1.img cloudinit.img tap0" >&2
    exit 2
fi

kernel=$1
disk=$2
cloudinit=$3
interface=$4
memory=1024
monitor=$(shuf -i 25000-65535 -n 1)

if [ ! -s $kernel -o ! -s $cloudinit -o ! -s $disk ];then
    echo "Make sure kernel and disk files exist" >&2
    exit 2
fi

if ! $(ls /sys/class/net/|grep -q $interface);then
    echo "Interface ${interface} not found" >&2
    exit 2
fi

while $(cat /proc/net/tcp|awk '{print $2}'|grep -qi "$(printf '%x' $monitor)");do
    monitor=$(shuf -i 25000-65535 -n 1)
done

echo "Starting monitor on TCP port ${monitor}"

qemu-system-arm \
    -kernel $kernel \
    -append "root=/dev/vda1 rootfstype=ext4 raid=noautodetect" \
    -no-reboot \
    -nographic \
    -m $memory \
    -M virt \
    -monitor telnet:127.0.0.1:$monitor,server,nowait \
    -net nic \
    -net tap,ifname=$interface,script=no,downscript=no \
    -drive if=none,file=$disk,id=hd0 \
    -device virtio-blk-device,drive=hd0 \
    -serial stdio \
    -cdrom $cloudinit
