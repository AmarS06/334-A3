#!/usr/bin/env bash
# usage: sudo bash netem.sh IF show|clear | IF lossy [loss%] [delay] [reorder%] | IF bottleneck [rate] [delay] [loss%]
set -euo pipefail
IF=${1:?IF}; cmd=${2:?cmd}
case $cmd in
  show)  tc -s qdisc show dev "$IF";;
  clear) tc qdisc del dev "$IF" root 2>/dev/null || true; echo cleared;;
  lossy) tc qdisc replace dev "$IF" root netem loss "${3:-5}%" delay "${4:-10ms}" 5ms reorder "${5:-25}%" 50%;;
  bottleneck)
    tc qdisc replace dev "$IF" root handle 1: netem delay "${4:-10ms}" loss "${5:-0}%"
    tc qdisc add dev "$IF" parent 1: handle 2: tbf rate "${3:-20mbit}" burst 32kbit latency 100ms
    echo "keep rate*RTT < 64KB (G8)";;
  *) echo "unknown cmd" >&2; exit 1;;
esac
