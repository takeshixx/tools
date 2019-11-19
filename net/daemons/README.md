# Network Daemons

A collection of scripts and commands to easily spawn network daemons for different protocols.

## FTP Server

A simple FTP server with anonymous login with Twisted. Shares the current directory via FTP.

```bash
sudo twistd3 -n ftp -p 21 -r .
```

## [http_connect_proxy.py](http_connect_proxy.py)

```bash
pip install twisted
python http_connect_proxy.py 8080
```

## [http_server.go](http_server.go)

A simple webserver for sharing (dir listing) and uploading files. It is meant to be easily extendable.

Building for Linux:

```bash
go build -o http_server http_server.go
```

Building for Windows:

```bash
GOOS=windows GOARCH=386 go build -o http_server http_server.go
```
