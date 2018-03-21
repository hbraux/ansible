# Basic Alpine/JDK8 container 

FROM bash:4.4

ENV LANG C.UTF-8

ENV JDK_VERSION 8

ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk

ENV PATH $PATH:$JAVA_HOME/bin

# also install compatibility libraries for glibc
RUN apk update && apk add --no-cache libc6-compat openjdk8-jre-base=8.151.12-r0  \
    && rm -fr /var/cache/apk/* 



