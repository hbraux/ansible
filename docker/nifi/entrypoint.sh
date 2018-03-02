#!/bin/bash

function _help {
echo "$SERVER_INFO


"
}

function _setup {
  [[ -f .setup ]] && return

  touch .setup
}


function _start {
  _setup
  exec scripts/start.sh
}

export -f _help _setup _start

case $1 in
  --help)  _help;;
  --start) _start;;
  *)       exec $@;;
esac

