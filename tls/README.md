# SSL/TLS Utils

## get_cert.sh

Gets certificates from SSL/TLS enabled services via OpenSSL's s_client and prints them to stdout in a human-readable form.

## pki.sh

Generate a simple PKI with a CA certificate and a signed server certificate. The script includes an example how to set specific fields in the certificate. This can be useful for mitm-scenarios for applications that check specific attributes in certificates.

## tls_listen.sh

Opens a SSL/TLS listening por with a randomly generated (self-signed) certificate for quick testing purposes. Supports socat (default), ncat and OpenSSL's s_server.
