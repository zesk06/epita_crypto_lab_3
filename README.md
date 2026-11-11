# Lab 3: fix the broken TLS servers

Part B of Lab 3 (EPITA, Applied Cryptography). Six nginx servers run on your machine. Each one has
at least one TLS fault. You get no list: find each fault from the network, fix it, and prove it.

**Done when:** `FINDINGS.md` has one section per server, with evidence before and after the fix.

## Start

Needs Docker with Compose, and OpenSSL 3.5 or later.

```bash
git clone git@github.com:zesk06/epita_crypto_lab_3.git && cd epita_crypto_lab_3
./setup.sh               # creates the lab CA (lab-ca.pem) and the server certificates
docker compose up -d     # or: docker-compose up -d
docker compose ps
```

## The servers

| Service | Port | Name(s) |
|---|---|---|
| `legacy` | 8441 | `legacy.lab.test` |
| `chain`  | 8442 | `chain.lab.test` |
| `names`  | 8443 | `names.lab.test` |
| `weak`   | 8444 | `weak.lab.test` |
| `order`  | 8445 | `order.lab.test` |
| `vhosts` | 8446 | `app.lab.test`, `www.lab.test` |

The names do not exist in DNS. Give them to the tools explicitly:

```bash
openssl s_client -connect 127.0.0.1:8441 -servername legacy.lab.test -CAfile lab-ca.pem </dev/null
curl --cacert lab-ca.pem --resolve legacy.lab.test:8441:127.0.0.1 https://legacy.lab.test:8441/
```

`lab-ca.pem` is the lab's root CA: the trust anchor for every server. It is created by `setup.sh`.

## Fixing

- Server configuration: `conf/<service>.conf`. After a change: `docker compose restart <service>`.
  If the service does not start, read `docker compose logs <service>`.
- New certificate from the lab CA: `./pki/issue.sh <service> <dns-name> [<dns-name>...]`,
  then restart the service. For `vhosts`, the certificates are `app` and `www`.
- Start again from zero: `./setup.sh && docker compose restart`.

## Rules

- Find each fault **from the network**, as an outside auditor would: `openssl`, `curl`, `testssl.sh`.
  Reading `setup.sh` or the configuration tells you nothing you can prove.
- Start with `testssl.sh` if you want (`testssl.sh --add-ca lab-ca.pem --ip 127.0.0.1 <name>:<port>`),
  then prove each finding with `openssl` or `curl`. It will not find everything.
- Every claim needs the command and its output, before and after. A testssl.sh line is not evidence.

## FINDINGS.md

One section per server:

```text
## <service>

### Evidence before
$ <the command that revealed the fault>
<the output lines that show it>

### Fault
<one line>

### Risk
<what an attacker gains, one line>

### Fix
<config diff or reissue command>

### Evidence after
$ <the same command>
<the output lines that show it is fixed>
```
