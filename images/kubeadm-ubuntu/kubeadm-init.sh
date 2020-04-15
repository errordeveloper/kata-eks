#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

cluster="$(sed -n 's/^cluster="\(.*\)"$/\1/p' "/etc/kubeadm/metadata/labels")"

# it looks CPU detection doesn't work very well, and with 3 cores it still barks;
# --cri-socket is required also, as somehow autodetection is broken when
# this command runs in the context of this systemd unit
# TODO: detect if kata is in use and pass diffetent ignore-preflight-errors
# TODO: use a config file
# on EKS without Kata SystemVerification,FileContent--proc-sys-net-bridge-bridge-nf-call-iptables are required
# on D4M Swap is Requires

kubeadm init --v=9 \
  --kubernetes-version="${KUBERNETES_VERSION}" \
  --ignore-preflight-errors=NumCPU,SystemVerification,FileContent--proc-sys-net-bridge-bridge-nf-call-iptables,Swap \
  --apiserver-cert-extra-sans="${cluster}" \
  --cri-socket=/var/run/containerd/containerd.sock

# install cilium manifest
kubectl apply --filename=/etc/cilium.yaml --kubeconfig=/etc/kubernetes/admin.conf

# write secrets to the parent cluster
join_token="$(kubeadm token create --ttl=0 --description="Secondary token for automation" --v=9)"
ca_hash="$(openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -pubkey | openssl rsa -pubin -outform der 2> /dev/null | sha256sum)"

join_token_js="$(printf '{"stringData":{"token": "%s", "ca_hash": "%s"}}' "${join_token}" "sha256:${ca_hash%% *}")"

kubectl patch secret "${cluster}-join-token" --patch="${join_token_js}" --kubeconfig=/etc/parent-management-cluster/kubeconfig

admin_kubeconfig_js="$(printf '{"data":{"kubeconfig": "%s"}}' "$(base64 --wrap=0 < "/etc/kubernetes/admin.conf")")"

kubectl patch secret "${cluster}-kubeconfig" --patch="${admin_kubeconfig_js}" --kubeconfig=/etc/parent-management-cluster/kubeconfig
