#!/usr/bin/env bash
# A easy-to-use proxychains wrapper.
set -e
script=${0##*/}

if [ $# -lt 3 ];then
    echo "Usage: ${script} <type> <proxy> <port> <command>" >&2
    echo "Example: ${script} http 127.0.0.1 8080 curl ipinfo.io" >&2
    exit 2
fi

if ! which proxychains >/dev/null;then
    echo "proxychains not found" >&2
    exit 2
fi

proxy_type=$1
proxy_host=$2
proxy_port=$3
shift
shift
shift
command=$*
tmpdir=$(mktemp -dt proxy.XXXXXX)
trap "rm -rf $tmpdir" EXIT TERM
config="${tmpdir}/proxychains.conf"
ip_regex="[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"

if [ "$proxy_type" != "socks4" -a "$proxy_type" != "socks4a" \
    -a "$proxy_type" != "socks5" -a "$proxy_type" != "http" ];then
    echo "Invalid proxy type ${proxy_type}" >&2
    exit 2
fi

if ! echo $proxy_host | grep -Eq $ip_regex;then
    # If proxy_host is not a valid IP address, try to resolve it.
    proxy_host=$(host $proxy_host | awk '/has address/ {print $4}')
fi

if [ -z $proxy_host ];then
    # If proxy host is not a valid IP
    # and it could not be resolved,
    # it's not valid for proxychains.
    echo "Could not resolve proxy host" >&2
    exit 2
fi

cat <<EOF > $config
strict_chain
quiet_mode
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
[ProxyList]
${proxy_type} ${proxy_host} ${proxy_port}
EOF

proxychains -q -f $config $command 
