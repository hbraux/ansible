FROM jdk:8

ARG URL_RESTHEART=https://github.com/SoftInstigate/restheart/releases/download/3.2.2

ENV MONGO_VERSION 3.4.10

ENV IMAGE_INFO Mongo ${MONGO_VERSION} slim server

ENV RESTHEART_VERSION 3.2.2

RUN set -x && mkdir -p /opt && mkdir -p /data/db \
    && apk add --no-cache mongodb \
    && curl -s ${URL_RESTHEART}/restheart-${RESTHEART_VERSION}.tar.gz | tar xzf - -C /opt \
    && mv /opt/restheart-${RESTHEART_VERSION} /opt/restheart \
    && chown -R mongodb /opt/restheart /data \
    # remove that big file
    && rm -f /usr/bin/mongoperf 

COPY entrypoint.sh /

USER mongodb

WORKDIR /opt/restheart

VOLUME /data

# Mongo DB Port
EXPOSE 27017

# restheart Port
EXPOSE 27000

ENTRYPOINT [ "/entrypoint.sh" ]

CMD [ "help"]
