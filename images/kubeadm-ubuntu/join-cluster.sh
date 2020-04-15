#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

cluster="$(sed -n 's/^cluster="\(.*\)"$/\1/p' "/etc/kubeadm/metadata/labels")"

kubeadm join --v=9 --ignore-preflight-errors=NumCPU,SystemVerification,FileContent--proc-sys-net-bridge-bridge-nf-call-iptables,Swap --cri-socket=/var/run/containerd/containerd.sock \
    "${cluster}-master:6443"
