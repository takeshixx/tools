// A simple webserver for quickly downloading and
// uploading files.
package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
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

func uploadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method == "GET" {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprintf(w, "%v", html_upload_form)
	} else {
		r.ParseMultipartForm(32 << 20)
		file, handler, err := r.FormFile("uploadfile")
		if err != nil {
			fmt.Println(err)
			return
		}
		defer file.Close()
		fmt.Fprintf(w, "%v", handler.Header)
		fileName := filepath.Base(handler.Filename)
		f, err := os.OpenFile(fileName, os.O_WRONLY|os.O_CREATE, 0666)
		if err != nil {
			fmt.Println(err)
			return
		}
		defer f.Close()
		io.Copy(f, file)
	}
}

func main() {
	rootDir := flag.String("root", ".", "root directory")
	absoluteDir, err := filepath.Abs(*rootDir)
	if err != nil {
		log.Fatal("Could not get absolute path")
		return
	}
	host := flag.String("host", "", "listening host IP (default: 0.0.0.0)")
	port := flag.Int("port", 8080, "listening port (default: 8080)")
	if *port < 1 || *port > 65535 {
		log.Fatal("Invalid port")
		return
	}
	sslCert := flag.String("ssl-cert", "", "SSL/TLS certificate")
	sslKey := flag.String("ssl-key", "", "SSL/TLS private key")
	flag.Parse()
	listeningSocket := fmt.Sprintf("%s:%d", *host, *port)
	http.HandleFunc("/upload", uploadHandler)
	http.Handle("/", http.FileServer(http.Dir(absoluteDir)))
	if *sslCert != "" {
		fmt.Println("Listening on socket: " + listeningSocket)
		log.Fatal(http.ListenAndServeTLS(listeningSocket, *sslCert, *sslKey, nil))
	} else {
		fmt.Println("Listening on socket: " + listeningSocket)
		log.Fatal(http.ListenAndServe(listeningSocket, nil))
	}
}
