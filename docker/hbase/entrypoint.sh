#!/bin/bash

function _help {
 echo "$IMAGE_INFO

WARNING: this image is for testing and development purpose only. It does not
support Docker Services.

Prerequisites
- create a Used Defined Network for hostname resolution
$ docker network create --driver bridge udn

Start server
$ docker run -d --name=hbase --network=udn -p 16000:16000 -p 16010:16010 hbase start

Other docker run options
   -v hbase:/data      for data persistence
   -e HEAP_SIZE=xxx    to increase the Heap Size (by default 128m)
   .. start --thrift   to use Thrift API instead of REST API 

HBase shell
$ docker run  -it --rm --network=udn hbase shell

Rest API
  http://hbase:16000/

HBase UI
  http://hbase:16010/

"
}

function _setup {
  [[ -f .setup ]] && return

  cat > conf/hbase-site.xml <<EOF
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
 <property>
  <name>hbase.rootdir</name>
  <value>file:////data</value>
 </property>
 <property>
  <name>hbase.rest.port</name>
  <value>16000</value>
 </property>
</configuration>
EOF
  touch .setup
}
export -f _help # testing purpose

function _setupcli {
  cat > conf/hbase-site.xml <<EOF
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
 <property>
  <name>hbase.zookeeper.quorum</name>
  <value>hbase</value>
 </property>
</configuration>
EOF
}

function _start {
  _setup
  if [[ $1 == -thrift ]]
  then HBASE_HEAPSIZE=32m hbase thrift start &
  else HBASE_HEAPSIZE=32m hbase rest start  &
  fi
  export HBASE_HEAPSIZE=${HEAP_SIZE:-128m}
  exec hbase master start
}



case $1 in
  help)  _help;;
  start) _start $2;;
  shell)   _setupcli; exec hbase shell;;
  *)       exec $@;;
esac

