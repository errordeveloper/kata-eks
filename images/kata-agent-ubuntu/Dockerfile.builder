
# based on https://github.com/weaveworks/footloose/blob/e0a534425d93b0dc45e308b319b14622f60f39da/images/ubuntu18.04/Dockerfile
FROM ubuntu:18.04@sha256:bec5a2727be7fff3d308193cfde3491f8fba1a2ba392b7546b43a051853a341d as rootfs-builder

# Don't start any optional services except for the few we need.
RUN find /etc/systemd/system /lib/systemd/system \
      -path '*.wants/*' \
      -not -name '*journald*' \
      -not -name '*systemd-tmpfiles*' \
      -not -name '*systemd-user-sessions*' \
      -exec rm \{} \;

RUN apt-get update \
    && apt-get upgrade --yes \
    && apt-get install --yes --no-install-recommends \
      chrony \
      dbus \
      init \
      iproute2 \
      iptables \
      iputils-ping \
      kmod \
      net-tools \
      sudo \
      systemd \
    && SUDO_FORCE_REMOVE=yes apt-get remove --yes \
      dmsetup \
      sudo \
    && apt-get autoremove --yes \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN >/etc/machine-id
RUN >/var/lib/dbus/machine-id

RUN systemctl set-default multi-user.target
RUN systemctl mask \
      dev-hugepages.mount \
      sys-fs-fuse-connections.mount \
      systemd-update-utmp.service \
      systemd-tmpfiles-setup.service \
      console-getty.service
RUN systemctl disable \
      networkd-dispatcher.service

# https://www.freedesktop.org/wiki/Software/systemd/ContainerInterface/
STOPSIGNAL SIGRTMIN+3


COPY configure.sh /tmp/configure.sh
RUN /tmp/configure.sh

FROM golang:1.14.1@sha256:08d16c1e689e86df1dae66d8ef4cec49a9d822299ec45e68a810c46cb705628d as agent-builder
ENV KATA_AGENT_IMPORT_PATH=github.com/kata-containers/agent
ARG KATA_AGENT_VERSION
RUN go get -d "${KATA_AGENT_IMPORT_PATH}" \
   && cd "${GOPATH}/src/${KATA_AGENT_IMPORT_PATH}" \
   && git remote add fork https://github.com/errordeveloper/kata-agent \
   && git fetch fork \
   && git checkout -q "${KATA_AGENT_VERSION}" \
   && make INIT=no SECCOMP=no \
   && make install DESTDIR=/out \
   && mkdir -p /out/etc/systemd/system/basic.target.wants \
   && ln -sf /usr/lib/systemd/system/kata-containers.target /out/etc/systemd/system/basic.target.wants/kata-containers.target

FROM scratch as rootfs
COPY --from=rootfs-builder / /
COPY --from=agent-builder /out /

FROM ubuntu:18.04@sha256:bec5a2727be7fff3d308193cfde3491f8fba1a2ba392b7546b43a051853a341d as ubuntu-bionic-kernels

# apt list 'linux-image-4.15.*-generic' | tail -1
RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
      linux-image-4.15.0-91-generic \
      linux-image-4.18.0-25-generic \
      linux-image-5.0.0-43-generic \
      linux-image-5.3.0-45-generic \
      linux-image-4.15.0-1056-kvm \
    && true

# see https://centos.pkgs.org/7/centos-updates-x86_64/ for all available versions
FROM centos:7@sha256:4a701376d03f6b39b8c2a8f4a8e499441b0d567f9ab9d58e4991de4472fb813c as centos-7-kernels
RUN yum install -y \
    kernel-3.10.0-1062.18.1.el7 \
  && true

# see https://centos.pkgs.org/8/centos-baseos-x86_64/ for all available versions
FROM centos:8@sha256:fe8d824220415eed5477b63addf40fb06c3b049404242b31982106ac204f6700 as centos-8-kernels
RUN dnf install -y \
    kernel-4.18.0-147.5.1.el8_1.x86_64 \
  && true

#FROM fedora:32@sha256:f0a228cac4545c031ed11da1fe5c2fd214c2c3b0b5f090c8000d9358930c7eac as fedora-32-kernels
#  RUN dnf install -y \
#      kernel-5.6.0-0.rc7.git0.2.fc32.x86_6 \ # go find it!
#    && true

FROM ubuntu:18.04@sha256:bec5a2727be7fff3d308193cfde3491f8fba1a2ba392b7546b43a051853a341d as image-builder
RUN mkdir /out

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
      gcc \
      libc-dev \
      parted \
      qemu-utils \
      udev \
    && true

COPY --from=rootfs / /in

COPY --from=ubuntu-bionic-kernels /lib/modules /in/lib/modules
COPY --from=ubuntu-bionic-kernels /boot /out

COPY --from=centos-7-kernels /lib/modules /in/lib/modules
COPY --from=centos-7-kernels /boot /out

COPY --from=centos-8-kernels /lib/modules /in/lib/modules
RUN mv /in/lib/modules/4.18.0-147.5.1.el8_1.x86_64/vmlinuz /out/vmlinuz-4.18.0-147.5.1.el8_1.x86_64

COPY --from=linuxkit/kernel:4.19.104 /kernel /out/vmlinuz-4.19.104-linuxkit
COPY --from=linuxkit/kernel:4.19.104 /kernel.tar /tmp/modules.tar
RUN tar -C /in -xf /tmp/modules.tar && rm -f /tmp/modules.tar

COPY --from=linuxkit/kernel:5.4.19 /kernel /out/vmlinuz-5.4.19-linuxkit
COPY --from=linuxkit/kernel:5.4.19 /kernel.tar /tmp/modules.tar
RUN tar -C /in -xf /tmp/modules.tar && rm -f /tmp/modules.tar

COPY make-image.sh /tmp/make-image.sh
COPY nsdax.gpl.c /tmp/nsdax.gpl.c

WORKDIR /tmp
CMD /tmp/make-image.sh -o /out/kata.img /in
