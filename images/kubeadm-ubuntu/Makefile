IMAGE := errordeveloper/kubeadm:ubuntu-18.04-1.18.0

build:
	docker image build --tag $(IMAGE) .

push: build
	docker image push $(IMAGE)
	docker image inspect --format '{{(index .RepoTags 0)}} {{(index .RepoDigests 0)}}' $(IMAGE) > .digest
