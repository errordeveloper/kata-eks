IMAGE := errordeveloper/extract

image:
	docker build --tag $(IMAGE) .

push: image
	docker push $(IMAGE)
