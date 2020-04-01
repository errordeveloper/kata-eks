ARG IMAGE_BUILDER
FROM ${IMAGE_BUILDER} as image-builder
RUN rm -rf /out/dev /out/etc /out/proc /out/sys
FROM errordeveloper/extract@sha256:64e36b6d6624e4e71b4b1dd8f9688a0aa8f02639e64ac11cc1625ee2a3aa5729
COPY --from=image-builder /out /in
CMD [ "-C", "/out", "/in/kata.img", "/in/kernel-4.19.104-linuxkit" ]
