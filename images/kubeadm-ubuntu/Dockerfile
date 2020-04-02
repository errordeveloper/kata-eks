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
    && apt-get upgrade --yes \
    && apt-get install --yes --no-install-recommends \
      ca-certificates \
      conntrack \
      curl \
      dbus \
      ebtables \
      ethtool \
      iproute2 \
      iptables \
      iputils-ping \
      kmod \
      net-tools \
      socat \
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
      console-getty.service \
      dev-hugepages.mount \
      proc-sys-fs-binfmt_misc.automount \
      sys-fs-fuse-connections.mount \
      systemd-tmpfiles-setup.service \
      systemd-update-utmp.service \
    && true
RUN systemctl disable \
      networkd-dispatcher.service \
    && true
RUN cp /usr/share/systemd/tmp.mount /etc/systemd/system/

# https://www.freedesktop.org/wiki/Software/systemd/ContainerInterface/
STOPSIGNAL SIGRTMIN+3

RUN mkdir -p /boot

COPY --from=errordeveloper/kata-agent:816ee8f1f-ubuntu-18.04-rootfs /lib/modules /lib/modules

COPY configure.sh /tmp/configure.sh
RUN /tmp/configure.sh

CMD /lib/systemd/systemd
