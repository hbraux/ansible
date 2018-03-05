FROM jdk:8

ARG URL_APACHE=http://apache.crihan.fr/dist

# Extra Nifi Archives (connectors)
ARG EXTRA_NIFI_NARS=elasticsearch-5,hbase,hbase_1_1_2-client-service,kafka-1-0,mongodb

# Core Nifi Archives (mandatory components and must have processors)
ENV CORE_NIFI_NARS framework,provenance-repository,jetty-bundle-1.5.0.nar,standard,standard-services-api,ssl-context-service,enrich,record-serialization-services,update-attribute

ENV NIFI_VERSION 1.5.0

ENV IMAGE_INFO Nifi ${NIFI_VERSION} development server 

RUN set -x && mkdir -p /opt \
    && curl -s ${URL_APACHE}/nifi/${NIFI_VERSION}/nifi-${NIFI_VERSION}-bin.tar.gz | tar xzf - -C /opt \
    && mv /opt/nifi-${NIFI_VERSION} /opt/nifi \
    && adduser -D -s /sbin/nologin nifi \
    && mkdir -p /opt/nifi/data \ 
    && chown -R nifi: /opt/nifi \
    # cleanup to reduce image size
    && rm -r /opt/nifi/docs \
    && set +x && for f in $(find /opt/nifi/lib -name "*.nar" | sort); do l=${f:19} ; echo "${CORE_NIFI_NARS},${EXTRA_NIFI_NARS}," | grep -q "${l%-nar*}," || rm -v $f ; done 

COPY entrypoint.sh /

ENV PATH ${PATH}:/opt/nifi/bin
WORKDIR /opt/nifi

USER nifi

EXPOSE 8080

VOLUME /opt/nifi/data

ENTRYPOINT ["/entrypoint.sh"]
CMD ["help"]


