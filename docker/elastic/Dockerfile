FROM jdk

ENV ELASTICSEARCH_VERSION=5.6.6
# squid does not handle dynamic content so using my site
ENV ELASTICSEARCH_TARBALL http://164.132.225.18/~harold/elasticsearch-5.6.6.tar.gz 
#ENV ELASTICSEARCH_TARBALL http://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz

ENV HELP_ABOUT Elasticsearch ${ELASTICSEARCH_VERSION} service

RUN set -x && mkdir -p /opt \
    && curl -s ${ELASTICSEARCH_TARBALL} | tar xzf - -C /opt \ 
    && mv /opt/elasticsearch-${ELASTICSEARCH_VERSION} /opt/elasticsearch \
    && adduser -DH -s /sbin/nologin elastic \
    && mkdir -p /opt/elasticsearch/data \
    && chown -R elastic: /opt/elasticsearch

COPY entrypoint.sh /

ENV PATH ${PATH}:/opt/elasticsearch/bin
WORKDIR /opt/elasticsearch

USER elastic

EXPOSE 9200 9300

VOLUME ["/opt/elasticsearch/data"]

ENTRYPOINT ["/entrypoint.sh"]

CMD ["elasticsearch"]


