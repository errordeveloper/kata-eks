#!/bin/bash -x

set -o errexit
set -o pipefail
set -o nounset

get_tarball() {
  url="$1"
  dir="$2"

  tmp="$(mktemp)"

  mkdir -p "${dir}"

  curl --fail --location --silent --output "${tmp}" "${url}"
  tar -C "${dir}" -xf "${tmp}"

  rm -f "${tmp}"
}

get_file() {
  url="$1"
  output="$2"

  mkdir -p "$(dirname "${output}")"

  curl --fail --location --silent --output "${output}" "${url}"
}

get_binary() {
  url="$1"
  output="/usr/bin/${2}"

  get_file "${url}" "${output}"

  chmod +x "${output}"
}

ARCH="$(uname -m)"
ALT_ARCH="${ARCH}"
if [ "${ARCH}" = "x86_64" ] ; then
  ALT_ARCH="amd64"
fi

CNI_VERSION="0.8.2"
get_tarball "https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-${ALT_ARCH}-v${CNI_VERSION}.tgz" /opt/cni/bin

CRICTL_VERSION="1.16.0"
get_tarball "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-linux-${ALT_ARCH}.tar.gz" /usr/bin

CONTAINERD_VERSION="1.3.3"
get_tarball "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}.linux-${ALT_ARCH}.tar.gz" /usr

RUNC_VERSION="1.0.0-rc10"
get_binary "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.${ALT_ARCH}" runc

KUBERNETES_VERSION="1.18.1"

for b in kubeadm kubectl kubelet ; do
  get_binary "https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/${ALT_ARCH}/${b}" "${b}"
done

cat > /etc/versions.env << EOF
CNI_VERSION=${CNI_VERSION}
CRICTL_VERSION=${CRICTL_VERSION}
CONTAINERD_VERSION=${CONTAINERD_VERSION}
RUNC_VERSION=${RUNC_VERSION}
KUBERNETES_VERSION=${KUBERNETES_VERSION}
EOF
