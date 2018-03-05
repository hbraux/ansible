#!/bin/bash

function _help {
echo "$IMAGE_INFO

Prerequisite: create a Used Defined Network for server Name resolution; example
  docker network create --driver bridge udn

Start server (no persistence)
  docker run -d --name=nifi -h <docker_host> --network=udn -p 8080:8080 nifi start

Web UI
  http://<docker_host>:8080/nifi

Stop server
  docker stop nifi && docker rm nifi
"
}

function _setup {
  [[ -f .setup ]] && return
  # move all repo to /opt/nifi/data as well as flows
  sed -i -e 's~=./\([a-z]*\)_repository~=/opt/nifi/data/\1_repository~g' conf/nifi.properties
  sed -i -e 's~=./conf/flow.xml.gz~=/opt/nifi/data/conf/flow.xml.gz~' conf/nifi.properties
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

