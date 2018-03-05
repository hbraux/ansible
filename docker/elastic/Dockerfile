FROM jdk:8

ARG URL_ELASTIC=http://artifacts.elastic.co/downloads

ENV ELASTICSEARCH_VERSION 5.6.6

ENV IMAGE_INFO Elasticsearch ${ELASTICSEARCH_VERSION} Development Server 

RUN set -x && mkdir -p /opt \
    && curl -s ${URL_ELASTIC}/elasticsearch/elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz | tar xzf - -C /opt \ 
    && mv /opt/elasticsearch-${ELASTICSEARCH_VERSION} /opt/elasticsearch \
    && adduser -DH -s /sbin/nologin elastic \
    && mkdir -p /opt/elasticsearch/data \
    && chown -R elastic: /opt/elasticsearch

COPY entrypoint.sh /

ENV PATH ${PATH}:/opt/elasticsearch/bin
WORKDIR /opt/elasticsearch

USER elastic

EXPOSE 9200 9300

VOLUME /opt/elasticsearch/data

ENTRYPOINT ["/entrypoint.sh"]

CMD ["help"]


