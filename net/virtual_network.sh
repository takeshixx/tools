#!/bin/bash
# Creates a bridge and tap interface,
# attaches the tap interface to the
# bridge and starts a dhcpd on the
# bridge interface.
set -e
set -x

# The interface which
# has access to the
# Internet.
external=enp0s25
# The name of the bridge
# interface (can be anything).
bridge=br999
tmp_dir=$(mktemp -dt qemuarm.XXXXXX)
interfaces=$(ls /sys/class/net/)
forwarding=$(sysctl -n net.ipv4.ip_forward 2>/dev/null)

# You can also supply the
# external interface via
# the command line.
if [ $# -eq 1 ];then
    external=$1
fi

if ! $(echo $interfaces|grep -q $external);then
    echo "External interface ${external} not found" >&2
    exit 2
fi

if ! $(echo $interfaces|grep -q $bridge);then
    echo "Bridge interface ${bridge} not found"
    sudo ip link add $bridge type bridge
    echo "Bridge interface ${bridge} created"
fi
sudo ip link set up dev $bridge

bridge_addr=$(ip addr show $bridge|grep "inet\b"|awk '{print $2}'|cut -d/ -f1)
if [ -z $bridge_addr ];then
    echo "Bridge address not set"
    sudo ip addr add 192.168.123.1/24 dev $bridge
    echo "IP address set on ${bridge}"
fi

echo "Checking dhcpd"
bridge_dhcpd=$(ps aux | grep "dhcpd") 
echo "got: ${bridge_dhcpd}"
if ! $(sudo ps aux|grep dhcpd|grep $bridge);then
    echo "dhcpd not running on ${bridge}"
    cat <<-EOF > $tmp_dir/dhcpd.conf
	subnet 192.168.123.0 netmask 255.255.255.0 {
	    range 192.168.123.10 192.168.123.100;
	    option routers 192.168.123.1;
	    option domain-name-servers 8.8.8.8, 8.8.4.4;
	}
	EOF
    sudo dhcpd -cf $tmp_dir/dhcpd.conf -pf $tmp_dir/dhcpd.pid $bridge
    echo "Started dhcpd on ${bridge}"
fi

echo "Checking tap device"
tap_int=tap0
if ! $(echo $interfaces|grep -q $tap_int);then
    echo "Tap interface ${tap_int} not found"
    sudo ip tuntap add dev $tap_int mode tap
    sudo ip link set $tap_int master $bridge
fi
sudo ip link set up dev $tap_int

echo "Applying NAT rules for Internet access"
sudo sysctl net.ipv4.ip_forward=1
sudo iptables -A POSTROUTING -t nat -o $external -j MASQUERADE
sudo iptables -A FORWARD -i $bridge -o $external -j ACCEPT
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -L -t nat -nv

clear_config(){
    if [ -f $tmp_dir/dhcpd.pid ];then
        sudo pkill -F $tmp_dir/dhcpd.pid
    fi
    sudo sysctl net.ipv4.ip_forward=$forwarding
    sudo ip link delete dev $tap_int
    sudo ip link delete dev $bridge
    sudo iptables -D POSTROUTING -t nat -o $external -j MASQUERADE
    sudo iptables -D FORWARD -i $bridge -o $external -j ACCEPT
    sudo iptables -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    rm -rf $tmp_dir
}
trap clear_config EXIT TERM

echo "Press enter to roll everything back"
read
