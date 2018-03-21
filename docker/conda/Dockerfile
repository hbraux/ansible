# a slim miniconda image

FROM centos:7

#FROM glibc

ARG URL_CONTINUM=https://repo.continuum.io

ARG CONDA_PACKAGES="python-dateutil pandas"
#pandas

ENV LANG C.UTF-8

ENV CONDA_VERSION 4.4.10

ENV IMAGE_INFO Miniconda ${CONDA_VERSION}

ENV PATH /opt/conda/bin:$PATH

RUN export HTTP_PROXY=${http_proxy} && export HTTPS_PROXY=${https_proxy} && \
    set -x && \
    echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh && \
    curl -s ${URL_CONTINUM}/miniconda/Miniconda2-${CONDA_VERSION}-Linux-x86_64.sh -o ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh  && \
    conda config --set ssl_verify false && \ 
    conda config --set show_channel_urls true && \
    conda update -y -n  base conda && \
    conda install -y -v $CONDA_PACKAGES 

CMD [ "/bin/bash" ]
