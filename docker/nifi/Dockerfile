FROM jdk:8

# using local Apache mirror
ARG URL_NIFI=http://apache.crihan.fr/dist/nifi/

# only include those NARS (Nifi Archives), must den with ,
ARG NIFI_NARS="framework,scripting,jetty-bundle,provenance-repository,websocket-services-jetty,elasticsearch-5,hbase,hbase_1_1_2-client-service,kafka-1-0,mongodb,mongodb-services,update-attribute,"

ENV NIFI_VERSION 1.5.0

ENV SERVER_NAME nifi
ENV SERVER_INFO Nifi ${NIFI_VERSION} development server 

RUN set -x && mkdir -p /opt \
    && curl -s ${URL_NIFI}/${NIFI_VERSION}/nifi-${NIFI_VERSION}-bin.tar.gz | tar xzf - -C /opt \
    && mv /opt/nifi-${NIFI_VERSION} /opt/nifi \
    && adduser -D -s /sbin/nologin nifi \
    && chown -R nifi: /opt/nifi \
    && set +x && for f in $(find /opt/nifi/lib -name "*.nar"); do l=${f:19}; echo $NIFI_NARS | grep -q "${l%-nar*}," || mv $f $f.unused ; done

COPY entrypoint.sh /

ENV PATH ${PATH}:/opt/nifi/bin
WORKDIR /opt/nifi

USER nifi

# publish port on docker host 8080->8080
EXPOSE 8080

# VOLUME /nifi

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--start"]


