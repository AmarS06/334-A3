#!/usr/bin/env bash
# usage: bash check-fresh.sh   (each CLONE, after node-init.sh + reboot; S6/S7 fresh-state check)
set -uo pipefail
bad=0
ok() { printf 'OK    %s\n' "$1"; }
no() { printf 'FAIL  %s\n' "$1"; bad=1; }
name=$(hostname)
case $name in
    client) want=2 ;;
    r1) want=2 ;;
    r2) want=3 ;;
    server) want=1 ;;
    *) want=-1 ;;
esac
[ "$want" -ge 0 ] && ok "hostname $name" || no "hostname is '$name' (run node-init.sh)"
if [ -r /mnt/a3/TRANSFER_STAMP ]; then ok "transfer image $(cat /mnt/a3/TRANSFER_STAMP)"
else no "/mnt/a3/TRANSFER_STAMP missing (sudo mount /mnt/a3; rebuild image with xorriso)"; fi
[ -x /mnt/a3/tools/vm/check-fresh.sh ] && ok "execute bits kept" || no "no execute bits on /mnt/a3 (image built without Rock Ridge)"
links=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2}' | cut -d@ -f1)
n=$(printf '%s\n' "$links" | grep -c .)
[ "$n" -eq "$want" ] && ok "$n interfaces besides lo" || no "$n interfaces besides lo, expected $want"
addrs=$(ip -4 -o addr show | awk '$2 != "lo" {print $2, $4}')
[ -z "$addrs" ] && ok "no IPv4 address outside lo" || no "IPv4 present: $addrs"
routes=$(ip -4 route show)
[ -z "$routes" ] && ok "no IPv4 routes" || no "routes present: $(echo "$routes" | tr '\n' ';')"
rp=$(sysctl -a 2>/dev/null | awk '/\.rp_filter/ && $3 != 1 {print $1"="$3}' | tr "\n" " ")
[ -z "$rp" ] && ok "every rp_filter = 1" || no "rp_filter not 1: $rp"
[ "$(sysctl -n net.ipv4.ip_forward)" = 0 ] && ok "ip_forward = 0" || no "ip_forward = 1"
ls /etc/netplan/*.yaml >/dev/null 2>&1 && no "netplan config present (seal-base.sh not run?)" || ok "no netplan config"
[ -e /etc/cloud/cloud-init.disabled ] && ok "cloud-init disabled" || no "cloud-init not disabled (seal-base.sh not run?)"
echo "-- interface map line (send to Claude / docs/vm-map.md):"
for i in $links; do printf '%s %s %s %s\n' "$name" "$i" "$(cat /sys/class/net/$i/address)" "$(cat /sys/class/net/$i/operstate)"; done
[ $bad -eq 0 ] && echo "RESULT: fresh state OK" || echo "RESULT: problems above"
exit $bad
