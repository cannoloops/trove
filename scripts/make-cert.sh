#!/bin/zsh
# Crea (una volta) un'identità di code signing self-signed nel login keychain,
# così il permesso Accessibilità resta valido tra una build e l'altra.
set -euo pipefail
NAME="Trove Local Signing"
security find-identity -v -p codesigning | grep -q "$NAME" && { echo "Identità già presente"; exit 0; }
T=$(mktemp -d); trap 'rm -rf $T' EXIT
cat > $T/cfg <<CFG
[req]
distinguished_name=dn
prompt=no
[dn]
CN=$NAME
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
CFG
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -keyout $T/k.pem -out $T/c.pem -config $T/cfg -extensions ext 2>/dev/null
openssl pkcs12 -export -legacy -inkey $T/k.pem -in $T/c.pem -out $T/id.p12 -passout pass:trove 2>/dev/null \
  || openssl pkcs12 -export -inkey $T/k.pem -in $T/c.pem -out $T/id.p12 -passout pass:trove
KC=~/Library/Keychains/login.keychain-db
security import $T/id.p12 -k $KC -P trove -T /usr/bin/codesign
security add-trusted-cert -r trustRoot -p codeSign -k $KC $T/c.pem
security find-identity -v -p codesigning | grep "$NAME"
