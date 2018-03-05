#!/bin/bash

function _help {
 echo "$SERVER_INFO

Prerequisite: create a Used Defined Network for server Name resolution; example
  docker network create --driver bridge udn

Start server (no persistence)
  docker run -d --name=hbase --network=udn -p 8080:8080 -p 16010:16010 hbase start

To use Thrift API instead of REST API run: hbase start --thrift

HBase shell
  docker run  -it --rm --network=udn hbase shell

Rest API
  http://<docker_host>:8080/

HBase UI
  http://<docker_host>:16010/

Stop server
  docker stop hbase && docker rm hbase
"
}

function _setup {
  [[ -f .setup ]] && return

  cat > conf/hbase-site.xml <<EOF
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>hbase.rootdir</name>
    <value>file:////opt/hbase/data</value>
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
  then hbase thrift start >logs/hbase-thrift.log 2>&1 &
  else hbase rest start > logs/hbase-rest.log 2>&1 &
  fi
  exec hbase master start
}



case $1 in
  help)  _help;;
  start) _start $2;;
  shell)   _setupcli; exec hbase shell;;
  *)       exec $@;;
esac

