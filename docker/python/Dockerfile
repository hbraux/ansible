FROM bash

ARG MIRROR=https://si-devops-zhb-nexus.edf.fr/repository/pypi.python.org/simple

ENV PYTHON_VERSION 2

# These are always installed. Notes:
#   * dumb-init: a proper init system for containers, to reap zombie children
#   * bash: For entrypoint, and debugging
#   * ca-certificates: for SSL verification during Pip and easy_install
#   * python: the binaries themselves
#   * py-setuptools: required only in major version 2, installs easy_install so we can install Pip.


RUN set -x \
  && apk add --no-cache python2 py-setuptools  \
  && ln -sf /usr/bin/python2.7 /usr/bin/python \
  && ln -sf /usr/bin/python2.7-config /usr/bin/python-config \
  && ln -sf /usr/bin/easy_install-2.7 /usr/bin/easy_install \
  && easy_install --index-url=$MIRROR pip \
  && echo -e "[global]\ntimeout=60\nindex-url=$MIRROR" >/etc/pip.conf \
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

# This script installs APK and Pip prerequisites on container start, or ONBUILD. Notes:
#   * Reads the -a flags and /apk-requirements.txt for install requests
#   * Reads the -b flags and /build-requirements.txt for build packages -- removed when build is complete
#   * Reads the -p flags and /requirements.txt for Pip packages
#   * Reads the -r flag to specify a different file path for /requirements.txt
ENTRYPOINT ["/entrypoint.sh"]
