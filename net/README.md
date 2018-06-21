# Network Utils

## proxy.sh

A easy-to-use wrapper for proxychains because it only supports configuration via configuration files. It allows to define a proxy via command line arguments.

### Examples

In general this script makes it easy to test connections over proxies. Instead of configuring clients to use different proxies or even clients that do not support proxies, just use it like:

```bash
proxy.sh http 192.168.123.312 8080 curl myip.space
```

It can also be handy for applications that only support e.g. HTTP proxies, but you want to proxy connections over a SSH tunnel established with:

```bash
ssh -D1080 root@targetserver
```

So you can e.g. run `sqlmap.py` over this tunnel:

```bash
proxy.sh socks5 127.0.0.1 1080 python2 sqlmap.py -u "http://example.org/"
```

## share_nat.sh

Easily share the Internet connection with other interfaces/devices via iptables rules.

## sshd.sh

Spawns a sshd on a specific port with a predefined private key for authentication. Can be used e.g. for reverse-ssh-connect scenarios.

## virtual_network.sh

Creates a bridge and tap interface and attaches the tap interface to the bridge. Then assigns a local IP address on the bridge, starts a dhcpd and applies several iptables rules to provide Internet access for the tap device. This can be useful e.g. for providing networking for QEMU VMs.
