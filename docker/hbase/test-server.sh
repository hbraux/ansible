sleep 4 # wait for server to start
dockerRun shell <<EOF
create_namespace 'test_ns'
create 'test_ns:test_table','C'
put 'test_ns:test_table','1234','C:a','aaaa'
EOF


curl -s http://$DOCKER_HOST:16010/master-status | grep test_ns:test_table
