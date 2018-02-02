#!/bin/bash

if [[ $1 == --help ]]
then [[ -n $HELP_ABOUT ]] && echo $HELP_ABOUT
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
    
export KAFKA_LOG_DIRS="/kafka/kafka-logs-$HOSTNAME"

# Starting Zookeeper
zookeeper-server-start.sh config/zookeeper.properties &

while ! nc -z localhost 2181;  do sleep 1; done

# this script updates server.properties based on environment variables starting by KAFKA_
for var in `env | egrep '^KAFKA' | grep -v 'KAFKA_VERSION'`
do kafka_name=`echo "$var" | sed -r "s/KAFKA_(.*)=.*/\1/g" | tr '[:upper:]' '[:lower:]' | tr _ .`
   env_var=`echo "$var" | sed -r "s/(.*)=.*/\1/g"`
   [[ -n $VERBOSE ]] && echo "{$0} Adding to server.properties: $kafka_name=${!env_var}"
   if egrep -q "(^|^#)$kafka_name=" config/server.properties
   then sed -r -i "s~(^|^#)($kafka_name)=(.*)~\2=${!env_var}~g" config/server.properties 
   else echo "$kafka_name=${!env_var}" >> config/server.properties
   fi
done
fi

exec "$@"

