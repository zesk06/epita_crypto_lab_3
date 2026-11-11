#!/usr/bin/env bash
# Build the lab PKI and the certificates of the six servers. Run once, before
# `docker compose up -d`. Running it again starts from scratch (new CA, new certificates).
set -euo pipefail
cd "$(dirname "$0")"

command -v openssl >/dev/null || { echo "openssl not found" >&2; exit 1; }
rm -rf certs pki/*.pem pki/*.key pki/*.srl lab-ca.pem

# Root CA (offline in real life) and issuing CA, as in Lab 4
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-384 -out pki/root.key
openssl req -x509 -new -key pki/root.key -sha384 -days 3650 -out pki/root.pem \
  -subj "/O=EPITA Lab/CN=EPITA Lab Root CA" \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign"
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-384 -out pki/int.key
openssl req -new -key pki/int.key -subj "/O=EPITA Lab/CN=EPITA Lab Issuing CA" -out pki/int.csr
openssl x509 -req -in pki/int.csr -CA pki/root.pem -CAkey pki/root.key -sha384 -days 1825 \
  -out pki/int.pem -extfile <(printf '%s\n' \
    "basicConstraints = critical, CA:TRUE, pathlen:0" \
    "keyUsage = critical, keyCertSign, cRLSign")
rm -f pki/int.csr
cp pki/root.pem lab-ca.pem

# One certificate per server
KEY=rsa:2048 ./pki/issue.sh legacy legacy.lab.test
./pki/issue.sh chain chain.lab.test
CN=names.lab.test ./pki/issue.sh names www.names.lab.test
KEY=rsa:1024 MD=sha1 ./pki/issue.sh weak weak.lab.test
./pki/issue.sh order order.lab.test
cat certs/order/leaf.pem pki/root.pem pki/int.pem > certs/order/served.pem
./pki/issue.sh app app.lab.test
./pki/issue.sh www www.lab.test

echo
echo "Done. Trust anchor: lab-ca.pem. Next: docker compose up -d"
