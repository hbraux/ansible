# Alpine with bash, curl and certificates for SSL

FROM alpine:3.7

ENV BASH_VERSION 4.4

RUN apk update && apk add --no-cache bash ca-certificates curl  \
    && rm -rf /var/cache/apk/*  \
    # remove useless terms
    && cd /usr/share/terminfo && ls | grep -v 'xterm$' | xargs rm -fr

CMD "/bin/bash"
