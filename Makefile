all: cilium-1.7-eks.yaml

.PHONY: cilium-1.7-eks.yaml

cilium-1.7-eks.yaml:
	helm template cilium cilium/cilium --version 1.7.2 \
	  --set global.eni=true \
	  --set global.egressMasqueradeInterfaces=eth0 \
	  --set global.tunnel=disabled \
	  --set global.nodeinit.enabled=true \
	  --namespace kube-system > $@
