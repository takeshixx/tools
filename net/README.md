# Network Utils

## [be_silent.sh](be_silent.sh)

Temporarily block all outgoing traffic on a given interface. Useful for passive network analysis.

## [go_netcat.go](go_netcat.go)

A simple netcat implemantion in Golang that is meant to be easily extendable.

Building for Linux:

```bash
go build -o gonc go_netcat.go
```

Building for Windows:

```bash
GOOS=windows GOARCH=386 go build -o gonc go_netcat.go
```

## [observe.py](observe.py)

Print packets from a specific IP/MAC on a given interface or a pcap file. Useful to see only packets from a specific host.

## [proxy.sh](proxy.sh)

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

## [share_nat.sh](share_nat.sh)

Easily share the Internet connection with other interfaces/devices via iptables rules. Useful for e. g. Man-in-the-Middle scenarios or Qemu VMs.

## [sshd.sh](sshd.sh)

Spawns a sshd on a specific port with a predefined private key for authentication. Can be used e.g. for reverse-ssh-connect scenarios.

## [sshd.ps1](sshd.ps1)

Windows port of `sshd.sh` which utilizes the OpenSSH port for Win32.

## [tcp_http_proxy.py](tcp_http_proxy.py)

Forward TCP traffic from a host over a HTTP proxy.

## [virtual_network.sh](virtual_network.sh)

Creates a bridge and tap interface and attaches the tap interface to the bridge. Then assigns a local IP address on the bridge, starts a dhcpd and applies several iptables rules to provide Internet access for the tap device. This can be useful e.g. for providing networking for QEMU VMs.
