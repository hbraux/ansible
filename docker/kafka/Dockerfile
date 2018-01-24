# see https://hub.docker.com/r/wurstmeister/kafka/ for state-of-the-art 

FROM jdk

# using local Apache mirror
ARG MIRROR=apache.crihan.fr

ENV ABOUT standalone Kafka/Zookeeper service
ENV KAFKA_VERSION 0.10.2.1 
ENV SCALA_VERSION 2.10 

# install wget as the one in Alpine's busybox does not work, as well as bash
RUN apk add --no-cache wget bash

RUN set -x && mkdir -p /opt   \
    && wget -qO- http://${MIRROR}/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz | tar xzf - -C /opt \
    && mv /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} /opt/kafka \
    && adduser -DH -s /sbin/nologin kafka \
    && chown -R kafka: /opt/kafka



COPY entrypoint.sh /

ENV PATH ${PATH}:/opt/kafka/bin
WORKDIR /opt/kafka

USER kafka

EXPOSE 2181 9092

ENTRYPOINT ["/entrypoint.sh"]
CMD ["kafka-server-start.sh", "config/server.properties"]


