KATA_AGENT_VERSION = 1.11.0-alpha1

IMAGE := errordeveloper/kata-agent:$(KATA_AGENT_VERSION)-ubuntu-18.04

image:
	docker build --build-arg KATA_AGENT_VERSION=$(KATA_AGENT_VERSION) --tag $(IMAGE) .

push: image
	docker push $(IMAGE)
