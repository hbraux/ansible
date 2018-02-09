FROM jdk

# using local Apache mirror
ARG MIRROR=apache.crihan.fr


ENV KAFKA_VERSION 0.10.2.1 
ENV SCALA_VERSION 2.10 

ENV SERVER_NAME kafka
ENV SERVER_HELP Kafka ${KAFKA_VERSION} development server (with Zookeeper)

RUN set -x && mkdir -p /opt && mkdir -p /kafka  \
    && curl -s http://${MIRROR}/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz | tar xzf - -C /opt \
    && mv /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} /opt/kafka \
    && rm -fr /opt/kafka/site-docs \
    && adduser -D -s /sbin/nologin kafka \
    && chown -R kafka: /opt/kafka /kafka

COPY entrypoint.sh /
COPY tools/* /opt/kafka/bin

ENV PATH ${PATH}:/opt/kafka/bin
WORKDIR /opt/kafka

USER kafka

EXPOSE 2181 9092

VOLUME /kafka

ENTRYPOINT ["/entrypoint.sh"]
CMD ["kafka-server-start.sh", "config/server.properties"]


