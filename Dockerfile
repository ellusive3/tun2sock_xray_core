# === Stage 1: Compile binaries using native Go ===
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder

# Install git since it's required for some internal go module resolutions
RUN apk add --no-cache git

# Compile Xray from locally copied sources
COPY xray-src /src/xray
WORKDIR /src/xray
# Changed from ./main to . (the root directory)
RUN env CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=5 go build -o /out/xray -v .

# Compile tun2socks from locally copied sources
COPY tun2socks-src /src/tun2socks
WORKDIR /src/tun2socks
RUN env CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=5 go build -o /out/tun2socks -v

# === Stage 2: Build final lightweight ARMv5 image ===
FROM --platform=linux/arm/v5 debian:stable-slim

RUN apt-get update && apt-get install -y iptables iproute2 && rm -rf /var/lib/apt/lists/*

# Copy compiled files over
COPY --from=builder /out/xray /usr/local/bin/xray
COPY --from=builder /out/tun2socks /usr/local/bin/tun2socks

RUN chmod +x /usr/local/bin/xray /usr/local/bin/tun2socks

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
