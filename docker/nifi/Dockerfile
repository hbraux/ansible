FROM jdk:8

ARG URL_APACHE=http://apache.crihan.fr/dist

ENV NIFI_VERSION 1.5.0

ENV IMAGE_INFO Nifi ${NIFI_VERSION} slim server 

ENV HEAP_SIZE 256m

# To reduce image size only keep the Nifi Archives that are mandatory (Core) or used (Connectors)
ENV NIFI_CORE_NARS framework,provenance-repository,jetty-bundle-1.5.0.nar,standard,standard-services-api,ssl-context-service,enrich,record-serialization-services,update-attribute,avro,kite
# ENV NIFI_CONN_NARS=elasticsearch-5,hbase,hbase_1_1_2-client-service,kafka-1-0,mongodb,cassandra
ENV NIFI_CONN_NARS=hbase,hbase_1_1_2-client-service,hadoop-libraries

RUN set -x && mkdir -p /opt /data \
    && curl -s ${URL_APACHE}/nifi/${NIFI_VERSION}/nifi-${NIFI_VERSION}-bin.tar.gz | tar xzf - -C /opt \
    && mv /opt/nifi-${NIFI_VERSION} /opt/nifi \
    && adduser -D -s /sbin/nologin nifi \
    && chown -R nifi: /opt/nifi /data \
    # cleanup
    && rm -r /opt/nifi/docs \
    && set +x && for f in $(find /opt/nifi/lib -name "*.nar" | sort); do l=${f:19} ; echo "${NIFI_CORE_NARS},${NIFI_CONN_NARS}," | grep -q "${l%-nar*}," || rm -v $f ; done 

COPY entrypoint.sh /

ENV PATH ${PATH}:/opt/nifi/bin
WORKDIR /opt/nifi

USER nifi

EXPOSE 8080

VOLUME /data

ENTRYPOINT ["/entrypoint.sh"]

CMD ["help"]


