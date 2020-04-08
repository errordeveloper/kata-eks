KATA_AGENT_VERSION = c3ba09430# see https://github.com/kata-containers/agent/pull/768
IMAGE := errordeveloper/kata-agent:$(KATA_AGENT_VERSION)-ubuntu-18.04

# This image has to be built in two stages as `docker build` context doesn't
# allow mounting /dev and outher things that are required for loopback block
# device operations to work; perhaps we could improve that with buildkit/buildx
# in the future, but this works for now. Also, make-image.sh is kind of clunky
# anyway... it's got to be possible to create images for Linux on any OS!
# To include dropbear with your SSH key, run:
# `make DEBUG_SSH_PUBLIC_KEYS="$(cat ~/.ssh/id_rsa.pub)"`
build:
	docker image build --file Dockerfile.builder --build-arg "KATA_AGENT_VERSION=$(KATA_AGENT_VERSION)" --build-arg "DEBUG_SSH_PUBLIC_KEYS=$(DEBUG_SSH_PUBLIC_KEYS)" --tag $(IMAGE)-builder .
	container=$$(docker container create --interactive --tty --volume /dev:/dev --privileged $(IMAGE)-builder) \
	  && docker container start --attach --interactive $${container} \
	  && image_builder="$$(docker container commit $${container})" \
	  && cat Dockerfile | docker image build --build-arg "IMAGE_BUILDER=$${image_builder}" --tag $(IMAGE) - \
	  && cat Dockerfile.rootfs | docker image build --build-arg "IMAGE_BUILDER=$${image_builder}" --tag $(IMAGE)-rootfs - \
	  && docker container rm --force $${container}

push: build
	docker image push $(IMAGE)
	docker image push $(IMAGE)-rootfs
	docker image inspect --format '{{(index .RepoTags 0)}} {{(index .RepoDigests 0)}}' $(IMAGE) $(IMAGE)-rootfs > .digest
