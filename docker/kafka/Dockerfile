# simple standalone Zookeeper+ Kafka container

FROM local/jdk

ARG MIRROR=apache.crihan.fr

ENV ZK_VERSION=3.4.10 \
    ZK_HOME=/opt/zookeeper \
    KAFKA_VERSION=0.10.2.1 \
    SCALA_VERSION=2.10 \
    KAFKA_HOME=/opt/kafka \
    PATH=${PATH}:${KAFKA_HOME}/bin

RUN mkdir -p /opt && cd /opt && wget -q http://${MIRROR}/dist/zookeeper/zookeeper-${ZK_VERSION}/zookeeper-${ZK_VERSION}.tar.gz -O tgz \
 && tar xfz tgz  \
 && ln -s /opt/zookeeper_${ZK_VERSION} ${ZK_HOME} \
 && rm -f tgz

RUN mkdir -p /opt && cd /opt && wget -q http://${MIRROR}/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -O tgz \
 && tar xfz tgz  \
 && ln -s /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} ${KAFKA_HOME} \
 && rm -f tgz

COPY start-kafka.sh

CMD start-kafka.sh

EXPOSE 2181 9096
