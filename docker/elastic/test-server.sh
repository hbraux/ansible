# wait for server to start
sleep 20 
# create index
dockerRun curl -s -XPUT http://elastic:9200/test_index

