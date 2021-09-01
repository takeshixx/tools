#!/bin/bash
# This script creates three certificates:
#   * CA certificate (custom subject)
#   * server certificate (custom subject)
#   * client certificate (default subject)
# The server and client certificate can be
# used interchangeably, either as server
# or client certificate.
set -e

if [ $# -lt 1 ];then
    echo "Usage: ${0} <output> [issuer] [subject]" >&2
    exit 2
fi

out_dir="$1"
issuer="$2"
subject="$3"
key_size=2048

if [ ! -d "$out_dir" ];then
    echo "${out_dir} does not exist, will create it. Press CTRL+C to exit, RETURN to continue..."
    read
    mkdir -p "$out_dir"
fi

if [ -z "$issuer" ];then
    issuer="/O=Legit Org/CN=Legit Test CA 2018"
fi

if [ -z "$subject" ];then
    subject="/C=DE/ST=UA/L=New York/O=Legit Org/OU=Legit Management/CN=ca.legit.com"
fi

tmp_dir=$(mktemp -dt pki.XXXXXX)
trap "rm -rf $tmp_dir" EXIT TERM
echo 00 > $tmp_dir/file.srl

cp /etc/ssl/openssl.cnf $tmp_dir/openssl.cnf

# If SubjectAlternativeNames are required
echo -e "\n[ SAN ]\n\nsubjectAltName=DNS:uber.legit.com" >> $tmp_dir/openssl.cnf

# If a complete openssl.cnf is required (rename $tmp_dir/openssl.cnf.notused to $tmp_dir/openssl.cnf)
cat > $tmp_dir/openssl.cnf.notused << EOF
[ req ]
default_bits            = 2048
default_keyfile         = privkey.pem
distinguished_name      = req_distinguished_name
attributes              = req_attributes
x509_extensions         = v3_ca # The extensions to add to the self signed cert
req_extensions          = v3_req # The extensions to add to a certificate request

[ req_distinguished_name ]

countryName                     = Country Name (2 letter code)
countryName_default             = DE
countryName_min                 = 2
countryName_max                 = 2
stateOrProvinceName             = State or Province Name (full name)
stateOrProvinceName_default     = Some-State
localityName                    = Locality Name (eg, city)
0.organizationName              = Organization Name (eg, company)
0.organizationName_default      = Internet Widgits Pty Ltd
organizationalUnitName          = Organizational Unit Name (eg, section)
commonName                      = Common Name (e.g. server FQDN or YOUR name)
commonName_max                  = 64
emailAddress                    = Email Address
emailAddress_max                = 64

[ req_attributes ]

challengePassword               = A challenge password
challengePassword_min           = 4
challengePassword_max           = 20
unstructuredName                = An optional company name

[ usr_cert ]

basicConstraints=CA:FALSE
nsComment                       = "OpenSSL Generated Certificate"
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer

[ v3_req ]

basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = DNS:uber.legit.com

[ SAN ]

subjectAltName = DNS:uber.legit.com

[ v3_ca ]

subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = critical,CA:true
EOF

die(){
    echo "$@"
    exit 1
}

# Generate CA key and certificate
openssl req -nodes -new -x509 \
        -out $out_dir/ca.crt \
        -keyout $out_dir/ca.key \
        -subj "$issuer" || die "Generating CA key and certificate failed"
        
#if which keytool >/dev/null;then
#    # Generate a Java keystore with the CA certificate
#    keytool -import -trustcacerts -file $out_dir/ca.crt -alias cacert -storepass test123 -noprompt -keystore $out_dir/cacerts.jks || die "Generating Java keystore failed"
#fi

# Generate 2048 bit DH key
# Note: Some implementations do not support
# smaller keys since Logjam (https://weakdh.org/).
openssl dhparam -out $out_dir/dh.pem $key_size || die "Creating DH params failed"

# Generate server key
openssl genrsa \
        -out $out_dir/server.key \
        $key_size || die "Generating server key failed"

# Generate server CSR
echo "subject"
echo "$subject"
openssl req -new \
        -key $out_dir/server.key \
        -out $tmp_dir/server.req \
        -subj "$subject" \
        -reqexts SAN \
        -config $tmp_dir/openssl.cnf || die "Could not create server CSR"
        
# Sign server CSR
openssl x509 -req \
        -CA $out_dir/ca.crt \
        -CAkey $out_dir/ca.key \
        -CAserial $tmp_dir/file.srl \
        -in $tmp_dir/server.req \
        -extensions v3_req \
        -extensions SAN \
        -extfile $tmp_dir/openssl.cnf \
        -out $out_dir/server.crt || die "Signing server CSR failed"

# Generate server .p12 bundle
openssl pkcs12 -export -nodes \
        -inkey $out_dir/server.key \
        -in $out_dir/server.crt \
        -out $out_dir/server.p12 || die "Creating server PKCS#12 bundle failed"

cat $out_dir/server.key > $out_dir/server.pem
cat $out_dir/server.crt >> $out_dir/server.pem

# Generate client key
openssl genrsa \
        -out $out_dir/client.key \
        $key_size || die "Generating client key failed"

# Generate client CSR
openssl req -new \
        -key $out_dir/client.key \
        -out $tmp_dir/client.req || die "Generating client CSR failed"

# Sign client CSR
openssl x509 -req \
        -extensions v3_req \
        -CA $out_dir/ca.crt \
        -CAkey $out_dir/ca.key \
        -CAserial $tmp_dir/file.srl \
        -in $tmp_dir/client.req \
        -out $out_dir/client.crt || die "Signing client CSR failed"

# Generate client .p12 bundle
openssl pkcs12 -export -nodes \
        -inkey $out_dir/client.key \
        -in $out_dir/client.crt \
        -out $out_dir/client.p12 || die "Generating client PKCS#12 bundle failed"

cat $out_dir/client.key > $out_dir/client.pem
cat $out_dir/client.crt >> $out_dir/client.pem
