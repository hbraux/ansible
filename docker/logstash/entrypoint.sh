#!/bin/bash

if [[ $1 == --help ]]
then [[ -n $SERVER_HELP ]] && echo $SERVER_HELP
echo "
Supported variables
  LOGSTASH_INPUT   : input plugin conf (by default tcp/json)
  LOGSTASH_OUTPUT  : output plugin conf (by default elasticsearch)
  LOGSTASH_FILTER  : filter plugin conf (none by default)
  LOGSTASH_ESHOST  : elasticsearch host (default 'elastic:9200')
  LOGSTASH_ESINDEX : elasticsearch index (by default 'logstash')

Commands supported in interactive mode
  shell : Logstash interactive Ruby shell
"
  exit
fi

# start logstash
if [[ $1 == logstash ]]
then
   cfgfile=data/logstash.conf

  if [[ ! -f $cfgfile ]]
  then 
    LOGSTASH_INDEX=${LOGSTASH_INDEX:-logstash}
    LOGSTASH_ESHOST=${LOGSTASH_ESHOST:-http://elastic:9200}
    DEFAULT_INPUT="tcp { port => 5000 codec => json }"
    DEFAULT_OUTPUT="elasticsearch { hosts => [\"$LOGSTASH_ESHOST\"] index => \"$LOGSTASH_ESINDEX\" }"
    LOGSTASH_INPUT=${LOGSTASH_INPUT:-$DEFAULT_INPUT}
    LOGSTASH_OUTPUT=${LOGSTASH_OUTPUT:-$DEFAULT_OUTPUT}
    
    echo "input{ $LOGSTASH_INPUT }" >>$cfgfile
    [[ -n $LOGSTASH_FILTER ]] &&  echo "filter { $LOGSTASH_FILTER }" >>$cfgfile
    echo "output { $LOGSTASH_OUTPUT }" >>$cfgfile
  fi
  exec $@ -f $cfgfile
else
  if [[ $1 == shell ]]
  then exec bin/logstash -i irb
  else exec "$@"
  fi
fi
