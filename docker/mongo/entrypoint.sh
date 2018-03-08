#!/bin/bash

function _help {
  echo "$IMAGE_INFO

WARNING: this image is for testing and development purpose only. It does not
support Docker Services.

Prerequisites
- create a Used Defined Network for hostname resolution
\$ docker network create --driver bridge udn

Start server
\$ docker run -d --name=mongo --network=udn -p 27000:27000 mongo start

Other docker run options
  -v mongo:/data      for data persistence

Mongo shell:
\$ docker run -it --rm --network=udn mongo shell

Rest API (Restheart)
  http://mongo:27000/
"
}

function _setup {
  [[ -f .setup ]] && return
  (cat>etc/rest.yml)<<EOF
http-listener: true
http-port: 27000
https-listener: false
connection-options:
    MAX_HEADER_SIZE: 104857
EOF
  touch .setup
}
export -f _setup

function _start {
  _setup
  java -Dfile.encoding=UTF-8 -server -jar restheart.jar etc/rest.yml --fork
  exec mongod 
}

case $1 in
  help)   _help;;
  start)  _start;;
  shell)  exec mongo --host mongo;;
  *)      exec $@;;
esac


