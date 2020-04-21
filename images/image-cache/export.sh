#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

kube_versions=(
  "1.16.9"
  "1.17.5"
  "1.18.1"
  "1.18.2"
)

kube_versioned_control_plane_images=(
  "k8s.gcr.io/kube-apiserver"
  "k8s.gcr.io/kube-controller-manager"
  "k8s.gcr.io/kube-scheduler"
)

kube_versioned_common_images=(
  "k8s.gcr.io/kube-proxy"
)

declare -A etcd_images

etcd_images["1.18.1"]="k8s.gcr.io/etcd:3.4.3-0"

declare -A coredns_images

coredns_images["1.18.1"]="k8s.gcr.io/coredns:1.6.7"

other_common_images=(
  "k8s.gcr.io/pause:3.2"
  "gcr.io/google-containers/startup-script:v1"
  "docker.io/cilium/operator:v1.7.2"
  "docker.io/cilium/cilium:v1.7.2"
  "docker.io/cilium/cilium:v1.7.2"
  "docker.io/cilium/cilium:v1.7.2"
)


pull_and_export() {
  image="${1}"
  output_dir="/images/container/${2}/${image}"
  output="${output_dir}/image.tar"

  mkdir -p "${output_dir}"

  if [ -e "${output}" ] ; then
    echo "${output} already exists, skipping"
    return
  fi

  ctr -n k8s.io images pull "${image}"
  ctr -n k8s.io images export "${output}" "${image}" 
  ctr -n k8s.io images remove "${image}"
}

for kube_version in "${kube_versions[@]}" ; do
  for control_plane_image in "${kube_versioned_control_plane_images}" ; do
    pull_and_export "${control_plane_image}:v${kube_version}" "control_plane_${kube_version}"
  done

  pull_and_export "${etcd_images[${kube_version}]}" "control_plane_${kube_version}"
  pull_and_export "${coredns_images[${kube_version}]}" "common_${kube_version}"
done

for other_common_image in "${other_common_images[@]}" ; do
  pull_and_export "${other_common_image}" common
done
