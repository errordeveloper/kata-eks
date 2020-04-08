IMAGES := \
  extract \
  kata-agent-ubuntu \
  kata-installer \
  kubeadm-ubuntu

.PHONY: $(IMAGES)

push: build
push build:
	$(MAKE) $(IMAGES) TARGET=$@

$(IMAGES):
	$(MAKE) -C $@ $(TARGET)
