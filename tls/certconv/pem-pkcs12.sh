#!/bin/bash
if [ $# -ne 3 ];then
    echo "Usage: $0 cert.pem key.pem out.pkcs12"
    exit 1
fi
openssl pkcs12 -export -in $1 -inkey $2 -out $3
