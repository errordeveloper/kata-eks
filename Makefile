CILIUM_MANIFESTS := \
  cilium-1.7-eks.yaml \
  images/kubeadm-ubuntu/cilium-1.7-kubeadm.yaml

manifest: $(CILIUM_MANIFESTS)
all: manifest images-push

.PHONY: $(CILIUM_MANIFESTS) manifest images-build image-push 

cilium-1.7-eks.yaml:
	helm template cilium cilium/cilium --version 1.7.2 \
	  --set global.eni=true \
	  --set global.egressMasqueradeInterfaces=eth0 \
	  --set global.tunnel=disabled \
	  --set global.nodeinit.enabled=true \
	  --namespace kube-system > $@

images/kubeadm-ubuntu/cilium-1.7-kubeadm.yaml:
	helm template cilium cilium/cilium --version 1.7.2 \
	  --namespace kube-system > $@

images-build:
	$(MAKE) -C images build

images-push:
	$(MAKE) -C images push

show-digests:
	-@cat images/*/.digest 2>/dev/null
