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
	"net/http/httptest"
	"net/http/httputil"
	"os"
	"path/filepath"
	"time"
)

const uploadForm = `<html>
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

func logHandler(handler http.HandlerFunc, logRespBody bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		reqData, err := httputil.DumpRequest(r, true)
		if err != nil {
			http.Error(w, fmt.Sprint(err), http.StatusInternalServerError)
			return
		}

		rec := httptest.NewRecorder()
		handler(rec, r)

		respData, err := httputil.DumpResponse(rec.Result(), logRespBody)
		if err != nil {
			http.Error(w, fmt.Sprint(err), http.StatusInternalServerError)
			return
		}

		logString := fmt.Sprintf("===REQUEST===\n%s\n===RESPONSE===\n%s", reqData, respData)
		log.Println(logString)

		// This copies the recorded response to the response writer
		for k, v := range rec.HeaderMap {
			w.Header()[k] = v
		}
		w.WriteHeader(rec.Code)
		rec.Body.WriteTo(w)
	}
}

func handlerLogWrapper(h http.Handler, logRespBody bool) http.Handler {
	return logHandler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h.ServeHTTP(w, r)
	}), logRespBody)
}

func uploadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method == "GET" {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprintf(w, "%v", uploadForm)
	} else {
		r.ParseMultipartForm(32 << 20)
		file, handler, err := r.FormFile("uploadfile")
		if err != nil {
			log.Println(err)
			return
		}
		defer file.Close()
		fileName := filepath.Base(handler.Filename)
		f, err := os.OpenFile(fileName, os.O_WRONLY|os.O_CREATE, 0666)
		if err != nil {
			log.Println(err)
			return
		}
		defer f.Close()
		io.Copy(f, file)
		fmt.Fprintf(w, "Successfully uploaded file %s (%v)", fileName, handler.Header)
		log.Printf("Uploaded file: %s\n", fileName)
	}
}

func stdioHandle(con net.Conn) {
	chanToStdout := streamCopy(con, os.Stdout)
	chanToRemote := streamCopy(os.Stdin, con)
	select {
	case <-chanToStdout:
		log.Println("Remote connection is closed")
	case <-chanToRemote:
		log.Println("Local program is terminated")
	}
}

func streamCopy(src io.Reader, dst io.Writer) <-chan int {
	buf := make([]byte, 1024)
	syncChannel := make(chan int)
	go func() {
		defer func() {
			if con, ok := dst.(net.Conn); ok {
				con.Close()
				log.Printf("Connection from %v is closed\n", con.RemoteAddr())
			}
			syncChannel <- 0 // Notify that processing is finished
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
	return syncChannel
}

func main() {
	rootDir := flag.String("root", ".", "root directory")
	host := flag.String("host", "0.0.0.0", "listening host IP")
	port := flag.Int("port", 8080, "listening port")
	randPassword := randomString(8)
	sslCert := flag.String("ssl-cert", "", "SSL/TLS certificate")
	sslKey := flag.String("ssl-key", "", "SSL/TLS private key")
	authUser := flag.String("auth-user", "operator", "HTTP Basic Authentication user name")
	authPass := flag.String("auth-pass", randPassword, "HTTP Basic Authentication password")
	authBypass := flag.Bool("no-auth", false, "do not enforce authentication")
	unixSocket := flag.Bool("unix", false, "use a Unix socket instead of TCP")
	logTraffic := flag.Bool("log", false, "log requests/responses")
	logRespBody := flag.Bool("log-resp-body", false, "log response bodies as well (could contain binary data)")
	flag.Parse()

	absoluteDir, err := filepath.Abs(*rootDir)
	if err != nil {
		log.Fatal("Could not get absolute path")
		return
	}
	log.Printf("Using root directory: %s\n", absoluteDir)
	if *port < 1 || *port > 65535 {
		log.Fatal("Invalid port")
		return
	}
	listeningSocket := fmt.Sprintf("%s:%d", *host, *port)
	if !*authBypass {
		if *authPass == randPassword {
			log.Printf("Authentication data: %s:%s\n", *authUser, *authPass)
			log.Printf("Authenticated URL: http")
		}
		if *logTraffic {
			http.HandleFunc("/upload", logHandler(httpBasicAuth(uploadHandler, *authUser, *authPass, "Please provide login credentials"), *logRespBody))
			http.Handle("/", handlerLogWrapper(handlerAuthWrapper(http.FileServer(http.Dir(absoluteDir)), *authUser, *authPass, "Please provide login credentials"), *logRespBody))
		} else {
			http.HandleFunc("/upload", httpBasicAuth(uploadHandler, *authUser, *authPass, "Please provide login credentials"))
			http.Handle("/", handlerAuthWrapper(http.FileServer(http.Dir(absoluteDir)), *authUser, *authPass, "Please provide login credentials"))
		}
	} else {
		if *logTraffic {
			http.HandleFunc("/upload", logHandler(uploadHandler, *logRespBody))
			http.Handle("/", handlerLogWrapper(http.FileServer(http.Dir(absoluteDir)), *logRespBody))
		} else {
			http.HandleFunc("/upload", uploadHandler)
			http.Handle("/", http.FileServer(http.Dir(absoluteDir)))
		}
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
