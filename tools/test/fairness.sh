#!/usr/bin/env bash
# usage: sudo bash fairness.sh OUR_URL[,OUR_URL2...] STD_URL [N] [M]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUR=${1:?OUR_URL(s)}; STD=${2:?STD_URL}; N=${3:-1}; M=${4:-1}
IFS=, read -ra OURS <<< "$OUR"; T=$(mktemp -d)
for i in $(seq 1 "$N"); do u=${OURS[$(( (i-1) % ${#OURS[@]} ))]}
  ( s=$(date +%s.%N); "$ROOT/client/run-client" "$u" -o "$T/our$i" 2>/dev/null; rc=$?; e=$(date +%s.%N)
    echo "ours#$i rc=$rc $(stat -c%s "$T/our$i" 2>/dev/null || echo 0) $s $e" > "$T/r.our$i" ) &
done
for i in $(seq 1 "$M"); do
  ( s=$(date +%s.%N); curl -s -o "$T/curl$i" "$STD"; rc=$?; e=$(date +%s.%N)
    echo "curl#$i rc=$rc $(stat -c%s "$T/curl$i" 2>/dev/null || echo 0) $s $e" > "$T/r.curl$i" ) &
done
wait
cat "$T"/r.* | awk '{d=$5-$4; printf "%-8s %-5s %10d bytes %7.2f s %8.2f Mbit/s\n",$1,$2,$3,d,($3*8/1e6)/d}'
echo "Note: compare throughput only over the overlap period; use same-size files and start together."
rm -rf "$T"
