dockerRun $DOCKER_IMG kafka-console-consumer.sh --bootstrap-server $SERVER_NAME:9092 --topic topic.test --from-beginning --max-messages 1


