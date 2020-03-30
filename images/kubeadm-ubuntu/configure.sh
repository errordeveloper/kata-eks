#!/bin/bash -x

set -o errexit
set -o pipefail
set -o nounset

get_tarball() {
  url="$1"
  dir="$2"

  tmp="$(mktemp)"

  mkdir -p "${dir}"

  curl --location --silent --output "${tmp}" "${url}"
  tar -C "${dir}" -xf "${tmp}" 

  rm -f "${tmp}"
}

get_file() {
  url="$1"
  output="$2"

  mkdir -p "$(dirname "${output}")"

  curl --location --silent --output "${output}" "${url}"
}

get_binary() {
  url="$1"
  output="/usr/bin/${2}"

  get_file "${url}" "${output}"

  chmod +x "${output}"
}

cat > /etc/sysctl.d/99-kubernetes-cri.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

cat > /etc/modules-load.d/99-containerd.conf << EOF
overlay
br_netfilter
EOF

ARCH="$(uname -m)"
ALT_ARCH="${ARCH}"
if [ "${ARCH}" = "x86_64" ] ; then
  ALT_ARCH="amd64"
fi

CNI_VERSION="v0.8.2"
get_tarball "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${ALT_ARCH}-${CNI_VERSION}.tgz" /opt/cni/bin

CRICTL_VERSION="v1.16.0"
get_tarball "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ALT_ARCH}.tar.gz" /usr/bin


CONTAINERD_VERSION="1.3.3"
get_tarball "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}.linux-${ALT_ARCH}.tar.gz" /usr

KUBERNETES_VERSION="v1.18.0"

for b in kubeadm kubectl kubelet ; do
  get_binary "https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/${ALT_ARCH}/${b}" "${b}"
done

mkdir -p /etc/systemd/system /etc/containerd /etc/kubernetes/manifests /var/lib/kubelet /etc/cni/net.d

cat > /etc/systemd/system/containerd.service << EOF
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Install]
WantedBy=multi-user.target

[Service]
#ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/bin/containerd
Delegate=yes
KillMode=process
Restart=always
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=1048576
# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
EOF

systemctl enable containerd

#containerd config default | sed 's/systemd_cgroup = false/systemd_cgroup = true/' > /etc/containerd/config.toml
containerd config default > /etc/containerd/config.toml

cat > /etc/systemd/system/kubelet.service << EOF
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/home/

[Install]
WantedBy=multi-user.target

[Service]

## NOTE: This is what kubeadm unit spec looks like, we attempt to ignore it and use a more concrete config instead
#Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
#Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
## This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
## This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
## the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
#EnvironmentFile=-/etc/default/kubelet
#EnvironmentFile=-/etc/sysconfig/kubelet
#ExecStart=/usr/bin/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_CONFIG_ARGS \$KUBELET_KUBEADM_ARGS \$KUBELET_EXTRA_ARGS

ExecStart=/usr/bin/kubelet \
  --config=/var/lib/kubelet/config.yaml \
  --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf \
  --container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock

Restart=always
StartLimitInterval=0
RestartSec=10
EOF

cat > /etc/kubernetes/kubelet.yaml << EOF
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
clusterDNS:
- 10.96.0.10
clusterDomain: cluster.local
cpuManagerReconcilePeriod: 0s
evictionPressureTransitionPeriod: 0s
fileCheckFrequency: 0s
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 0s
imageMinimumGCAge: 0s
nodeStatusReportFrequency: 0s
nodeStatusUpdateFrequency: 0s
rotateCertificates: true
runtimeRequestTimeout: 0s
staticPodPath: /etc/kubernetes/manifests
streamingConnectionIdleTimeout: 0s
syncFrequency: 0s
volumeStatsAggPeriod: 0s
# cgroupDriver: systemd
resolvConf: /run/systemd/resolve/resolv.conf
EOF

systemctl enable kubelet

