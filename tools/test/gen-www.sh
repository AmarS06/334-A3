#!/usr/bin/env bash
# usage: bash gen-www.sh [DIR=tests/www]
set -euo pipefail
D=${1:-"$(cd "$(dirname "$0")/../.." && pwd)/tests/www"}; mkdir -p "$D/sub" "$D/emptydir"
echo '<html><body><h1>A3 index</h1></body></html>' > "$D/index.html"
echo '<html><body>sub index</body></html>' > "$D/sub/index.html"
echo 'plain text' > "$D/a.txt"; echo 'body{}' > "$D/s.css"; echo 'var x=1;' > "$D/a.js"; echo '{"a":1}' > "$D/d.json"
for f in i.png p.JPG g.gif doc.pdf noext; do head -c 2048 /dev/urandom > "$D/$f"; done
head -c 150000  /dev/urandom > "$D/blob.bin"
head -c 1048576 /dev/urandom > "$D/1M.bin"
head -c 10485760 /dev/urandom > "$D/10M.bin"
python3 -c "print('<html><body>' + 'x'*200000 + '</body></html>')" > "$D/big.html"
(cd "$D" && find . -type f ! -name MD5SUMS | sort | xargs md5sum > MD5SUMS)
echo "generated $D"; ls -la "$D"
