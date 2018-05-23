FROM ubuntu:xenial
MAINTAINER Yuanhai He <i@bestmike007.com>

ENV PERCONA_VERSION='5.7.21-21-3.xenial'
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y vim curl && \
    curl -sSLO https://repo.percona.com/apt/percona-release_0.1-4.xenial_all.deb && \
    dpkg -i percona-release_0.1-4.xenial_all.deb && \
    rm percona-release_0.1-4.xenial_all.deb && \
    apt-get update && \
    apt-get install -y percona-server-server-5.7=$PERCONA_VERSION percona-server-tokudb-5.7=$PERCONA_VERSION && \
    rm -rf /var/lib/mysql && \
    apt-get clean -yq
ADD entry-point.sh /entry-point.sh
RUN chmod +x /entry-point.sh
ENTRYPOINT /entry-point.sh
