#!/bin/bash
# Boot a Raspberry Pi 2 Ubuntu VM on QEMU
if [ $# -lt 5 ];then
    echo "Usage: ${0} <kernel> <initrd> <dtb> <disk> <interface>" >&2
    echo "Example: ${0} vmlinuz initrd.img bcm2709-rpi-2-b.dtb ubuntu.img tap0" >&2
    exit 2
fi

kernel=$1
initrd=$2
dtb=$3
disk=$4
interface=$5
memory=1024
monitor=$(shuf -i 25000-65535 -n 1)

if [ ! -s $kernel -o ! -s $initrd -o ! -s $disk -o ! -s $dtb ];then
    echo "Make sure kernel, initrd, dtb and disk files exist" >&2
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
    -append "console=ttyAMA0,115200 root=/dev/mmcblk0p2" \
    -no-reboot \
    -nographic \
    -m $memory \
    -M raspi2 \
    -monitor telnet:127.0.0.1:$monitor,server,nowait \
    -drive format=raw,file=$disk \
    -serial stdio \
    -dtb $dtb \
    -net nic \
    -net tap,ifname=$interface,script=no,downscript=no
