FROM --platform=linux/arm/v5 debian:stable-slim

# 1. Обновляем пакеты и ставим базовые утилиты
RUN apt-get update
RUN apt-get install -y iptables iproute2 curl unzip ca-certificates
RUN rm -rf /var/lib/apt/lists/*

# 2. Скачиваем Xray-core (без использования кавычек)
RUN curl -L -o /tmp/xray.zip https://github.com
RUN unzip /tmp/xray.zip -d /usr/local/bin/
RUN chmod +x /usr/local/bin/xray
RUN rm -rf /tmp/xray.zip

# 3. Скачиваем tun2socks (без использования кавычек)
RUN curl -L -o /tmp/tun2socks.zip https://github.com
RUN unzip /tmp/tun2socks.zip -d /tmp/
RUN mv /tmp/tun2socks-linux-armv5 /usr/local/bin/tun2socks
RUN chmod +x /usr/local/bin/tun2socks
RUN rm -rf /tmp/tun2socks.zip

# 4. Копируем скрипт запуска
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
