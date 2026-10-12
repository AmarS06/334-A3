#!/usr/bin/env bash
# usage: sudo bash diag-connect.sh [HOST=10.10.3.10] [PORT=8000]   (CLIENT; why does a kernel-TCP connect fail?)
H=${1:-10.10.3.10}; P=${2:-8000}
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
echo "--- iptables (filter)"; iptables -S | grep -v '^-P .* ACCEPT$' || true
command -v nft >/dev/null && { echo "--- nft rules not from iptables"; nft list ruleset 2>/dev/null | grep -E 'reject|drop' | grep -v 'RST' | head -5; }
echo "--- route"; ip route get "$H"
echo "--- curl with capture"
cap=$(mktemp); timeout 6 tcpdump -nn -l -i any "host $H and (tcp port $P or icmp)" > "$cap" 2>/dev/null &
sleep 1.5
curl -sS -o /dev/null -w "http=%{http_code} bytes=%{size_download}\n" --max-time 4 "http://$H:$P/"; echo "curl exit=$?"
wait
echo "--- packets"; cat "$cap"; rm -f "$cap"
