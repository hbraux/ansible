#!/bin/bash

function _help {
echo "$IMAGE_INFO

WARNING: this image is for testing and development purpose only. It does not
support Docker Services.

Prerequisites
- create a Used Defined Network for hostname resolution
\$ docker network create --driver bridge udn

Start server
\$ docker run -d --name=spark  -h spark -v spark:/data --network=udn -p 7080:7080 -h spark start

Other docker run options
 -e HEAP_SIZE=xxx    to increase the Heap Size (by default 256m)

Python Spark (client mode)
\$ docker run -it --rm --network=udn spark pyspark --master spark://spark:7077

Spark submit (file must be copied to volume)
\$ docker cp test.py spark:/data
\$ docker run -it --rm -v spark:/data --network=udn spark spark-submit /data/test.py --master spark://spark:7077

Spark Web UI
   http://spark:7080/
"
}

function _setup {
  [[ -f .setup ]] && return
  touch .setup
}

function _start {
  _setup
  export SPARK_HOME=/opt/spark
  sparkjar=$(ls /opt/spark/lib/spark-assembly-*.jar)
  java -cp /opt/spark/conf/:$sparkjar -Xms${HEAP_SIZE} -Xmx${HEAP_SIZE} org.apache.spark.deploy.worker.Worker spark://spark:7077 &

  exec java -cp /opt/spark/conf/:$sparkjar -Xms${HEAP_SIZE} -Xmx${HEAP_SIZE} org.apache.spark.deploy.master.Master -h spark --webui-port 7080
}


case $1 in
  help)   _help;;
  start)  _start;;
  *)     exec $@;;
esac

