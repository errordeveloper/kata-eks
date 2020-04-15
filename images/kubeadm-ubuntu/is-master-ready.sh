#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

export KUBECONFIG="/etc/kubernetes/admin.conf"

if ! systemctl --no-pager is-active kubeadm@master.target > /dev/null ; then
  echo "systemd kubeadm@master.target is not yet active"
  exit 1
fi

if ! [ -e "${KUBECONFIG}" ] ; then
  echo "${KUBECONFIG} has not been written yet"
  exit 1
fi

node_name="$(hostname)"

jsonpath='{@.status.conditions[?(@.type=="Ready")].status}'
ready="$(kubectl get node "${node_name}" --output "jsonpath=${jsonpath}" || printf Error)"

if ! [ "${ready}" = "True" ] ; then
  echo "node ${node_name} is not ready yet"
  exit 1
fi

if systemctl --no-pager is-failed kubeadm@master.service > /dev/null ; then
  echo "systemd kubeadm@master.service has failed"
  exit 1
fi

echo "node ${node_name} is ready now"
exit 0
