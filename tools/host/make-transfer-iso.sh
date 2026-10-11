#!/usr/bin/env bash
# usage: bash tools/host/make-transfer-iso.sh [OUT=~/A3-VMs/a3-transfer.iso]   (HOST; then: vbox-clone-topology.sh transfer)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT=${1:-"$HOME/A3-VMs/a3-transfer.iso"}
mkdir -p "$(dirname "$OUT")"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/a3"
(cd "$ROOT" && tar cf - --exclude=.git --exclude=.venv --exclude=refcorpus --exclude=scratch \
    --exclude=captures --exclude=dist --exclude=audit-out --exclude=tests/www --exclude=__pycache__ \
    --exclude=.ruff_cache --exclude='*.pcap' --exclude='*.pcapng' --exclude=.DS_Store \
    --exclude=./COL334_assignment_3.pdf .) | (cd "$STAGE/a3" && tar xf -)
date "+%Y-%m-%d %H:%M:%S" > "$STAGE/a3/TRANSFER_STAMP"
rm -f "$OUT"
if command -v xorriso >/dev/null 2>&1; then
    xorriso -as mkisofs -quiet -r -J -joliet-long -V A3 -o "$OUT" "$STAGE/a3"
elif command -v genisoimage >/dev/null 2>&1; then
    genisoimage -quiet -r -J -joliet-long -V A3 -o "$OUT" "$STAGE/a3"
else
    echo "need xorriso for Rock Ridge names and modes: brew install xorriso (macOS) / apt install xorriso" >&2
    exit 1
fi
echo "built $OUT ($(du -h "$OUT" | cut -f1)), stamp $(cat "$STAGE/a3/TRANSFER_STAMP")"
echo "next: bash tools/vm/vbox-clone-topology.sh transfer"
