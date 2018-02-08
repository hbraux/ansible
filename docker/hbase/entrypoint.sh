#!/bin/bash

if [[ $1 == --help ]]
then [[ -n $CONTAINER_HELP ]] && echo $CONTAINER_HELP
echo "
Commands supported in interactive mode:
  shell
"
  exit
fi

# start elastic
if [[ $1 == hbase-server ]]
then
  # update config for server mode (data dir)
  (cat > conf/hbase-site.xml) <<EOF
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>hbase.rootdir</name>
    <value>file:////opt/hbase/data</value>
  </property>
</configuration>
EOF
  (cat > conf/zoo.cfg) <<EOF
clientPort=2182
EOF
  # Ports: 9090 API and 9095 UI
  # hbase thrift start > logs/hbase-thrift.log 2>&1 &

  # REST server (background)
  # hbase rest start > $logs_dir/hbase-rest.log 2>&1 &

  # Master server (Foreground) that also starts the region server
  # Ports: Master: 16000 API, 16010 UI; 2181 ZK;  Region: 16020 API, 16030 UI
  exec hbase master start 
  exit
fi

# Update config for client mode (server alias)
(cat > conf/zoo.cfg) <<EOF
clientPortAddress=$CONTAINER_NAME
server.1=$CONTAINER_NAME:2182
EOF
(cat > conf/hbase-site.xml) <<EOF
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
     <name>hbase.zookeeper.quorum</name>
     <value>$CONTAINER_NAME</value>
  </property>
</configuration>
EOF
  
if [[ $1 == "shell" ]]
then exec hbase shell
else exec "$@"
fi

