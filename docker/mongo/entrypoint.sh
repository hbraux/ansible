#!/bin/bash

function _help {
  echo "$IMAGE_INFO

Prerequisite: create a Used Defined Network for server Name resolution; example
  docker network create --driver bridge udn

Start server (no persistence)
  docker run -d --name=mongo --network=udn -p 8080:8080 mongo start

Mongo shell:
  docker run -it --rm --network=udn mongo shell

Rest API
  http://<docker_host>:8080/

Stop server
  docker stop mongo && docker rm mongo
"
}

function _setup {
  [[ -f .setup ]] && return
  # noting to setup for Mongo DB
  touch .setup
}

function _start {
  _setup
  java -Dfile.encoding=UTF-8 -server -jar restheart.jar --fork
  exec mongod 
}

case $1 in
  help)   _help;;
  start)  _start;;
  shell)  exec mongo --host mongo;;
  *)      exec $@;;
esac


