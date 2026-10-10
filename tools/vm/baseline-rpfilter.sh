#!/usr/bin/env bash
# usage: sudo bash baseline-rpfilter.sh
set -euo pipefail
conf=/etc/sysctl.d/99-a3-rpfilter.conf
printf 'net.ipv4.conf.all.rp_filter=1\nnet.ipv4.conf.default.rp_filter=1\n' > "$conf"
for d in /proc/sys/net/ipv4/conf/*/; do
  i=$(basename "$d"); sysctl -qw "net.ipv4.conf.$i.rp_filter=1"
  case $i in all|default) ;; *) echo "net.ipv4.conf.$i.rp_filter=1" >> "$conf";; esac
done
sysctl -a 2>/dev/null | grep '\.rp_filter'
