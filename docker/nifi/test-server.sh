dockerRun kafka-topics.sh --zookeeper $SERVER_NAME:2181 --create --topic topic.test --partitions 1 --replication-factor 1
dockerRun kafka-json.sh $SERVER_NAME:9092 topic.test uuid:%uuid date=%now val=%rand


