#!/bin/bash

echo "$SERVER_INFO"

function _help {
 echo "Variables:
  LOGSTASH_INPUT   : input plugin conf, 'tcp/json' by default
  LOGSTASH_OUTPUT  : output plugin conf, 'elasticsearch' by default
  LOGSTASH_FILTER  : filter plugin conf, none by default
  LOGSTASH_ESHOST  : elasticsearch host, 'elastic:9200' by default
  LOGSTASH_ESINDEX : elasticsearch index, 'logstash' by default

Commands in interactive mode
  shell : Logstash interactive Ruby shell
"
}

function _setup {
  [[ -f .setup ]] && return

  LOGSTASH_ESINDEX=${LOGSTASH_ESINDEX:-logstash}
  LOGSTASH_ESHOST=${LOGSTASH_ESHOST:-http://elastic:9200}
  DEFAULT_INPUT="tcp { port => 5000 codec => json }"
  DEFAULT_OUTPUT="elasticsearch { hosts => [\"$LOGSTASH_ESHOST\"] index => \"$LOGSTASH_ESINDEX\" }"
  LOGSTASH_INPUT=${LOGSTASH_INPUT:-$DEFAULT_INPUT}
  LOGSTASH_OUTPUT=${LOGSTASH_OUTPUT:-$DEFAULT_OUTPUT}
  
  echo "input{ $LOGSTASH_INPUT }" >>data/logstash.conf
  [[ -n $LOGSTASH_FILTER ]] &&  echo "filter { $LOGSTASH_FILTER }" >>data/logstash.conf
  echo "output { $LOGSTASH_OUTPUT }" >>data/logstash.conf
  
  touch .setup
}

function _start {
  _setup
  exec logstash -f data/logstash.conf
}

export -f _help _setup _start

case $1 in
  --help)  _help;;
  --start) _start;;
  shell)   exec bin/logstash -i irb;;
  *)       exec "$@"
esac

