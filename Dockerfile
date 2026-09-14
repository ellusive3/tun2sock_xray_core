# === Stage 1: Build Xray and tun2socks from source using Go ===
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder

# Build Xray-core
RUN apk add --no-cache git
RUN git clone https://github.com /src/xray
WORKDIR /src/xray
RUN env CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=5 go build -o /out/xray -v ./main

# Build tun2socks
RUN git clone https://github.com /src/tun2socks
WORKDIR /src/tun2socks
RUN env CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=5 go build -o /out/tun2socks -v

# === Stage 2: Create the final lightweight ARMv5 image ===
FROM --platform=linux/arm/v5 debian:stable-slim

RUN apt-get update && apt-get install -y iptables iproute2 && rm -rf /var/lib/apt/lists/*

# Copy binaries from the builder stage
COPY --from=builder /out/xray /usr/local/bin/xray
COPY --from=builder /out/tun2socks /usr/local/bin/tun2socks

RUN chmod +x /usr/local/bin/xray /usr/local/bin/tun2socks

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
