FROM golang:1.14.1@sha256:08d16c1e689e86df1dae66d8ef4cec49a9d822299ec45e68a810c46cb705628d as builder
COPY extract.go /go/src/extract/extract.go
RUN go build -ldflags '-extldflags "-fno-PIC -static"' -buildmode pie -tags 'osusergo netgo static_build' -o /bin/extract /go/src/extract

FROM scratch as rootfs
COPY --from=builder /bin/extract /bin/extract
ENTRYPOINT ["/bin/extract"]
