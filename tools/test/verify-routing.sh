#!/usr/bin/env bash
# usage: bash verify-routing.sh client|r1|r2|server
me=${1:?usage: $0 client|r1|r2|server}
ALL="10.10.1.10 10.10.1.1 10.10.2.1 10.10.2.2 10.10.3.1 10.10.3.10"
[ "$me" = client ] && ALL="$ALL 10.10.4.1"
[ "$me" = r2 ] && ALL="$ALL 10.10.4.2"
pass=0; fail=0
for a in $ALL; do
  if ping -c1 -W1 "$a" >/dev/null 2>&1; then echo "PASS ping $a"; pass=$((pass+1)); else echo "FAIL ping $a"; fail=$((fail+1)); fi
done
echo "--- forwarding / rp_filter"
sysctl net.ipv4.ip_forward; sysctl -a 2>/dev/null | grep -E '\.(forwarding|rp_filter) ' | grep -v -E 'lo\.|ipv6'
echo "--- routes"; ip route
case $me in
  client) echo "--- traceroute to server (expect 10.10.1.1, 10.10.4.1, 10.10.3.10)"; traceroute -n 10.10.3.10;;
  server) echo "--- traceroute to client (expect 10.10.3.1, 10.10.1.10)"; traceroute -n 10.10.1.10;;
esac
echo "pings: $pass passed, $fail failed"; [ $fail -eq 0 ]
