#!/bin/bash
# Boot a Ubuntu ARMHF netboot image VM on QEMU
if [ $# -lt 4 ];then
    echo "Usage: ${0} <kernel> <initrd> <disk> <interface>" >&2
    echo "Example: ${0} vmlinuz initrd.img ubuntu.img tap0" >&2
    exit 2
fi

kernel=$1
initrd=$2
disk=$3
interface=$4
memory=1024
monitor=$(shuf -i 25000-65535 -n 1)

if [ ! -s $kernel -o ! -s $initrd -o ! -s $disk ];then
    echo "Make sure kernel, initrd and disk files exist" >&2
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
    -initrd $initrd \
    -append "root=/dev/ram" \
    -no-reboot \
    -nographic \
    -m $memory \
    -M virt \
    -monitor telnet:127.0.0.1:$monitor,server,nowait \
    -net nic \
    -net tap,ifname=$interface,script=no,downscript=no \
    -drive file=$disk,if=virtio \
    -serial stdio 
