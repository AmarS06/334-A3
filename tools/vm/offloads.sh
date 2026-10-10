#!/usr/bin/env bash
# usage: sudo bash offloads.sh show|off|on IF...
set -euo pipefail
mode=${1:?show|off|on}; shift
for i in "$@"; do
  case $mode in
    show) echo "== $i"; ethtool -k "$i" | grep -E 'generic-receive|large-receive|tcp-segmentation|generic-segmentation';;
    off)  ethtool -K "$i" gro off; ethtool -K "$i" lro off 2>/dev/null || true; echo "$i: GRO off";;
    on)   ethtool -K "$i" gro on; echo "$i: GRO on";;
  esac
done
