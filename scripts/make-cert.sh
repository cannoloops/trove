#!/bin/zsh
# Crea (una volta) un'identità di code signing self-signed in un keychain dedicato (trove-signing),
# così il permesso Accessibilità resta valido tra le build e codesign non chiede conferme.
set -euo pipefail
NAME="Trove Local Signing"
KC=~/Library/Keychains/trove-signing.keychain-db
KPW=trove-local
if security find-identity -p codesigning $KC 2>/dev/null | grep -q "$NAME"; then
  security unlock-keychain -p $KPW $KC
  exit 0
fi
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
[[ -f $KC ]] || security create-keychain -p $KPW $KC
security set-keychain-settings $KC   # niente auto-lock
security unlock-keychain -p $KPW $KC
security import $T/id.p12 -k $KC -P trove -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k $KPW $KC >/dev/null
security list-keychains -d user -s $(security list-keychains -d user | tr -d '"') $KC
security find-identity -p codesigning $KC | grep "$NAME"
