FROM jdk:8

ARG URL_APACHE=http://apache.crihan.fr/dist

ENV KAFKA_VERSION 0.10.2.1 

ENV SCALA_VERSION 2.10 

ENV IMAGE_INFO Kafka ${KAFKA_VERSION} slim server

ENV HEAP_SIZE 256m

RUN set -x && mkdir -p /opt && mkdir -p /data  \
    && curl -s ${URL_APACHE}/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz | tar xzf - -C /opt \
    && mv /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} /opt/kafka \
    && rm -fr /opt/kafka/site-docs \
    && adduser -D -s /sbin/nologin kafka \
    && chown -R kafka: /opt/kafka /data

COPY entrypoint.sh /
COPY tools/* /opt/kafka/bin

ENV PATH ${PATH}:/opt/kafka/bin
WORKDIR /opt/kafka

USER kafka

# Zookeeper
EXPOSE 2181

# Kafka brokers
EXPOSE 9092

VOLUME /data

ENTRYPOINT ["/entrypoint.sh"]

CMD ["help"]


