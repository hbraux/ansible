#!/bin/bash

function _help {
 echo "$SERVER_INFO
Commands in interactive mode
  shell : hbase shell
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
  <property>
    <name>hbase.rest.port</name>
    <value>8084</value>
  </property>
</configuration>
EOF
  cat > conf/zoo.cfg <<EOF
clientPort=2182
EOF
  
  touch .setup
}

function _setupcli {
  cat > conf/hbase-site.xml <<EOF
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
     <name>hbase.zookeeper.quorum</name>
     <value>$SERVER_NAME</value>
  </property>
</configuration>
EOF

  cat > conf/zoo.cfg <<EOF 
clientPortAddress=$SERVER_NAME
server.1=$SERVER_NAME:2182
EOF
}

function _start {
  _setup
  # Thrift Server 
  hbase thrift start > logs/hbase-thrift.log 2>&1 &

  # REST server
  hbase rest start > logs/hbase-rest.log 2>&1 &

  exec hbase master start
}

export -f _help _setup _start

case $1 in
  --help)  _help;;
  --start) _start;;
  shell)   _setupcli; exec hbase shell;;
  *)       exec $@;;
esac

