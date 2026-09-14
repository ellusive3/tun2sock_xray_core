# === Stage 1: Компиляция бинарников через нативный Go ===
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder

# Компилируем Xray из локально скопированных исходников
COPY xray-src /src/xray
WORKDIR /src/xray
RUN env CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=5 go build -o /out/xray -v ./main

# Компилируем tun2socks из локально скопированных исходников
COPY tun2socks-src /src/tun2socks
WORKDIR /src/tun2socks
RUN env CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=5 go build -o /out/tun2socks -v

# === Stage 2: Сборка финального легкого образа ARMv5 ===
FROM --platform=linux/arm/v5 debian:stable-slim

RUN apt-get update && apt-get install -y iptables iproute2 && rm -rf /var/lib/apt/lists/*

# Переносим готовые скомпилированные файлы
COPY --from=builder /out/xray /usr/local/bin/xray
COPY --from=builder /out/tun2socks /usr/local/bin/tun2socks

RUN chmod +x /usr/local/bin/xray /usr/local/bin/tun2socks

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
