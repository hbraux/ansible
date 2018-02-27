#!/bin/bash

echo "$SERVER_INFO"

function _help {
echo "Commands in interactive mode (examples):
  kafka-topics.sh --zookeeper $SERVER_NAME:2181 --create --topic topic.test --partitions 1 --replication-factor 1
  kafka-console-producer.sh --broker-list $SERVER_NAME:9092 --topic topic.test
  kafka-console-consumer.sh --bootstrap-server $SERVER_NAME:9092 --topic topic.test --from-beginning
  kafka-json.sh $SERVER_NAME:9092 topic.test uuid:%uuid date=%now val=%rands

"
}

function _setup {
  [[ -f .setup ]] && return
  sed -r -i 's~^log.dirs=.*~log.dirs=/kafka/kafka-logs~' config/server.properties
  touch .setup
}

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

export -f _help _setup _start

case $1 in
  --help)  _help;;
  --start) _start;;
  *)       exec $@;;
esac

