.PHONY: all
all: go_netcat http_server

.PHONY: go_netcat
go_netcat:
	go build -o ./bin/gonc net/go_netcat.go

.PHONY: http_server
http_server:
	go build -o ./bin/http_server net/daemons/http_server.go

.PHONY: clean
clean:
	rm -rf bin/
