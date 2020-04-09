FROM ubuntu:18.04@sha256:bec5a2727be7fff3d308193cfde3491f8fba1a2ba392b7546b43a051853a341d

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
      ca-certificates \
      curl \
    && true

COPY download.sh /tmp/download.sh
RUN /tmp/download.sh

COPY export.sh /usr/bin/export.sh

CMD ["export.sh"]
