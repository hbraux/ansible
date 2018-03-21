FROM alpine:3.7

ENV CACHE_VERSION 0.1

# Docker HOST IP is required for FTP Passive mode
ENV DOCKER_HOSTIP 127.0.0.1

# Passive Port Range for FTP
ENV PASV_MIN_PORT 21001
ENV PASV_MAX_PORT 21009

LABEL Description="HTTP/FTP Cache Server ${CACHE_VERSION} with upload support"

LABEL Usage="docker run -d --name=cache -e DOCKER_HOSTIP=\$DOCKER_HOSTIP --mount source=cache,target=/data -p 80:80 -p 21:21 -p ${PASV_MIN_PORT}-${PASV_MAX_PORT}:${PASV_MIN_PORT}-${PASV_MAX_PORT} cache"

RUN apk update && apk add --no-cache apache2 vsftpd \
    && rm -rf /var/cache/apk/*

COPY entrypoint.sh /

EXPOSE 80 21
EXPOSE 21001-21009

VOLUME /data

ENTRYPOINT ["/entrypoint.sh"]

CMD ["start"]
