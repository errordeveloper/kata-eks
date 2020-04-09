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

CONTAINERD_VERSION="1.3.3"
get_tarball "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}.linux-${ALT_ARCH}.tar.gz" /usr

cat > /etc/versions.env << EOF
CONTAINERD_VERSION=${CONTAINERD_VERSION}
EOF
