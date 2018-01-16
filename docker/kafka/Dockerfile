#  https://github.com/wurstmeister/kafka-docker
# docker build -t kafka .

FROM alpine/jdk:3.6

ENV http_proxy http://192.168.56.31:3128

ENV KAFKA_VERSION=0.10.2.1 \
    SCALA_VERSION=2.10 \
    KAFKA_HOME=/opt/kafka \
    PATH=${PATH}:${KAFKA_HOME}/bin

RUN set -x && mkdir -p /opt && cd /opt && wget -q http://apache.crihan.fr/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -O tgz \
 && tar xfz tgz  \
 && ln -s /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} /opt/kafka \
 && rm -f tgz

# VOLUME ["/kafka"]

# Use "exec" form so that it runs as PID 1 (useful for graceful shutdown)
# CMD ["start-kafka.sh"]

