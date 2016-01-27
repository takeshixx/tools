#!/bin/sh
# Start a SSL/TLS listener with random keys/certs.
# Can be used with socat, ncat (Nmap) and s_server (OpenSSL).

# Enable debug output
#set -x

if [ "$#" -ne 2 ]; then
	echo "${0} [listen_addr] [listen_port]"
	exit 1
fi

LISTEN_ADDR=$1
LISTEN_PORT=$2
TMPDIR=$(mktemp -dt temptls.XXXXXX)
trap "rm -rf '$TMPDIR'" EXIT TERM

rsa_key_size=2048
ca_name=ca
ca_key="${TMPDIR}/${ca_name}.key"
ca_key_pub="${TMPDIR}/${ca_name}_pub.key"
ca_cert="${TMPDIR}/${ca_name}.cert"
ca_subject="/O=TESTORG/OU=TESTOU/CN=testca.com"
ca_serial="${TMPDIR}/file.srl"
server_name=testserver
server_key="${TMPDIR}/${server_name}.key"
server_key_pub="${TMPDIR}/${server_name}_pub.key"
server_cert="${TMPDIR}/${server_name}.cert"
server_pem="${TMPDIR}/${server_name}.pem"
server_csr="${TMPDIR}/${server_name}.csr"
server_subject="/C=DE/O=TESTORG/OU=TESTOU/CN=testserver.com"

gen_ca(){
	echo 00 > $ca_serial
	openssl req -out $ca_cert -keyout $ca_key -nodes -new -newkey "rsa:${rsa_key_size}" -x509 -subj $ca_subject >/dev/null 2>&1
	openssl rsa -in $ca_key -pubout -out $ca_key_pub >/dev/null 2>&1
}

gen_server_rsa(){
	openssl genrsa -out $server_key $key_size >/dev/null 2>&1
	openssl rsa -in $server_key -pubout -out $server_key_pub >/dev/null 2>&1
	openssl req -key $server_key -new -out $server_csr -subj $server_subject >/dev/null 2>&1
	openssl x509 -req -extensions v3_req -CA $ca_cert -CAkey $ca_key -CAserial $ca_serial -in $server_csr -out $server_cert >/dev/null 2>&1
	cat $server_key > $server_pem
	cat $server_cert >> $server_pem
}

listen_socat(){
    if ! which socat >/dev/null;then
        echo "socat not found"
        exit 1
    fi
	listen_addr=$1
	listen_port=$2
	socat -d -d OPENSSL-LISTEN:$listen_port,bind=$listen_addr,reuseaddr,fork,cert=$server_pem,cafile=$ca_cert,verify=0 STDOUT
}

listen_ncat(){
	if ! which ncat >/dev/null;then
        echo "ncat not found"
        exit 1
    fi
	listen_addr=$1
	listen_port=$2
	ncat -v -l --ssl --ssl-cert $server_cert --ssl-key $server_key $listen_addr $listen_port
}

listen_s_server(){
	listen_addr=$1
	listen_port=$2
	openssl s_server -cert $server_pem -CAfile $ca_cert -accept $listen_port
}

main(){
	if ! which openssl >/dev/null;then
        echo "openssl not found"
        exit 1
    fi

	gen_ca
	gen_server_rsa
	listen_socat $LISTEN_ADDR $LISTEN_PORT
	#listen_ncat $LISTEN_ADDR $LISTEN_PORT
	#listen_s_server $LISTEN_ADDR $LISTEN_PORT
}

main