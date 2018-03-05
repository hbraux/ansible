#!/bin/bash

function _help {
  echo "$IMAGE_INFO

Start server (no persistence)
  docker run -d --name=elastic -p 9200:9200 elastic start

Rest API
  http://<docker_host>:9200/

Stop server
  docker stop elastic && docker rm elastic

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
export -f _setup # testing

function _start {
  _setup
  # reducing HEAP memory (2g by default) for a test cluster
  export ES_JAVA_OPTS="-Xms512m -Xmx512m"
  exec elasticsearch
}


case $1 in
  help)  _help;;
  start) _start;;
  *)       exec $@;;
esac

