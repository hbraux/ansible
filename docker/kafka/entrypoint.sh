#!/bin/bash

function _help {
echo "$IMAGE_INFO

Prerequisite: create a Used Defined Network for server Name resolution; example
  docker network create --driver bridge udn

Start server (no persistence)
  docker run -d --name=kafka --network=udn kafka start

Create a topic:
  docker run  -it --rm --network=udn kafka kafka-topics.sh --zookeeper kafka:2181 --create --topic topic.test --partitions 1 --replication-factor 1

Generate messages: 
  docker run  -it --rm --network=udn kafka kafka-console-producer.sh --broker-list kafka:9092 --topic topic.test
  docker run  -it --rm --network=udn kafka kafka-json.sh kafka:9092 topic.test uuid:%uuid date=%now val=%rands

Consume messages;
  docker run  -it --rm --network=udn kafka kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic topic.test --from-beginning

Stop server
  docker stop kafka && docker rm kafka
"
}

function _setup {
  [[ -f .setup ]] && return
  sed -r -i 's~^log.dirs=.*~log.dirs=/kafka/kafka-logs~' config/server.properties
  touch .setup
}
export -f _setup # testing purpose

function _setupold {
  for var in `env | egrep '^KAFKA' | grep -v 'KAFKA_VERSION'`
  do kafka_name=`echo "$var" | sed -r "s/KAFKA_(.*)=.*/\1/g" | tr '[:upper:]' '[:lower:]' | tr _ .`
   env_var=`echo "$var" | sed -r "s/(.*)=.*/\1/g"`
   if egrep -q "(^|^#)$kafka_name=" config/server.properties
   then sed -r -i "s~(^|^#)($kafka_name)=(.*)~\2=${!env_var}~g" config/server.properties 
   else echo "$kafka_name=${!env_var}" >> config/server.properties
   fi
  done
}

function _start {
  _setup
  # Starting Zookeeper
  zookeeper-server-start.sh config/zookeeper.properties &
  while ! nc -z localhost 2181;  do sleep 1; done
  # staring kafka
  exec bin/kafka-server-start.sh config/server.properties
}



case $1 in
  help)  _help;;
  start) _start;;
  *)     exec $@;;
esac

