#!/bin/bash

if [[ $1 == about ]]
then [[ -n $ABOUT ]] && echo $ABOUT
echo "
Commands supported in interactive mode (samples)
 kafka-topics.sh --zookeeper kafka:2181 --create --topic test --partitions 1 --replication-factor 1
 kafka-console-producer.sh --broker-list kafka:9092 --topic test 
 kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic test --from-beginning
"
  exit
fi

# start kafka
if [[ $1 == *kafka-server-start.sh && "$2" == *server.properties ]]
then
    
KAFKA_BROKER_ID=${KAFKA_BROKER_ID:-1}
KAFKA_PORT=${KAFKA_PORT:-9092}
KAFKA_LOG_DIRS="/kafka/kafka-logs-$HOSTNAME"

# Starting Zookeeper
zookeeper-server-start.sh config/zookeeper.properties &
# wait for zookeeper to be ready
while ! nc -z localhost 2181
do sleep 1
done

# this script updates config/server.properties based on environment variables starting by KAFKA_xxx (skipping)

for VAR in `env |grep ignored`
do
  if [[ $VAR =~ ^KAFKA_ && ! $VAR =~ ^KAFKA_HOME ]]; then
    kafka_name=`echo "$VAR" | sed -r "s/KAFKA_(.*)=.*/\1/g" | tr '[:upper:]' '[:lower:]' | tr _ .`
    env_var=`echo "$VAR" | sed -r "s/(.*)=.*/\1/g"`
    if egrep -q "(^|^#)$kafka_name=" config/server.properties
    then sed -r -i "s@(^|^#)($kafka_name)=(.*)@\2=${!env_var}@g" config/server.properties #note that no config values may contain an '@' char
    else echo "$kafka_name=${!env_var}" >> config/server.properties
    fi
  fi
done
fi

exec "$@"

