FROM jdk:8

ENV LOGSTASH_VERSION 5.6.6
# squid does not handle dynamic content so using my site
ENV LOGSTASH_TARBALL http://164.132.225.18/~harold/logstash-5.6.6.tar.gz 
#ENV LOGSTASH_TARBALL http://artifacts.elastic.co/downloads/logstash/logstash-${LOGSTASH_VERSION}.tar.gz


ENV SERVER_INFO Logstash ${LOGSTASH_VERSION} Development Server 
ENV SERVER_NAME logstash

RUN set -x && mkdir -p /opt \
    && curl -s ${LOGSTASH_TARBALL} | tar xzf - -C /opt \ 
    && mv /opt/logstash-${LOGSTASH_VERSION} /opt/logstash \
    && adduser -DH -s /sbin/nologin logstash \
    && mkdir -p /opt/logstash/data  \
    && rm -fr /opt/logstash/vendor/bundle/jruby/2.3.0 \
    && chown -R logstash: /opt/logstash

COPY entrypoint.sh /

ENV PATH ${PATH}:/opt/logstash/bin
WORKDIR /opt/logstash

USER logstash

# Node API 
EXPOSE 9600

# Input plugins
EXPOSE 5000 5001

# no volume needed
# VOLUME /opt/logstash/data

ENTRYPOINT ["/entrypoint.sh"]

CMD ["--start"]


