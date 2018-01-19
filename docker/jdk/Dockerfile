# Basic Aline/JDK8 container

FROM alpine:3.6

ENV LANG=C.UTF-8 \
    JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk \
    PATH=$PATH:$JAVA_HOME/bin

RUN echo -e "http://dl-2.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

# install wget as the one in Alpine's busybox does not work
RUN apk update && apk add --no-cache wget

RUN apk add --no-cache openjdk8="8.151.12-r0"

