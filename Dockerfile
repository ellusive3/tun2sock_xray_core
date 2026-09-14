FROM --platform=linux/arm/v5 debian:stable-slim

# Устанавливаем необходимые сетевые утилиты через apt
RUN apt-get update && apt-get install -y \
    iptables \
    iproute2 \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Скачиваем и распаковываем актуальный Xray-core для armv5
RUN curl -L -o /tmp/xray.zip https://github.com && \
    unzip /tmp/xray.zip -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/xray && \
    rm -rf /tmp/xray.zip

# Скачиваем и распаковываем актуальный tun2socks для armv5
RUN curl -L -o /tmp/tun2socks.zip https://github.com && \
    unzip /tmp/tun2socks.zip -d /tmp/ && \
    mv /tmp/tun2socks-linux-armv5 /usr/local/bin/tun2socks && \
    chmod +x /usr/local/bin/tun2socks && \
    rm -rf /tmp/tun2socks.zip

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

