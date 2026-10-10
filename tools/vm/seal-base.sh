#!/usr/bin/env bash
# usage: sudo bash seal-base.sh   (BASE VM, after install-packages.sh, before cloning)
set -euo pipefail
mkdir -p /etc/cloud/cloud.cfg.d /root/netplan-disabled
echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
touch /etc/cloud/cloud-init.disabled
for f in /etc/netplan/*.yaml; do [ -e "$f" ] && mv "$f" /root/netplan-disabled/; done
systemctl mask systemd-networkd-wait-online.service >/dev/null 2>&1 || true
systemctl disable --now NetworkManager >/dev/null 2>&1 || true
bash "$(dirname "$0")/baseline-rpfilter.sh" >/dev/null
echo "sealed: netplan configs moved to /root/netplan-disabled, cloud-init disabled, wait-online masked, rp_filter=1 persisted"
