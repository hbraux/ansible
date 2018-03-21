# Python with pip and local proxy

FROM bash

ARG PYTHON_MIRROR=htt://localmirror/

ENV PYTHON_VERSION 2

RUN set -x \
  && apk add --no-cache python2 py-setuptools  \
  && ln -sf /usr/bin/python2.7 /usr/bin/python \
  && ln -sf /usr/bin/python2.7-config /usr/bin/python-config \
  && ln -sf /usr/bin/easy_install-2.7 /usr/bin/easy_install \
  && easy_install --index-url=$PYTHON_MIRROR pip \
  && echo -e "[global]\ntimeout=60\nindex-url=$PYTHON_MIRROR" >/etc/pip.conf \
  && pip install --upgrade pip \
  && ln -sf /usr/bin/pip2.7 /usr/bin/pip

# Copy in the entrypoint script -- this installs prerequisites on container start.
COPY entrypoint.sh /entrypoint.sh

# These packages are not installed immediately, but are added at runtime or ONBUILD to shrink the image as much as possible. Notes:
#   * build-base: used so we include the basic development packages (gcc)
#   * linux-headers: commonly needed, and an unusual package name from Alpine.
#   * python-dev: are used for gevent e.g.
#   * py-pip: provides pip, not needed once the software is built
ENV BUILD_PACKAGES="\
  build-base \
  linux-headers \
  python2-dev \
"

ENTRYPOINT ["/entrypoint.sh"]
