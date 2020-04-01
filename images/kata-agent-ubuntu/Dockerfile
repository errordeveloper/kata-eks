ARG IMAGE_BUILDER
FROM ${IMAGE_BUILDER} as image-builder
FROM errordeveloper/extract@sha256:64e36b6d6624e4e71b4b1dd8f9688a0aa8f02639e64ac11cc1625ee2a3aa5729
COPY --from=image-builder /out /
CMD [ "-C", "/out", "kata.img", "kernel-4.19.104-linuxkit","vmlinuz-4.15.0-91-generic", "vmlinuz-4.18.0-25-generic", "vmlinuz-5.0.0-43-generic", "vmlinuz-5.3.0-45-generic", "vmlinuz-4.15.0-1056-kvm", "vmlinuz-3.10.0-1062.18.1.el7.x86_64", "vmlinuz-4.18.0-147.5.1.el8_1.x86_64" ]
