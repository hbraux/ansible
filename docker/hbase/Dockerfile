FROM jdk:8

ARG MIRROR=apache.crihan.fr 

ENV HBASE_VERSION 1.2.6
ENV HBASE_TARBALL http://${MIRROR}/dist/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz

ENV SERVER_NAME hbase
ENV SERVER_INFO HBase ${HBASE_VERSION} development server (with Zookeeper)

RUN set -x && mkdir -p /opt \
    && curl -s ${HBASE_TARBALL} | tar xzf - -C /opt \ 
    && mv /opt/hbase-${HBASE_VERSION} /opt/hbase \
    && rm -fr /opt/hbase/docs \
    && mkdir -p /opt/hbase/logs /opt/hbase/data \
    && adduser -DH -s /sbin/nologin hbase \
    && chown -R hbase: /opt/hbase

COPY entrypoint.sh /

ENV PATH ${PATH}:/opt/hbase/bin
WORKDIR /opt/hbase

USER hbase

# Thrift API  (do not expose UI port 9095) 9090->9090
# EXPOSE 9090

# Zookeeper (using 2182 to not conflict with Kafka)
EXPOSE 2182   

# Rest API 8080->8081
# EXPOSE 8080

# Master web UI  16010->16010
EXPOSE 16010

VOLUME /opt/hbase/data

ENTRYPOINT ["/entrypoint.sh"]

CMD ["--start"]


