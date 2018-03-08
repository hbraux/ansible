FROM jdk:8

ARG URL_APACHE=http://apache.crihan.fr/dist

ENV SPARK_VERSION 1.6.3

ENV IMAGE_INFO Spark ${SPARK_VERSION} slim server

ENV HEAP_SIZE 256m

# add python2 for pyspark
RUN apk add --no-cache python2  libc6-compat


RUN set -x && mkdir -p /opt  \
    && curl -s ${URL_APACHE}/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop2.6.tgz | tar xzf - -C /opt \
    && mv /opt/spark-${SPARK_VERSION}-bin-hadoop2.6 /opt/spark \
    && adduser -D -s /sbin/nologin spark \
    && mkdir -p /opt/spark/logs \
    && chown -R spark: /opt/spark \
    #cleanup
    && cd /opt/spark && rm -fr CHANGES.txt R examples ec2 lib/*examples*

COPY entrypoint.sh /

ENV PATH ${PATH}:/opt/spark/bin
WORKDIR /opt/spark

USER spark

# Spark master
EXPOSE 7077

# Spark master UI
EXPOSE 7080

# the volume is just to upload file to server
VOLUME /data

ENTRYPOINT ["/entrypoint.sh"]

CMD ["help"]


