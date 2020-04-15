#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

cluster="$(sed -n 's/^cluster="\(.*\)"$/\1/p' "/etc/kubeadm/metadata/labels")"

export KUBECONFIG="/etc/parent-management-cluster/kubeconfig"

join_token="$(kubeadm token create --ttl=0 --description="Secondary token for automation")"
ca_hash="$(sha256sum /etc/kubernetes/pki/ca.crt)"

join_token_js="$(printf '{"stringData":{"token": "%s", "ca_hash": "%s"}}' )" "${join_token}" "sha256:${hash%% *}"

kubectl patch secret "${cluster}-join-token" --patch="${join_token_js}"

admin_kubeconfig_js="$(printf '{"data":{"kubeconfig": "%s"}}' "$(base64 --wrap=0 < "/etc/kubernetes/admin.conf")")"

kubectl patch secret "${cluster}-kubeconfig" --patch="${admin_kubeconfig_js}"
