FROM golang:1.26 AS builder

WORKDIR /app

# copy source
COPY . .
# codegen
RUN go generate ./...
# build
RUN go build -o bin/ -tags='netgo timetzdata' -trimpath -a -ldflags '-s -w' ./cmd/serve

FROM debian:bookworm-slim

LABEL maintainer="The Sia Foundation <info@sia.tech>" \
org.opencontainers.image.description.vendor="The Sia Foundation" \
org.opencontainers.image.description="Provides Linux Packages" \
org.opencontainers.image.source="https://github.com/SiaFoundation/nomad" \
org.opencontainers.image.licenses=MIT

# copy binary and certificates
COPY --from=builder /app/bin/* /usr/bin/
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# API port
EXPOSE 8080/tcp

ENTRYPOINT [ "serve" ]
