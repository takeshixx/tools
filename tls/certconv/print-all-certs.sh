#!/bin/bash
if [ $# -ne 1 ];then
    echo "Usage: $0 [certs.pem]"
    exit 1
fi
openssl crl2pkcs7 -nocrl -certfile $1 | openssl pkcs7 -print_certs -text -noout
