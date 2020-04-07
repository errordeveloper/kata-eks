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
vsock
vmw_vsock_virtio_transport
vmw_vsock_virtio_transport_common
EOF

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
