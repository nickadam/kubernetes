FROM ubuntu:20.04

USER root

RUN apt-get update && \
  apt-get install -y dnsutils iproute2 curl && \
  curl -fsLo /usr/local/bin/tini https://github.com/krallin/tini/releases/download/v0.19.0/tini-amd64 && \
  chmod +x /usr/local/bin/tini

COPY docker-entrypoint.sh /usr/local/bin/
