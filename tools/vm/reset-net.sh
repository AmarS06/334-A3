#!/usr/bin/env bash
# usage: sudo bash reset-net.sh IF...
set -euo pipefail
[ $# -ge 1 ] || { echo "usage: $0 IF..." >&2; exit 1; }
for i in "$@"; do
  ip route flush dev "$i" 2>/dev/null || true
  ip addr flush dev "$i"
  ip link set "$i" down
  sysctl -qw "net.ipv4.conf.$i.rp_filter=1" "net.ipv4.conf.$i.forwarding=0"
done
sysctl -qw net.ipv4.conf.all.rp_filter=1 net.ipv4.ip_forward=0
ip -br addr; ip route
