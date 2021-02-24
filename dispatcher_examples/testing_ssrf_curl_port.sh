#!/bin/bash
host=${1:-127.0.0.1}
port=${2:-2121}
docker run --rm curlimages/curl:7.73.0 ftp://$host:$port/ -v