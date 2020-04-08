#!/bin/bash -x

set -o errexit
set -o pipefail
set -o nounset

cat > /etc/sysctl.d/99-kubernetes-cri.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

cat > /etc/modules-load.d/99-containerd.conf << EOF
overlay
br_netfilter
EOF

cat > /etc/modules-load.d/99-vsock.conf << EOF
vsock
vmw_vsock_virtio_transport
vmw_vsock_virtio_transport_common
EOF

cp /usr/share/systemd/tmp.mount /etc/systemd/system/

systemctl enable tmp.mount

mkdir -p /out/etc/chrony

cat > /out/etc/chrony/chrony.conf << EOF
# Welcome to the chrony configuration file. See chrony.conf(5) for more
# information about usuable directives.

# This will use (up to):
# - 4 sources from ntp.ubuntu.com which some are ipv6 enabled
# - 2 sources from 2.ubuntu.pool.ntp.org which is ipv6 enabled as well
# - 1 source from [01].ubuntu.pool.ntp.org each (ipv4 only atm)
# This means by default, up to 6 dual-stack and up to 2 additional IPv4-only
# sources will be used.
# At the same time it retains some protection against one of the entries being
# down (compare to just using one of the lines). See (LP: #1754358) for the
# discussion.
#
# About using servers from the NTP Pool Project in general see (LP: #104525).
# Approved by Ubuntu Technical Board on 2011-02-08.
# See http://www.pool.ntp.org/join.html for more information.

# KATA: Comment out ntp sources for chrony to be extra careful
# Reference:  https://chrony.tuxfamily.org/doc/3.4/chrony.conf.html
#pool ntp.ubuntu.com        iburst maxsources 4
#pool 0.ubuntu.pool.ntp.org iburst maxsources 1
#pool 1.ubuntu.pool.ntp.org iburst maxsources 1
#pool 2.ubuntu.pool.ntp.org iburst maxsources 2

# This directive specify the location of the file containing ID/key pairs for
# NTP authentication.
keyfile /etc/chrony/chrony.keys

# This directive specify the file into which chronyd will store the rate
# information.
driftfile /var/lib/chrony/chrony.drift

# Uncomment the following line to turn logging on.
#log tracking measurements statistics

# Log files location.
logdir /var/log/chrony

# Stop bad estimates upsetting machine clock.
maxupdateskew 100.0

# This directive enables kernel synchronisation (every 11 minutes) of the
# real-time clock. Note that it can’t be used along with the 'rtcfile' directive.
rtcsync

# Step the system clock instead of slewing it if the adjustment is larger than
# one second, but only in the first three clock updates.
makestep 1 3

# KATA: Is this how they do it?
refclock PHC /dev/ptp0 poll 3 dpoll -2 offset 0
# KATA: Step the system clock instead of slewing it if the adjustment is larger than
# one second, at any time
makestep 1 -1
EOF

mkdir -p /etc/systemd/system/chronyd.service.d

cat > /etc/systemd/system/chronyd.service.d/10-ptp.conf << EOF
[Unit]
ConditionPathExists=/dev/ptp0
EOF

# based on: https://github.com/cilium/cilium/blob/99a5aae2909f796d0e10341b9a2256444856eed4/contrib/systemd/sys-fs-bpf.mount
cat > /etc/systemd/system/sys-fs-bpf.mount << EOF
[Unit]
Description=Cilium BPF mounts
Documentation=http://docs.cilium.io/
DefaultDependencies=no
Before=local-fs.target umount.target
After=swap.target

[Mount]
What=bpffs
Where=/sys/fs/bpf
Type=bpf
Options=rw,nosuid,nodev,noexec,relatime,mode=700

[Install]
WantedBy=multi-user.target kata-containers.target
EOF

systemctl enable sys-fs-bpf.mount

# based on: https://github.com/kata-containers/agent/blob/73afd1a31736490e5fda4c4b779d84f945acb187/kata-containers.target
cat > /etc/systemd/system/kata-containers.target << EOF
#
# Copyright (c) 2018-2019 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

[Unit]
Description=Kata Containers Agent Target
Requires=basic.target
Requires=tmp.mount
Requires=sys-fs-bpf.mount
Wants=chronyd.service
Requires=kata-agent.service
Conflicts=rescue.service rescue.target
After=basic.target rescue.service rescue.target
AllowIsolate=yes
EOF

# https://github.com/kata-containers/agent/blob/73afd1a31736490e5fda4c4b779d84f945acb187/kata-agent.service.in
cat > /etc/systemd/system/kata-agent.service << EOF
#
# Copyright (c) 2018-2019 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

[Unit]
Description=Kata Containers Agent
Documentation=https://github.com/kata-containers/agent
Wants=kata-containers.target

[Service]
# Send agent output to tty to allow capture debug logs
# from a VM serial port
StandardOutput=tty
Type=simple
ExecStart=/usr/bin/kata-agent
LimitNOFILE=infinity
# ExecStop is required for static agent tracing; in all other scenarios
# the runtime handles shutting down the VM.
ExecStop=/bin/sync ; /usr/bin/systemctl --force poweroff
FailureAction=poweroff

[Install]
WantedBy=kata-containers.target
EOF

mkdir -p /etc/systemd/system/kata-agent.service.d

cat > /etc/systemd/system/kata-agent.service.d/10-delegate.conf << EOF
[Service]
Delegate=yes
KillMode=process
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=1048576
TasksMax=infinity
EOF

systemctl enable kata-agent

cat > /etc/systemd/system/kata-debug.service << EOF
[Unit]
Description=Kata Containers debug console -l
Before=kata-agent.service

[Install]
WantedBy=kata-containers.target

[Service]
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
StandardInput=tty
StandardOutput=tty
PrivateDevices=no
Type=simple
ExecStart=/bin/bash -l
Restart=always
EOF

systemctl enable kata-debug

cat > /etc/systemd/system/dropbear-debug.service << EOF
[Unit]
Before=kata-agent.service

[Install]
WantedBy=kata-containers.target

[Service]
ExecStart=/usr/sbin/dropbear -s -E -F
Restart=always
EOF

if [ -e /tmp/authorized_keys ] ; then
  mkdir -p /root/.ssh
  mv /tmp/authorized_keys /root/.ssh/authorized_keys
  chmod 0600 /root/.ssh/authorized_keys


  systemctl enable dropbear-debug
fi

systemctl enable auditd

echo > /out/etc/resolv.conf
