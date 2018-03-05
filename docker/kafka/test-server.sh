dockerRun kafka-topics.sh --zookeeper kafka:2181 --create --topic topic.test --partitions 1 --replication-factor 1
dockerRun kafka-json.sh kafka:9092 topic.test uuid:%uuid date=%now val=%rand


