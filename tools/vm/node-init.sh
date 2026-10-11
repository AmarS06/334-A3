#!/usr/bin/env bash
# usage: sudo bash node-init.sh client|r1|r2|server   (each CLONE, once, from S6; then reboot)
set -euo pipefail
name=${1:-}
case $name in
    client) want=2 ;;
    r1) want=2 ;;
    r2) want=3 ;;
    server) want=1 ;;
    *) echo "usage: sudo bash $0 client|r1|r2|server" >&2; exit 1 ;;
esac
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
old=$(hostname)
hostnamectl set-hostname "$name" 2>/dev/null || { echo "$name" > /etc/hostname; hostname "$name"; }
if grep -q '^127\.0\.1\.1' /etc/hosts; then
    sed -i "s/^127\.0\.1\.1.*/127.0.1.1 $name/" /etc/hosts
else
    echo "127.0.1.1 $name" >> /etc/hosts
fi
mkdir -p /mnt/a3
sed -i '\#/mnt/a3#d' /etc/fstab
echo '/dev/sr0 /mnt/a3 iso9660 ro,nofail 0 0' >> /etc/fstab
systemctl daemon-reload 2>/dev/null || true
have=$(ip -o link show | awk -F': ' '$2 != "lo" {n++} END {print n+0}')
echo "hostname: $old -> $name"
echo "fstab:    $(grep /mnt/a3 /etc/fstab)"
if [ "$have" -eq "$want" ]; then
    echo "links:    $have non-lo interfaces (OK)"
else
    echo "links:    $have non-lo interfaces, expected $want (check adapters: vbox-clone-topology.sh map)" >&2
fi
echo "next:     sudo reboot, then: bash /mnt/a3/tools/vm/check-fresh.sh"
