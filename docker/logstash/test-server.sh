# wait for server to start
sleep 20
# check plugin port
dockerRun nc -vz logstash 5000

# check that logstash is runnning
dockerRun curl -s http://logstash:9600/?pretty

# check that Elastic is running
dockerRun curl -s  http://elastic:9200/logstash

# send a JSON message 
dockerRun curl nc -v logstash 5000 <<<'{"MESSAGE":"TEST"}'

# check index
dockerRun curl -s http://elastic:9200/logstash/logs/


