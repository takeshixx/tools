#!/bin/sh

set -x

if [ $# -lt 2 ]; then
    echo "${0} [host] [port]"
    exit 1
fi

${$2:=443}

TARGET_ADDR=$1
TARGET_PORT=$2

if ! which openssl >/dev/null;then
    echo "openssl not found"
    exit 1
fi

openssl s_client -showcerts -connect "${TARGET_ADDR}:${TARGET_PORT}" </dev/null
