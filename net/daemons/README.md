# Network Daemons

A collection of scripts and commands to easily spawn network daemons for different protocols.

## [http_connect_proxy.py](http_connect_proxy.py)

```bash
pip install twisted
python http_connect_proxy.py 8080
```

## FTP Server

A simple FTP server with anonymous login with Twisted. Shares the current directory via FTP.

```bash
sudo twistd3 -n ftp -p 21 -r .
```