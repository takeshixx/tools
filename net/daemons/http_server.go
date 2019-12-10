// A simple webserver for quickly downloading and
// uploading files.
package main

import (
	"crypto/subtle"
	"flag"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

const html_upload_form = `<html>
    <head>
    <title></title>
    </head>
    <body>
		<form method="post" enctype="multipart/form-data">
			<input name="uploadfile" type="file" size="50"> 
			</label>  
			<button>Upload</button>
		</form>
    </body>
</html>`

var seededRand *rand.Rand = rand.New(rand.NewSource(time.Now().UnixNano()))

func randomString(length int) string {
	charset := "abcdefghijklmnopqrstuvwxyz" +
		"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[seededRand.Intn(len(charset))]
	}
	return string(b)
}

func httpBasicAuth(handler http.HandlerFunc, username, password, realm string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		user, pass, ok := r.BasicAuth()
		if !ok || subtle.ConstantTimeCompare([]byte(user), []byte(username)) != 1 || subtle.ConstantTimeCompare([]byte(pass), []byte(password)) != 1 {
			w.Header().Set("WWW-Authenticate", `Basic realm="`+realm+`"`)
			w.WriteHeader(401)
			w.Write([]byte("Unauthorized.\n"))
			return
		}
		handler(w, r)
	}
}

func handlerAuthWrapper(h http.Handler, user string, pass string, realm string) http.Handler {
	return httpBasicAuth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h.ServeHTTP(w, r)
	}), user, pass, realm)
}

func uploadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method == "GET" {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprintf(w, "%v", html_upload_form)
	} else {
		r.ParseMultipartForm(32 << 20)
		file, handler, err := r.FormFile("uploadfile")
		if err != nil {
			log.Println(err)
			return
		}
		defer file.Close()
		fmt.Fprintf(w, "%v", handler.Header)
		fileName := filepath.Base(handler.Filename)
		f, err := os.OpenFile(fileName, os.O_WRONLY|os.O_CREATE, 0666)
		if err != nil {
			log.Println(err)
			return
		}
		defer f.Close()
		io.Copy(f, file)
	}
}

func stdio_handle(con net.Conn) {
	chan_to_stdout := stream_copy(con, os.Stdout)
	chan_to_remote := stream_copy(os.Stdin, con)
	select {
	case <-chan_to_stdout:
		log.Println("Remote connection is closed")
	case <-chan_to_remote:
		log.Println("Local program is terminated")
	}
}

func stream_copy(src io.Reader, dst io.Writer) <-chan int {
	buf := make([]byte, 1024)
	sync_channel := make(chan int)
	go func() {
		defer func() {
			if con, ok := dst.(net.Conn); ok {
				con.Close()
				log.Printf("Connection from %v is closed\n", con.RemoteAddr())
			}
			sync_channel <- 0 // Notify that processing is finished
		}()
		for {
			var nBytes int
			var err error
			nBytes, err = src.Read(buf)
			if err != nil {
				if err != io.EOF {
					log.Printf("Read error: %s\n", err)
				}
				break
			}
			_, err = dst.Write(buf[0:nBytes])
			if err != nil {
				log.Fatalf("Write error: %s\n", err)
			}
		}
	}()
	return sync_channel
}

func main() {
	rootDir := flag.String("root", ".", "root directory")
	absoluteDir, err := filepath.Abs(*rootDir)
	if err != nil {
		log.Fatal("Could not get absolute path")
		return
	}
	host := flag.String("host", "0.0.0.0", "listening host IP")
	port := flag.Int("port", 8080, "listening port")
	if *port < 1 || *port > 65535 {
		log.Fatal("Invalid port")
		return
	}
	randPassword := randomString(8)
	sslCert := flag.String("ssl-cert", "", "SSL/TLS certificate")
	sslKey := flag.String("ssl-key", "", "SSL/TLS private key")
	authUser := flag.String("auth-user", "operator", "HTTP Basic Authentication user name")
	authPass := flag.String("auth-pass", randPassword, "HTTP Basic Authentication password")
	authBypass := flag.Bool("no-auth", false, "do not enforce authentication")
	unixSocket := flag.Bool("unix", false, "use a Unix socket instead of TCP")
	flag.Parse()
	listeningSocket := fmt.Sprintf("%s:%d", *host, *port)
	if !*authBypass {
		if *authPass == randPassword {
			log.Printf("Authentication data: %s:%s\n", *authUser, *authPass)
		}
		http.HandleFunc("/upload", httpBasicAuth(uploadHandler, *authUser, *authPass, "Please provide login credentials"))
		http.Handle("/", handlerAuthWrapper(http.FileServer(http.Dir(absoluteDir)), *authUser, *authPass, "Please provide login credentials"))
	} else {
		http.HandleFunc("/upload", uploadHandler)
		http.Handle("/", http.FileServer(http.Dir(absoluteDir)))
	}
	if *unixSocket {
		log.Println("Using Unix socket")
		if _, err := os.Stat("/tmp/http_server.sock"); err == nil {
			err = os.Remove("/tmp/http_server.sock")
			if err != nil {
				log.Fatal("Could not delete existing Unix socket")
			}
		}
		unixListener, errL := net.Listen("unix", "/tmp/http_server.sock")
		if errL != nil {
			log.Fatal("Failed to create unix socket: ", errL)
		}
		defer unixListener.Close()
		http.Serve(unixListener, nil)
	} else if *sslCert != "" {
		log.Println("Listening on socket: " + listeningSocket)
		log.Fatal(http.ListenAndServeTLS(listeningSocket, *sslCert, *sslKey, nil))
	} else {
		log.Println("Listening on socket: " + listeningSocket)
		log.Fatal(http.ListenAndServe(listeningSocket, nil))
	}
}
