IMAGE := errordeveloper/extract

build:
	docker build --tag $(IMAGE) .

push: build
	docker push $(IMAGE)
