#!/usr/bin/env bash
# usage: sudo bash tools/netns/a3-topology.sh up|configure|status|exec NODE CMD...|down   (Linux/WSL2 dev sandbox, not a substitute for the VMs)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"; NETCFG=${A3_NETCFG:-$REPO/netcfg}; NODES="client r1 r2 server"
LINKS="A client ethA r1 ethA
B r1 ethB r2 ethB
C r2 ethC server ethC
D client ethD r2 ethD"
args(){ case $1 in client) echo "ethA ethD";; r1) echo "ethA ethB";; r2) echo "ethB ethC ethD";; server) echo "ethC";; esac; }
case ${1:?usage} in
  up)
    for n in $NODES; do
      ip netns add "a3-$n"; ip -n "a3-$n" link set lo up
      ip netns exec "a3-$n" sysctl -qw net.ipv4.conf.all.rp_filter=1 net.ipv4.conf.default.rp_filter=1 net.ipv4.ip_forward=0
    done
    while read -r net a ia b ib; do
      ip link add "a3t${net}0" type veth peer name "a3t${net}1"
      ip link set "a3t${net}0" netns "a3-$a"; ip -n "a3-$a" link set "a3t${net}0" name "$ia"
      ip link set "a3t${net}1" netns "a3-$b"; ip -n "a3-$b" link set "a3t${net}1" name "$ib"
      ip netns exec "a3-$a" sysctl -qw "net.ipv4.conf.$ia.rp_filter=1"
      ip netns exec "a3-$b" sysctl -qw "net.ipv4.conf.$ib.rp_filter=1"
      ip netns exec "a3-$a" ethtool -K "$ia" tx off >/dev/null 2>&1 || true
      ip netns exec "a3-$b" ethtool -K "$ib" tx off >/dev/null 2>&1 || true
    done <<< "$LINKS"
    echo "namespaces up: interfaces DOWN, no addresses, rp_filter=1 (fresh-boot equivalent)";;
  configure) for n in $NODES; do echo "== $n"; ip netns exec "a3-$n" bash "$NETCFG/$n.sh" $(args "$n"); done;;
  status) for n in $NODES; do echo "== $n"; ip -n "a3-$n" -br addr; ip -n "a3-$n" route; done;;
  exec) n=${2:?node}; shift 2; exec ip netns exec "a3-$n" "$@";;
  down) for n in $NODES; do ip netns del "a3-$n" 2>/dev/null || true; done; echo down;;
  *) echo "unknown command" >&2; exit 1;;
esac
