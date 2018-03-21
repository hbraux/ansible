# Alpine with glibc, required for conda 
# Note that Alpine is provded with muscl and not supposed to support glibc 
# https://wiki.alpinelinux.org/wiki/Running_glibc_programs

# Also provides curl, certificates, bash, tini and git

FROM alpine:3.7

ARG URL_GLIBC=https://github.com/sgerrand/alpine-pkg-glibc/releases/download

ENV LANG=C.UTF-8

ENV GLIBC_VERSION 2.27-r0

RUN apk update && apk add --no-cache curl ca-certificates bash tini git && \
    # remove useless terms
   cd /usr/share/terminfo && ls | grep -v 'xterm$' | xargs rm -fr

RUN set -x && cd /tmp &&  \
    curl -s https://raw.githubusercontent.com/sgerrand/alpine-pkg-glibc/master/sgerrand.rsa.pub -o /etc/apk/keys/sgerrand.rsa.pub && \
    curl -sO $URL_GLIBC/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk && \
    curl -sO $URL_GLIBC/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk && \
    curl -sO $URL_GLIBC/${GLIBC_VERSION}/glibc-i18n-${GLIBC_VERSION}.apk && \
    ls -l && \
    apk add --no-cache glibc*.apk && \
    rm -f glibc*apk /etc/apk/keys/sgerrand.rsa.pub && \
    /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 ${LANG} || true && \
    echo "export LANG=$LANG" > /etc/profile.d/locale.sh && \
    apk del glibc-i18n && \
    rm -rf /var/cache/apk/*

CMD "/bin/bash"


