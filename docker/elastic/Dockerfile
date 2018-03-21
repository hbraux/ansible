FROM jdk:8

ARG URL_DOWNLOAD=https://artifacts.elastic.co

ENV ELASTICSEARCH_VERSION 5.6.6

ENV CLUSTER_NAME test

ENV IMAGE_INFO Elasticsearch ${ELASTICSEARCH_VERSION} Slim Server 
ENV HEAP_SIZE 128m

RUN set -x && mkdir -p /opt /data \
    && curl -s ${URL_DOWNLOAD}/downloads/elasticsearch/elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz | tar xzf - -C /opt \ 
    && mv /opt/elasticsearch-${ELASTICSEARCH_VERSION} /opt/elasticsearch \
    && adduser -DH -s /sbin/nologin elastic \
    && chown -R elastic: /opt/elasticsearch /data

COPY entrypoint.sh /

ENV PATH ${PATH}:/opt/elasticsearch/bin
WORKDIR /opt/elasticsearch

USER elastic

EXPOSE 9200 9300

VOLUME /data

ENTRYPOINT ["/entrypoint.sh"]

CMD ["help"]


