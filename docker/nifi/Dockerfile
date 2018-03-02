FROM jdk:8

# using local Apache mirror
ARG MIRROR=apache.crihan.fr


ENV NIFI_VERSION 1.5.0

ENV SERVER_NAME nifi
ENV SERVER_INFO Nifi ${NIFI_VERSION} development server 

RUN set -x && mkdir -p /opt \
    && curl -s http://${MIRROR}/dist/nifi/${NIFI_VERSION}/nifi-${NIFI_VERSION}-bin.tar.gz | tar xzf - -C /opt \
    && mv /opt/nifi_-${NIFI_VERSION} /opt/nifi \
    && adduser -D -s /sbin/nologin nifi \
    && chown -R nifi: /opt/nifi

COPY entrypoint.sh /

ENV PATH ${PATH}:/opt/nifi/bin
WORKDIR /opt/nifi

USER nifi

EXPOSE 8080

# VOLUME /nifi

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--start"]


