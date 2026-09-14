FROM --platform=linux/arm/v5 debian:stable-slim

# Устанавливаем ca-certificates для работы SSL/HTTPS, а также curl и unzip
RUN apt-get update && apt-get install -y \
    iptables \
    iproute2 \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Скачиваем стабильный Xray-core v25.1.30 для arm32v5 по прямой ссылке
RUN curl -L -o /tmp/xray.zip "https://github.com" && \
    unzip /tmp/xray.zip -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/xray && \
    rm -rf /tmp/xray.zip

# Скачиваем стабильный tun2socks v2.5.2 для armv5 по прямой ссылке
RUN curl -L -o /tmp/tun2socks.zip "https://github.com" && \
    unzip /tmp/tun2socks.zip -d /tmp/ && \
    mv /tmp/tun2socks-linux-armv5 /usr/local/bin/tun2socks && \
    chmod +x /usr/local/bin/tun2socks && \
    rm -rf /tmp/tun2socks.zip

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

