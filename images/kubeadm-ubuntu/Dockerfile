FROM linuxkit/kernel:4.19.104 as kernel

# based on https://github.com/weaveworks/footloose/blob/e0a534425d93b0dc45e308b319b14622f60f39da/images/ubuntu18.04/Dockerfile
FROM ubuntu:18.04@sha256:bec5a2727be7fff3d308193cfde3491f8fba1a2ba392b7546b43a051853a341d

# Don't start any optional services except for the few we need.
RUN find /etc/systemd/system /lib/systemd/system \
      -path '*.wants/*' \
      -not -name '*journald*' \
      -not -name '*systemd-tmpfiles*' \
      -not -name '*systemd-user-sessions*' \
      -exec rm \{} \;

RUN apt-get update \
    && apt-get install -y \
      curl \
      dbus \
      iproute2 \
      iputils-ping \
      net-tools \
      sudo \
      systemd \
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

RUN mkdir -p /boot
COPY --from=kernel System.map /boot/System.map
COPY --from=kernel kernel.tar /tmp/modules.tar
RUN tar -C / -xf /tmp/modules.tar && rm -f /tmp/modules.tar

COPY configure.sh /tmp/configure.sh
RUN /tmp/configure.sh
