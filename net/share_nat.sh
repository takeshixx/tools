#!/bin/sh
# Share external connections with internal systems (e.g. share
# an Internet connection via a second network interface).
if [ "$(id -u)" != 0 ]; then
	echo "You need root privileges to run this script!"
	exit 1
fi
if [ "$#" -ne 2 ]; then
	echo "${0} [internal] [external]"
	exit 1
fi
if ! which iptables >/dev/null;then
    echo "iptables not found!"
	exit 1
fi

IF_INTERNAL=$1
IF_EXTERNAL=$2
sysctl net.ipv4.ip_forward=1
iptables -A POSTROUTING -t nat -o "$IF_EXTERNAL" -j MASQUERADE
iptables -A FORWARD -i "$IF_INTERNAL" -o "$IF_EXTERNAL" -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -L -t nat -nv

echo "Press ENTER to remove the rules again..."
read -r

iptables -D POSTROUTING -t nat -o "$IF_EXTERNAL" -j MASQUERADE
iptables -D FORWARD -i "$IF_INTERNAL" -o "$IF_EXTERNAL" -j ACCEPT
iptables -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
