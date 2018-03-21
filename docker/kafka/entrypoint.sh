#!/bin/bash

function _help {
echo "$IMAGE_INFO

WARNING: this image is for testing and development purpose only. It does not
support Docker Services.

Prerequisites
- create a Used Defined Network for hostname resolution
\$ docker network create --driver bridge udn

Start server
\$ docker run -d --name=kafka --network=udn kafka start

Other docker run options
 -e HEAP_SIZE=xxx    to increase the Heap Size (by default $HEAP_SIZE)
 -v kafka:/data      for data persistence

Create a topic
\$ docker run -it --rm --network=udn kafka kafka-topics.sh --zookeeper kafka:2181 --create --topic mytopic --partitions 1 --replication-factor 1

Kafka cOnsoles
\$ docker run -it --rm --network=udn kafka kafka-console-producer.sh --broker-list kafka:9092 --topic mytopic
\$ docker run -it --rm --network=udn kafka kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic mytopic [ --from-beginning ]

JSON Message generator
\$ docker run  -it --rm --network=udn kafka kafka-json.sh kafka:9092 mytopic ..
"
}

function _setup {
  [[ -f .setup ]] && return
  sed -r -i 's~^log.dirs=.*~log.dirs=/data~' config/server.properties
  touch .setup
}
export -f _setup # testing purpose


function _start {
  _setup
  # Starting Zookeeper
  KAFKA_HEAP_OPTS="-Xmx32m -Xms32m" zookeeper-server-start.sh config/zookeeper.properties &
  while ! nc -z localhost 2181;  do sleep 1; done
  # staring kafka
  HEAP_SIZE=${HEAP_SIZE:-256m}
  export KAFKA_HEAP_OPTS="-Xmx${HEAP_SIZE} -Xms${HEAP_SIZE}" 
  exec bin/kafka-server-start.sh config/server.properties
}



case $1 in
  help)  _help;;
  start) _start;;
  *)     exec $@;;
esac

