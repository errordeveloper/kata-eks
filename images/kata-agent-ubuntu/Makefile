KATA_AGENT_VERSION = 1.11.0-alpha1

IMAGE := errordeveloper/kata-agent:$(KATA_AGENT_VERSION)-ubuntu-18.04

image:
	docker build --file Dockerfile.builder --build-arg KATA_AGENT_VERSION=$(KATA_AGENT_VERSION) --tag $(IMAGE)-local .
	container=$$(docker create --interactive --tty --volume /dev:/dev --privileged $(IMAGE)-local) \
	  && docker start --attach --interactive $${container} \
	  && cat Dockerfile | docker build --build-arg IMAGE_BUILDER="$$(docker commit $${container})" --tag $(IMAGE) -

push: image
	docker push $(IMAGE)
