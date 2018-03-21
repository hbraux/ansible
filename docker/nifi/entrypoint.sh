#!/bin/bash

function _help {
echo "$IMAGE_INFO

WARNING: this image is for testing and development purpose only. It does not
support Docker Services.

Prerequisites
- create a Used Defined Network for hostname resolution
\$ docker network create --driver bridge udn

Start server
\$ docker run -d --name=nifi -h nifi --network=udn -p 8080:8080 nifi start

Other docker run options
 -e HEAP_SIZE=xxx    to increase the Heap Size (by default $HEAP_SIZE)
 -v nifi:/data      for data persistence

Web UI
  http://nifi:8080/nifi
"
}

function _setup {
  [[ -f .setup ]] && return
  # move all repo to /data as well as flows
  sed -i -e 's~=./\([a-z]*\)_repository~=/data/\1_repository~g' conf/nifi.properties
  sed -i -e 's~=./conf/flow.xml.gz~=/data/conf/flow.xml.gz~' conf/nifi.properties
  HEAP_SIZE=${HEAP_SIZE:-512m}
  sed -i -e "s/java.arg.2=-Xms.*/java.arg.2=-Xms${HEAP_SIZE}/" conf/bootstrap.conf
  sed -i -e "s/java.arg.3=-Xmx.*/java.arg.3=-Xmx${HEAP_SIZE}/" conf/bootstrap.conf
  touch .setup
}
export -f _setup #debug

function _start {
  _setup
  exec nifi.sh run
}

case $1 in
  help)  _help;;
  start) _start;;
  *)       exec $@;;
esac

