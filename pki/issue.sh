#!/usr/bin/env bash
# Issue a server certificate from the lab issuing CA.
#   ./pki/issue.sh <name> <dns-name> [<dns-name>...]
# Writes certs/<name>/key.pem, leaf.pem and fullchain.pem (leaf + issuing CA).
#
# Defaults are the good choices. The environment variables below exist only so that
# setup.sh can plant faults; you should not need them.
#   KEY=ec       ECDSA P-256 (default) | KEY=rsa:<bits>
#   MD=sha256    signature hash
#   CN=<name>    subject CN (default: the first DNS name)
#   DAYS=90      validity
set -euo pipefail

[ $# -ge 2 ] || { echo "usage: $0 <name> <dns-name> [<dns-name>...]" >&2; exit 1; }
cd "$(dirname "$0")/.."
name=$1; shift
KEY=${KEY:-ec} MD=${MD:-sha256} CN=${CN:-$1} DAYS=${DAYS:-90}
out=certs/$name
mkdir -p "$out"

case $KEY in
  ec)    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$out/key.pem" ;;
  rsa:*) openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:"${KEY#rsa:}" -out "$out/key.pem" ;;
  *)     echo "unknown KEY=$KEY" >&2; exit 1 ;;
esac

san=$(printf 'DNS:%s,' "$@"); san=${san%,}
openssl req -new -key "$out/key.pem" -subj "/CN=$CN" -out "$out/req.csr"
openssl x509 -req -in "$out/req.csr" -CA pki/int.pem -CAkey pki/int.key \
  -"$MD" -days "$DAYS" -out "$out/leaf.pem" -extfile <(printf '%s\n' \
    "basicConstraints = critical, CA:FALSE" \
    "keyUsage = critical, digitalSignature, keyEncipherment" \
    "extendedKeyUsage = serverAuth" \
    "subjectAltName = $san")
rm -f "$out/req.csr"
cat "$out/leaf.pem" pki/int.pem > "$out/fullchain.pem"
chmod 644 "$out"/*.pem   # nginx in the container must read the key: lab only
echo "issued $out/leaf.pem for: $*"
