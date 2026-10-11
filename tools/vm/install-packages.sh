#!/usr/bin/env bash
# usage: sudo bash install-packages.sh [--vbox|--vmware]   (BASE VM, NAT attached)
set -euo pipefail
pkgs="traceroute tcpdump tshark curl wget iptables ethtool iproute2 netcat-openbsd iputils-ping python3 build-essential"
if [ "${1:-}" = --vbox ] && [ "$(dpkg --print-architecture)" = amd64 ]; then pkgs="$pkgs virtualbox-guest-utils"; fi
[ "${1:-}" = --vmware ] && pkgs="$pkgs open-vm-tools"
add-apt-repository -y multiverse >/dev/null 2>&1 || true
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y $pkgs
python3 -c 'import sys; v=sys.version_info; print("python", sys.version.split()[0]); sys.exit(0 if v[:2]==(3,10) else "WARN: expected Python 3.10")' || true
gcc --version | head -1
