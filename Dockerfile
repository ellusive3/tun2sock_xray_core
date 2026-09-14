# syntax=docker/dockerfile:1
# Target: MikroTik hEX S (E60iUGS) / EN7562CT, linux/arm/v5 only

ARG XRAY_VERSION=v26.3.27
ARG TUN2SOCKS_VERSION=v2.7.0

# Download official ARMv5 binaries (cross-platform, no QEMU compile)
FROM --platform=$BUILDPLATFORM alpine:3.21 AS downloader

ARG XRAY_VERSION
ARG TUN2SOCKS_VERSION

RUN apk add --no-cache ca-certificates curl unzip

WORKDIR /tmp

RUN curl -fsSL \
      -o xray.zip \
      "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-arm32-v5.zip" \
    && unzip -j xray.zip xray -d /out \
    && curl -fsSL \
      -o tun2socks.zip \
      "https://github.com/xjasonlyu/tun2socks/releases/download/${TUN2SOCKS_VERSION}/tun2socks-linux-armv5.zip" \
    && unzip -j tun2socks.zip -d /tmp/tun \
    && mv /tmp/tun/tun2socks-linux-armv5 /out/tun2socks \
    && chmod 0755 /out/xray /out/tun2socks \
    && ls -la /out/xray /out/tun2socks

# Runtime: Debian armel (library/debian has no arm/v5; use arm32v5/*)
FROM --platform=linux/arm/v5 arm32v5/debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      dnsutils \
      iputils-ping \
      iproute2 \
      iptables \
      procps \
      traceroute \
    && update-alternatives --set iptables /usr/sbin/iptables-legacy \
    && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy \
    && ln -sf "$(command -v traceroute)" /usr/local/bin/tracert \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /etc/xray /usr/local/bin

COPY --from=downloader ["/out/xray", "/usr/local/bin/xray"]
COPY --from=downloader ["/out/tun2socks", "/usr/local/bin/tun2socks"]
COPY ["entrypoint.sh", "/entrypoint.sh"]

RUN sed -i 's/\r$//' /entrypoint.sh \
    && ln -sf /entrypoint.sh /usr/local/bin/entrypoint.sh \
    && chmod 0755 /usr/local/bin/xray /usr/local/bin/tun2socks /entrypoint.sh /usr/local/bin/entrypoint.sh

# Mount your config on MikroTik: /etc/xray/config.json
ENV TUN_DEVICE=tun0 \
    TUN_ADDR=198.18.0.1/15 \
    XRAY_CONFIG=/etc/xray/config.json \
    SOCKS_PROXY=socks5://127.0.0.1:1080 \
    GATEWAY_MODE=1

ENTRYPOINT ["/entrypoint.sh"]
