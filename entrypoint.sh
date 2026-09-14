#!/bin/sh
set -eu

TUN_DEVICE="${TUN_DEVICE:-tun0}"
TUN_ADDR="${TUN_ADDR:-198.18.0.1/15}"
XRAY_CONFIG="${XRAY_CONFIG:-/etc/xray/config.json}"
SOCKS_PROXY="${SOCKS_PROXY:-socks5://127.0.0.1:1080}"
OUT_INTERFACE="${OUT_INTERFACE:-}"
# 1 = accept traffic from MikroTik (eth0/veth) and send it into TUN
GATEWAY_MODE="${GATEWAY_MODE:-1}"

if [ ! -f "$XRAY_CONFIG" ]; then
  echo "error: xray config not found: $XRAY_CONFIG" >&2
  echo "Mount config.json to /etc/xray/config.json (MikroTik /container/mounts)." >&2
  exit 1
fi

resolve_out_interface() {
  if [ -n "$OUT_INTERFACE" ] && [ -e "/sys/class/net/$OUT_INTERFACE" ]; then
    printf '%s\n' "$OUT_INTERFACE"
    return 0
  fi

  # Prefer the interface used by the default route (MikroTik veth gateway).
  iface=$(ip -4 route show default 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit }}')
  if [ -n "$iface" ] && [ -e "/sys/class/net/$iface" ]; then
    printf '%s\n' "$iface"
    return 0
  fi

  # Fallback: first non-loopback / non-TUN iface.
  for path in /sys/class/net/*; do
    name=$(basename "$path")
    case "$name" in
      lo|tun*|docker*|br-*|cni*|flannel*|wg*) continue ;;
    esac
    printf '%s\n' "$name"
    return 0
  done

  return 1
}

OUT_INTERFACE=$(resolve_out_interface) || {
  echo "error: could not detect outbound interface" >&2
  ip -o link show >&2 || true
  exit 1
}
echo "using outbound interface: $OUT_INTERFACE"

if [ ! -e "/sys/class/net/$TUN_DEVICE" ]; then
  ip tuntap add mode tun dev "$TUN_DEVICE"
fi

ip addr replace "$TUN_ADDR" dev "$TUN_DEVICE"
ip link set dev "$TUN_DEVICE" up

sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf."$OUT_INTERFACE".rp_filter=0 >/dev/null 2>&1 || true

# RouterOS container kernel often rejects iptables-nft; prefer legacy and never abort.
if command -v iptables-legacy >/dev/null 2>&1; then
  IPTABLES=iptables-legacy
elif command -v iptables >/dev/null 2>&1; then
  IPTABLES=iptables
else
  IPTABLES=
fi

iptables_try() {
  if [ -n "$IPTABLES" ]; then
    "$IPTABLES" "$@" 2>/dev/null || true
  fi
}

if [ "$GATEWAY_MODE" = "1" ]; then
  # Locally generated traffic (Xray → VLESS) stays on main table via default GW.
  # Packets arriving from the router are policy-routed into TUN.
  ip route replace default dev "$TUN_DEVICE" table 100
  ip rule del iif "$OUT_INTERFACE" lookup 100 2>/dev/null || true
  ip rule add iif "$OUT_INTERFACE" lookup 100 priority 100

  # Optional; MikroTik usually SNATs toward veth already. Do not fail startup.
  iptables_try -C FORWARD -i "$OUT_INTERFACE" -o "$TUN_DEVICE" -j ACCEPT \
    || iptables_try -A FORWARD -i "$OUT_INTERFACE" -o "$TUN_DEVICE" -j ACCEPT
  iptables_try -C FORWARD -i "$TUN_DEVICE" -o "$OUT_INTERFACE" -j ACCEPT \
    || iptables_try -A FORWARD -i "$TUN_DEVICE" -o "$OUT_INTERFACE" -j ACCEPT
  iptables_try -t nat -C POSTROUTING -o "$TUN_DEVICE" -j MASQUERADE \
    || iptables_try -t nat -A POSTROUTING -o "$TUN_DEVICE" -j MASQUERADE
fi

cleanup() {
  if [ -n "${XRAY_PID:-}" ] && kill -0 "$XRAY_PID" 2>/dev/null; then
    kill "$XRAY_PID" 2>/dev/null || true
    wait "$XRAY_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

/usr/local/bin/xray run -config "$XRAY_CONFIG" &
XRAY_PID=$!

i=0
while [ "$i" -lt 20 ]; do
  if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    echo "error: xray exited during startup" >&2
    wait "$XRAY_PID" || true
    exit 1
  fi
  i=$((i + 1))
  [ "$i" -ge 2 ] && break
  sleep 1
done

trap - EXIT INT TERM

exec /usr/local/bin/tun2socks \
  --device "$TUN_DEVICE" \
  --proxy "$SOCKS_PROXY" \
  --interface "$OUT_INTERFACE"
