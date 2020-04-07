KATA_AGENT_VERSION = c3ba09430# see https://github.com/kata-containers/agent/pull/768
IMAGE := errordeveloper/kata-agent:$(KATA_AGENT_VERSION)-ubuntu-18.04

# This image has to be built in two stages as `docker build` context doesn't
# allow mounting /dev and outher things that are required for loopback block
# device operations to work; perhaps we could improve that with buildkit/buildx
# in the future, but this works for now. Also, make-image.sh is kind of clunky
# anyway... it's got to be possible to create images for Linux on any OS!
# To include dropbear with your SSH key, run:
# `make DEBUG_SSH_PUBLIC_KEYS="$(cat ~/.ssh/id_rsa.pub)"`
image:
	docker build --file Dockerfile.builder --build-arg "KATA_AGENT_VERSION=$(KATA_AGENT_VERSION)" --build-arg "DEBUG_SSH_PUBLIC_KEYS=$(DEBUG_SSH_PUBLIC_KEYS)" --tag $(IMAGE)-builder .
	container=$$(docker create --interactive --tty --volume /dev:/dev --privileged $(IMAGE)-builder) \
	  && docker start --attach --interactive $${container} \
	  && image_builder="$$(docker commit $${container})" \
	  && cat Dockerfile | docker build --build-arg IMAGE_BUILDER="$${image_builder}" --tag $(IMAGE) - \
	  && cat Dockerfile.rootfs | docker build --build-arg IMAGE_BUILDER="$${image_builder}" --tag $(IMAGE)-rootfs -

push: image
	docker push $(IMAGE)
	docker push $(IMAGE)-rootfs
