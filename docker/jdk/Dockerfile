# docker build -t local/jdk .
FROM alpine:3.6

ARG PROXY

ENV http_proxy=${PROXY} \
    LANG=C.UTF-8 \
    JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk \
    PATH=$PATH:$JAVA_HOME/bin

RUN echo -e "http://dl-2.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

# install wget as the default one in Alpine's busybox is limited
RUN apk update && apk add --no-cache wget

RUN apk add --no-cache openjdk8="8.151.12-r0" && [ "$JAVA_HOME" = "$JAVA_HOME" ]

