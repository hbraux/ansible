#!/bin/bash

function _help {
echo "$SERVER_INFO


"
}

function _setup {
  [[ -f .setup ]] && return
  sed (i -e "s/nifi.web.http.host=/nifi.web.http.host=xx/" conf/nifi.properties
  touch .setup
}


function _start {
  _setup
  exec bin/nifi.sh run
}

export -f _help _setup _start

case $1 in
  --help)  _help;;
  --start) _start;;
  *)       exec $@;;
esac

