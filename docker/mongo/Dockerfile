FROM bash

# the version include in APK repo is that one
ENV MONGO_VERSION 3.4.10
ENV SERVER_INFO Mongo ${MONGO_VERSION} Development Server
ENV SERVER_NAME mongo

RUN apk add --no-cache mongodb \
    && rm /usr/bin/mongoperf \
    && chown -R mongodb /data/db

COPY entrypoint.sh /

USER mongodb

VOLUME /data/db

EXPOSE 27017 28017

ENTRYPOINT [ "/entrypoint.sh" ]


CMD [ "mongod", "--bind_ip", "0.0.0.0" ]
