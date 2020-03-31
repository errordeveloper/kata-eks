KATA_AGENT_VERSION = 1.11.0-alpha1

IMAGE := errordeveloper/kata-agent:$(KATA_AGENT_VERSION)-ubuntu-18.04

# This image has to be built in two stages as `docker build` context doesn't
# allow mounting /dev and outher things that are required for loopback block
# device operations to work; perhaps we could improve that with buildkit/buildx
# in the future, but this works for now. Also, make-image.sh is kind of clunky
# anyway... it's got to be possible to create images for Linux on any OS!
image:
	docker build --file Dockerfile.builder --build-arg KATA_AGENT_VERSION=$(KATA_AGENT_VERSION) --tag $(IMAGE)-local .
	container=$$(docker create --interactive --tty --volume /dev:/dev --privileged $(IMAGE)-local) \
	  && docker start --attach --interactive $${container} \
	  && cat Dockerfile | docker build --build-arg IMAGE_BUILDER="$$(docker commit $${container})" --tag $(IMAGE) -

push: image
	docker push $(IMAGE)
