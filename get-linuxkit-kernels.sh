#!/bin/bash

# for general documentation on LinuxKit kernels see https://github.com/linuxkit/linuxkit/blob/07f1bae9ce17a6d2acb11cfea7d15176c8751099/docs/kernels.md
# for Ubuntu kernels see https://github.com/linuxkit/linuxkit/tree/07f1bae9ce17a6d2acb11cfea7d15176c8751099/contrib/foreign-kernels

tags=(
  "4.19.104"
  "5.4.19"
)

for tag in "${tags[@]}" ; do
  image="$(docker pull -q "linuxkit/kernel:${tag}")"
  echo "Extracting from ${image}..."
  container="$(docker create "${image}" nothing)"
  dir="linux-${tag}"
  mkdir -p "${dir}"
  docker cp "${container}:kernel" "${dir}/bzImage"
  du -h "${dir}/bzImage"
  docker cp "${container}:System.map" "${dir}/System.map"
  du -h "${dir}/System.map"
  docker cp "${container}:kernel.tar" "${dir}/modules.tar"
  du -h "${dir}/modules.tar"
done
