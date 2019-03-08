#!/bin/bash
# Temporarily block all outgoing traffic
# on a given interface. Useful for passive
# netowkr analysis.
if [ $# -nq 1 ];then
    echo "Usage: ${0} [interface]"
fi

interface=$1
all_interfaces=$(ls /sys/class/net/)

if ! $(echo $all_interfaces|grep -q $interface);then
    echo "Interface ${interface} not found" >&2
    exit 2
fi

exit(){
    iptables -D OUTPUT -o $interface -j DROP
}

trap "exit" EXIT TERM

iptables -I OUTPUT -o $interface -j DROP
echo "Press ENTER or CTRL+C to stop this script."
read
