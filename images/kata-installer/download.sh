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

ARCH="$(uname -m)"
ALT_ARCH="${ARCH}"
if [ "${ARCH}" = "x86_64" ] ; then
  ALT_ARCH="amd64"
fi

mkdir -p /data/etc /data/usr/bin

CRICTL_VERSION="1.16.0"
get_tarball "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-linux-${ALT_ARCH}.tar.gz" /data/usr/bin

CONTAINERD_VERSION="1.3.3"
get_tarball "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}.linux-${ALT_ARCH}.tar.gz" /data/usr

KATA_RUNTIME_VERSION="1.11.0-alpha1"
get_tarball "https://github.com/kata-containers/runtime/releases/download/${KATA_RUNTIME_VERSION}/kata-static-${KATA_RUNTIME_VERSION}-${ARCH}.tar.xz" /data

ln -f -s /opt/kata/bin/containerd-shim-kata-v2 /data/opt/kata/bin/containerd-shim-kata-qemu-v2
ln -f -s /opt/kata/bin/containerd-shim-kata-v2 /data/opt/kata/bin/containerd-shim-kata-fc-v2

cat > /data/etc/versions.env << EOF
CRICTL_VERSION=${CRICTL_VERSION}
CONTAINERD_VERSION=${CONTAINERD_VERSION}
KATA_RUNTIME_VERSION=${KATA_RUNTIME_VERSION}
EOF
