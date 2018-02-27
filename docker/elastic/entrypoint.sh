#!/bin/bash

function _help {
  echo "$SERVER_INFO
Commands in interactive mode (examples):
  curl -s -XGET http://$SERVER_NAME:9200
"
}

function _setup {
  [[ -f .setup ]] && return
  sed -r -i "s/(^-Xms.*)//" config/jvm.options
  sed -r -i "s/(^-Xmx.*)//" config/jvm.options
  # starting Elastic in production mode (https://www.elastic.co/guide/en/elasticsearch/reference/5.2/bootstrap-checks.html#_development_vs_production_mode)
  echo "network.host: [_eth0_]" >> config/elasticsearch.yml
  touch .setup
}

function _start {
  _setup
  # reducing HEAP memory (2g by default) for a test cluster
  export ES_JAVA_OPTS="-Xms512m -Xmx512m"
  exec elasticsearch
}

export -f _help _setup _start

case $1 in
  --help)  _help;;
  --start) _start;;
  *)       exec $@;;
esac

