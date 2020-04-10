#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset


if ! [ -d /images ] ; then
  echo "no /images directory present, skip image preload"
  exit 0
fi

# TODO pick master/node images also
dirs=(
  "/images/container/common"
  "/images/container/common_${KUBERNETES_VERSION}"
  "/images/container/control_plane_${KUBERNETES_VERSION}"
)

images=($(find "${dirs[@]}" -name image.tar))

if [ -z "${images+x}" ] ; then
  echo  "no images found in ${dirs[@]}, skip image preload"
  exit 0
fi

echo "${images[@]}" | xargs --max-procs=2 --max-args=1 ctr -n k8s.io images import
