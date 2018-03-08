FROM jdk:8

ARG URL_APACHE=http://apache.crihan.fr/dist

ENV HBASE_VERSION 1.2.6

ENV HEAP_SIZE 128m

ENV IMAGE_INFO HBase ${HBASE_VERSION} slim server

RUN set -x && mkdir -p /opt  \
    && curl -s ${URL_APACHE}/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz | tar xzf - -C /opt \ 
    && mv /opt/hbase-${HBASE_VERSION} /opt/hbase \
    && rm -fr /opt/hbase/docs \
    && mkdir -p /opt/hbase/logs /data \
    && adduser -DH -s /sbin/nologin hbase \
    && chown -R hbase: /opt/hbase /data

COPY entrypoint.sh /

ENV PATH ${PATH}:/opt/hbase/bin
WORKDIR /opt/hbase

USER hbase

# Thrift API  
EXPOSE 9090

# Zookeeper 
EXPOSE 2181

# Rest API
EXPOSE 16000

# Master web UI 
EXPOSE 16010

VOLUME /data

ENTRYPOINT ["/entrypoint.sh"]

CMD ["help"]


