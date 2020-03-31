ARG IMAGE_BUILDER
FROM ${IMAGE_BUILDER} as image-builder
RUN rm -rf /out/dev /out/etc /out/proc /out/sys
FROM scratch
COPY --from=image-builder /out /
