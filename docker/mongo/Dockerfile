FROM jdk

# the version include in APK repo is that one
ENV MONGO_VERSION 3.4.10
ENV SERVER_INFO Mongo ${MONGO_VERSION} Development Server with Restheart
ENV SERVER_NAME mongo

ENV RESTHEART_TARBALL=https://github.com/SoftInstigate/restheart/releases/download/3.2.2/restheart-3.2.2.tar.gz

RUN apk add --no-cache mongodb \
    && curl -s ${RESTHEART_TARBALL} | tar xzf - -C /opt \
    && chown -R mongodb /data/db /opt

#  rm /usr/bin/mongoperf \

COPY entrypoint.sh /

USER mongodb

VOLUME /data/db

# only publish Restheart Port
EXPOSE 8080/TCP

ENTRYPOINT [ "/entrypoint.sh" ]


CMD [ "--start"]
