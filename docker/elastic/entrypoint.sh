#!/bin/bash

function _help {
  echo "$IMAGE_INFO

WARNING: this image is for testing and development purpose only. It does not
support Docker Services. For production use official image from
https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html

Prerequisites
- create a Used Defined Network for hostname resolution
\$ docker network create --driver bridge udn

Start server
\$ docker run -d --name=elastic --network=udn -p 9200:9200 elastic start

Other docker run options
 -e HEAP_SIZE=xxx    to increase the Heap Size (by default 128m) 
 -v elastic:/data    for data persistence

Set default shards to 1 and replicas to 0 (recommended before use)
\$  docker run -it --rm --network=udn elastic curl -XPUT http://elastic:9200/_template/all -d '{\"template\":\"*\",\"settings\":{\"number_of_shards\":1,\"number_of_replicas\":0}}'

Rest API
  http://elastic:9200/
"
}

function _setup {
  [[ -f .setup ]] && return
  HEAP_SIZE=${HEAP_SIZE:-128m}
  sed -r -i "s/(^-Xms.*)/-Xms${HEAP_SIZE}/" config/jvm.options
  sed -r -i "s/(^-Xmx.*)/-Xmx${HEAP_SIZE}/" config/jvm.options
  # starting Elastic in production mode for connectivity purpose (https://www.elastic.co/guide/en/elasticsearch/reference/5.2/bootstrap-checks.html#_development_vs_production_mode)
  cat>>config/elasticsearch.yml <<EOF
cluster.name: $CLUSTER_NAME
path.data: /data
network.host: [_eth0_]
EOF
  touch .setup
}
export -f _setup # testing

function _start {
  _setup
  exec elasticsearch
}


case $1 in
  help)  _help;;
  start) _start;;
  *)       exec $@;;
esac

