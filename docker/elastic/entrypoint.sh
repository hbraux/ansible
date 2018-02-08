#!/bin/bash

if [[ $1 == --help ]]
then [[ -n $CONTAINER_HELP ]] && echo $CONTAINER_HELP
echo "
Commands supported in interactive mode (samples)
  curl -s http://$CONTAINER_NAME:9200 # can be run from any container on the User Defined Network
"
  exit
fi

# start elastic
if [[ $1 == "elasticsearch" ]]
then
  # reducing HEAP memory (2g by default) for a test cluster
  export ES_JAVA_OPTS="-Xms512m -Xmx512m"
  sed -r -i "s/(^-Xms.*)//" config/jvm.options
  sed -r -i "s/(^-Xmx.*)//" config/jvm.options
  # starting Elastic in production mode (https://www.elastic.co/guide/en/elasticsearch/reference/5.2/bootstrap-checks.html#_development_vs_production_mode)
  echo "network.host: [_eth0_]" >> config/elasticsearch.yml
fi

exec "$@"
