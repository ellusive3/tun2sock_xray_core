#!/bin/sh

# Создаем интерфейс tun0
ip tuntap add mode tun dev tun0
ip addr add 198.18.0.3/15 dev tun0
ip link set dev tun0 up

# Включаем форвардинг трафика внутри контейнера
sysctl -w net.ipv4.ip_forward=1

# Запускаем Xray в фоновом режиме
/usr/local/bin/xray run -config /etc/xray/config.json &

# Даем Xray 2 секунды на старт
sleep 2

# Запускаем tun2socks в основном режиме (процесс не должен завершаться)
# Он слушает tun0 и отправляет всё в локальный Xray (127.0.0.1:1080)
exec /usr/local/bin/tun2socks -device tun0 -proxy socks5://127.0.0.1:1080 -interface eth0
