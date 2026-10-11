#!/usr/bin/env bash
# usage: bash tools/host/check-host.sh
. "$(dirname "$0")/gnu-path.sh"
OS=$(uname -s); [ -n "${WSL_DISTRO_NAME:-}" ] && OS=WSL
miss=0
row(){ printf '%-10s %-8s %s\n' "$1" "$2" "$3"; }
chk(){ local name=$1 need=$2 hint=$3; shift 3
  for c in "$@"; do if command -v "$c" >/dev/null 2>&1; then row "$name" OK "$(command -v "$c")"; return; fi; done
  row "$name" "$need" "$hint"; [ "$need" = MISSING ] && miss=1; }
echo "host: $OS"
chk git        MISSING "apt install git | brew install git | winget install Git.Git" git
chk python3.10 MISSING "apt install python3.10 python3.10-venv (deadsnakes on non-22.04) | brew install python@3.10 | pyenv install 3.10" python3.10
chk zip        MISSING "apt install zip unzip | preinstalled on macOS" zip
case $OS in
  Darwin)
    chk bash4    MISSING "brew install bash" "$( [ -x /opt/homebrew/bin/bash ] && echo /opt/homebrew/bin/bash || echo bash-missing )"
    chk gnu-grep MISSING "brew install grep gnu-sed coreutils" ggrep
    chk gnu-sed  MISSING "brew install gnu-sed" gsed
    chk hypervisor MISSING "brew install --cask virtualbox (7.1 or newer; setup.md S4)" VBoxManage vmrun utmctl;;
  *)      chk hypervisor MISSING "apt install virtualbox | winget install Oracle.VirtualBox (Windows side)" VBoxManage VBoxManage.exe;;
esac
chk wireshark  optional "apt install wireshark | brew install --cask wireshark | winget install WiresharkFoundation.Wireshark" wireshark tshark
chk pandoc     optional "report build: apt install pandoc | brew install pandoc | winget install JohnMacFarlane.Pandoc" pandoc
chk node       optional "audit (Dolos): Node.js LTS via nvm / brew install node / winget install OpenJS.NodeJS.LTS" node
chk java       optional "audit (JPlag): a recent JDK, e.g. apt install openjdk-21-jdk / brew install --cask temurin" java
if [ -x .venv/bin/ruff ]; then row ruff OK "$(.venv/bin/ruff --version)"; else row ruff optional "run tools/host/setup-dev.sh"; fi
if [ "$OS" = Linux ] || [ "$OS" = WSL ]; then
  for c in ip tc iptables tcpdump traceroute curl wget nc; do chk "$c" optional "netns sandbox: apt install iproute2 iptables tcpdump traceroute curl wget netcat-openbsd" "$c"; done
fi
[ $miss -eq 0 ] && echo "All required host tools present." || { echo "Install the MISSING items above."; exit 1; }
