FROM --platform=linux/arm/v5 alpine:latest

# Устанавливаем необходимые сетевые утилиты
RUN apk add --no-cache iptables iproute2 curl unzip

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

# Копируем конфигурацию и скрипт запуска
COPY config.json /etc/xray/config.json
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
