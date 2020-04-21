#!/bin/bash -x

set -o errexit
set -o pipefail
set -o nounset

ready_pods=($(kubectl get pods -l role=master -o json | jq -r '.items[] | select(.status.phase == "Running") | .metadata.name'))

for pod in "${ready_pods[@]}" ; do
  kubectl exec "${pod}" -- kubectl "$@"
done
