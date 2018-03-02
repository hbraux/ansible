# Basic Alpine/JDK8 container 

FROM bash:4.4

ENV LANG=C.UTF-8
ENV JDK_VERSION 8
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk
ENV PATH $PATH:$JAVA_HOME/bin

# RUN echo -e "http://dl-2.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

RUN apk update && apk add --no-cache openjdk8="8.151.12-r0" 


