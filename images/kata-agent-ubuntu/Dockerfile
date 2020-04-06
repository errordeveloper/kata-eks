ARG IMAGE_BUILDER
FROM ${IMAGE_BUILDER} as image-builder
FROM errordeveloper/extract@sha256:10df1869daa458b895fc9fdd5f3bc3314627468aae7cd44619cbdc6c5d6412be
COPY --from=image-builder /out /data
CMD [ "-C", "/out" ]
