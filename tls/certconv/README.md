# Certificate Conversion Tools

## [pem-pkcs12.sh](pem-pkcs12.sh)

Convert PEM encoded certificates and private keys to PKCS#12 format.

## [print-all-certs.sh](print-all-certs.sh)

Prints all certificates from a given file. This is useful, e.g., when a SSL/TLS service returns the full certificate chain (server, intermediate, root or even more certificates). Certificates should be in PEM format. This can be combined with the [get_cert.sh](../get_cert.sh) script on `zsh`:

```bash
print-all-certs.sh =(get_cert.sh google.com 443)
```
