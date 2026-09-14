#!/bin/sh
set -eu

TUN_DEVICE="${TUN_DEVICE:-tun0}"
TUN_ADDR="${TUN_ADDR:-198.18.0.3/15}"
XRAY_CONFIG="${XRAY_CONFIG:-/etc/xray/config.json}"
SOCKS_PROXY="${SOCKS_PROXY:-socks5://127.0.0.1:1080}"
OUT_INTERFACE="${OUT_INTERFACE:-eth0}"

if [ ! -f "$XRAY_CONFIG" ]; then
  echo "error: xray config not found: $XRAY_CONFIG" >&2
  echo "Mount config.json to /etc/xray/config.json (MikroTik /container/mounts)." >&2
  exit 1
fi

if [ ! -e "/sys/class/net/$TUN_DEVICE" ]; then
  ip tuntap add mode tun dev "$TUN_DEVICE"
fi

ip addr replace "$TUN_ADDR" dev "$TUN_DEVICE"
ip link set dev "$TUN_DEVICE" up

# May fail without CAP_SYS_ADMIN / privileged — ignore
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true

cleanup() {
  if [ -n "${XRAY_PID:-}" ] && kill -0 "$XRAY_PID" 2>/dev/null; then
    kill "$XRAY_PID" 2>/dev/null || true
    wait "$XRAY_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

/usr/local/bin/xray run -config "$XRAY_CONFIG" &
XRAY_PID=$!

# Wait until Xray is alive (socks inbound ready soon after process start)
i=0
while [ "$i" -lt 20 ]; do
  if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    echo "error: xray exited during startup" >&2
    wait "$XRAY_PID" || true
    exit 1
  fi
  # brief settle for inbound bind
  i=$((i + 1))
  [ "$i" -ge 2 ] && break
  sleep 1
done

# Drop trap so EXIT does not kill xray when shell is replaced by exec
trap - EXIT INT TERM

exec /usr/local/bin/tun2socks \
  -device "$TUN_DEVICE" \
  -proxy "$SOCKS_PROXY" \
  -interface "$OUT_INTERFACE"
