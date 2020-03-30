FROM linuxkit/kernel:4.19.104 as kernel

FROM ubuntu:18.04@sha256:bec5a2727be7fff3d308193cfde3491f8fba1a2ba392b7546b43a051853a341d as rootfs-builder

# RUN apt-get update \
#     && apt-get install -y \
#       apt-utils \
#       autoconf \
#       automake \
#       binutils \
#       build-essential \
#       ca-certificates \
#       chrony \
#       chrony \
#       cmake \
#       coreutils \
#       curl \
#       dbus \
#       debianutils \
#       debootstrap \
#       g++ \
#       gcc \
#       git \
#       init \
#       iproute2 \
#       iptables \
#       iputils-ping \
#       kmod \
#       libc6-dev \
#       libseccomp2 \
#       libstdc++-8-dev \
#       m4 \
#       make \
#       musl \
#       musl-dev \
#       musl-tools \
#       net-tools \
#       sed \
#       sudo \
#       systemd \
#       tar \
#     && apt-get clean \
#     && rm -rf /var/lib/apt/lists/*
RUN apt-get update \
    && apt-get install -y \
      apt-utils \
      fakechroot \
      fakeroot \
      debianutils \
      debootstrap \
      tar \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN . /etc/lsb-release \
    && fakechroot -- fakeroot -- debootstrap \
      --foreign --variant=fakechroot \
      --include="chrony init iptables kmod systemd" \
      "${DISTRIB_CODENAME}" \
      /out \
    && DEBOOTSTRAP_DIR=/out/debootstrap fakechroot -- fakeroot -- debootstrap \
      --second-stage \
      --second-stage-target=/out \
    || (cat /out/debootstrap/debootstrap.log ; exit 1)

#RUN ln -sf /lib/systemd/systemd /out/usr/lib/systemd/systemd

#RUN ls -la /out/bin /out/usr/bin

RUN mkdir -p /out/boot
COPY --from=kernel System.map /out/boot/System.map
COPY --from=kernel kernel.tar /tmp/modules.tar
RUN tar -C /out -xf /tmp/modules.tar && rm -f /tmp/modules.tar

COPY configure.sh /tmp/configure.sh
RUN /tmp/configure.sh


FROM golang:1.14.1@sha256:08d16c1e689e86df1dae66d8ef4cec49a9d822299ec45e68a810c46cb705628d as agent-builder
env KATA_AGENT_IMPORT_PATH=github.com/kata-containers/agent
env KATA_AGENT_VERSION=1.10.1
RUN go get -d "${KATA_AGENT_IMPORT_PATH}" \
   && make -C "${GOPATH}/src/${KATA_AGENT_IMPORT_PATH}" INIT=no SECCOMP=no \
   && make -C "${GOPATH}/src/${KATA_AGENT_IMPORT_PATH}" install DESTDIR=/out

FROM scratch
COPY --from=rootfs-builder /out /
COPY --from=agent-builder /out /

