#!/usr/bin/env bash
# usage: bash tools/vm/vbox-clone-topology.sh create|map|snapshot NAME|restore NAME|destroy   (HOST, VirtualBox)
set -euo pipefail
BASE=${A3_BASE:-a3-base}; SEAL=base-sealed; NODES="client r1 r2 server"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
nets(){ case $1 in client) echo "LAN_A LINK_D";; r1) echo "LAN_A LAN_B";; r2) echo "LAN_B LAN_C LINK_D";; server) echo "LAN_C";; esac; }
off(){ VBoxManage showvminfo "$1" --machinereadable | grep -q '^VMState="poweroff"' || { echo "$1 must be powered off" >&2; exit 1; }; }
has_snap(){ VBoxManage snapshot "$1" list --machinereadable 2>/dev/null | grep -q "=\"$2\"$"; }
case ${1:?usage: $0 create|map|snapshot NAME|restore NAME|destroy} in
  create)
    off "$BASE"
    VBoxManage storageattach "$BASE" --storagectl SATA --port 1 --device 0 --medium emptydrive 2>/dev/null || true
    has_snap "$BASE" "$SEAL" || VBoxManage snapshot "$BASE" take "$SEAL"
    for n in $NODES; do
      vm="a3-$n"
      if VBoxManage showvminfo "$vm" >/dev/null 2>&1; then echo "$vm exists, skipping"; continue; fi
      VBoxManage clonevm "$BASE" --snapshot "$SEAL" --options link --name "$vm" --register
      VBoxManage modifyvm "$vm" --nic1 none --nic2 none --nic3 none --nic4 none
      i=1; for net in $(nets "$n"); do
        VBoxManage modifyvm "$vm" "--nic$i" intnet "--intnet$i" "$net" "--nictype$i" 82540EM "--macaddress$i" auto "--cableconnected$i" on
        i=$((i+1)); done
      VBoxManage sharedfolder remove "$vm" --name a3 >/dev/null 2>&1 || true
      VBoxManage sharedfolder add "$vm" --name a3 --hostpath "$REPO" --automount --auto-mount-point /mnt/a3
      echo "created $vm: $(nets "$n")"
    done
    if VBoxManage list dhcpservers | grep -E 'NetworkName:.*(LAN_A|LAN_B|LAN_C|LINK_D)'; then echo "WARNING: a DHCP server is attached to an A3 network; remove it" >&2; fi;;
  map)
    for n in $NODES; do echo "== a3-$n"; VBoxManage showvminfo "a3-$n" --machinereadable | grep -E '^(macaddress|intnet)[0-9]=' ; done
    echo "Linux shows MACs as aa:bb:..; match them with 'ip -br link' in each VM and fill docs/vm-map.md";;
  snapshot) s=${2:?snapshot name}; for n in $NODES; do off "a3-$n"; has_snap "a3-$n" "$s" && VBoxManage snapshot "a3-$n" delete "$s"; VBoxManage snapshot "a3-$n" take "$s"; done;;
  restore)  s=${2:?snapshot name}; for n in $NODES; do off "a3-$n"; VBoxManage snapshot "a3-$n" restore "$s"; done;;
  destroy)  for n in $NODES; do VBoxManage unregistervm "a3-$n" --delete 2>/dev/null && echo "deleted a3-$n" || true; done;;
  *) echo "unknown command" >&2; exit 1;;
esac
