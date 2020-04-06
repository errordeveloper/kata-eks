FROM ubuntu:18.04@sha256:bec5a2727be7fff3d308193cfde3491f8fba1a2ba392b7546b43a051853a341d as builder

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
      ca-certificates \
      curl \
      xz-utils \
    && true

RUN mkdir -p /data

COPY download.sh /tmp/download.sh
RUN /tmp/download.sh

COPY configure.sh /tmp/configure.sh
RUN /tmp/configure.sh

FROM errordeveloper/extract@sha256:10df1869daa458b895fc9fdd5f3bc3314627468aae7cd44619cbdc6c5d6412be
COPY --from=builder /data /data

CMD ["-C", "/out"]
