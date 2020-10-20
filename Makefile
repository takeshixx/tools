go_netcat:
	go build -o ./bin/gonc net/go_netcat.go

http_server:
	go build -o ./bin/http_server net/daemons/http_server.go

clean:
	rm -rf bin/