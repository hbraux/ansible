FROM jdk:8

ARG URL_ELASTIC=http://artifacts.elastic.co/downloads/elasticsearch

ENV ELASTICSEARCH_VERSION 5.6.6

ENV SERVER_INFO Elasticsearch ${ELASTICSEARCH_VERSION} Development Server 
ENV SERVER_NAME elastic

RUN set -x && mkdir -p /opt \
    && curl -s ${URL_ELASTIC}/elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz | tar xzf - -C /opt \ 
    && mv /opt/elasticsearch-${ELASTICSEARCH_VERSION} /opt/elasticsearch \
    && adduser -DH -s /sbin/nologin elastic \
    && mkdir -p /opt/elasticsearch/data \
    && chown -R elastic: /opt/elasticsearch

COPY entrypoint.sh /

ENV PATH ${PATH}:/opt/elasticsearch/bin
WORKDIR /opt/elasticsearch

USER elastic

# publish 9200 on host
EXPOSE 9200/TCP
EXPOSE 9300

VOLUME /opt/elasticsearch/data

ENTRYPOINT ["/entrypoint.sh"]

CMD ["--start"]


