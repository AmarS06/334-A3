#!/usr/bin/env bash
# usage: sudo [A3_CLIENT=/mnt/a3/reference/client/run-client] bash md5check.sh URL [ORIGINAL_MD5]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; URL=${1:?URL}; T=$(mktemp -d)
curl -s -o "$T/curl" "$URL"; echo "curl exit=$?"
wget -q -O "$T/wget" "$URL"; echo "wget exit=$?"
"${A3_CLIENT:-$ROOT/client/run-client}" "$URL" -o "$T/ours"; echo "ours exit=$?"
md5sum "$T"/curl "$T"/wget "$T"/ours
[ -n "${2:-}" ] && echo "original: $2"
n=$(md5sum "$T"/* | awk '{print $1}' | sort -u | wc -l); [ "$n" = 1 ] && echo "MATCH" || echo "MISMATCH"
rm -rf "$T"
