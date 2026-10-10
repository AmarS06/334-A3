#!/usr/bin/env bash
# usage: [WRAP=1] tools/package.sh ENTRY1 [ENTRY2]
. "$(dirname "$0")/host/gnu-path.sh"
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then exec bash "$0" "$@"; fi
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
[ $# -eq 1 ] || [ $# -eq 2 ] || { echo "usage: $0 ENTRY1 [ENTRY2]" >&2; exit 1; }
mapfile -t E < <(for e in "$@"; do printf '%s\n' "${e^^}"; done | LC_ALL=C sort)
for e in "${E[@]}"; do [[ "$e" =~ ^[A-Z0-9]+$ ]] || { echo "bad entry number '$e' (no spaces/hyphens)" >&2; exit 1; }; done
NAME="A3_$(IFS=_; echo "${E[*]}")"
[ ${#E[@]} -eq 1 ] && echo "NOTE: solo package $NAME.zip; confirm solo submissions are allowed (TA Q10)" >&2
fail=0; err(){ echo "ERROR: $*" >&2; fail=1; }

for f in netcfg/client.sh netcfg/r1.sh netcfg/r2.sh netcfg/server.sh client/run-client server/run-server README.md report.pdf; do
  [ -f "$f" ] || err "missing $f"
done
for f in netcfg/*.sh client/run-client server/run-server; do
  [ -f "$f" ] || continue
  [ -x "$f" ] || err "$f not executable"
  grep -q $'\r' "$f" && err "$f has CRLF line endings"
  head -1 "$f" | grep -q '^#!' || err "$f missing shebang"
done
for f in client/run-client server/run-server; do
  grep -q '^[[:space:]]*exec ' "$f" || err "$f does not use exec"
  grep -q '"\$@"' "$f" || err "$f does not pass \"\$@\""
done
[ -n "$(find src -type f ! -name '*.pyc' 2>/dev/null)" ] || err "src/ is empty"
grep -q 'TODO' README.md && err "README.md still contains TODO"
bash tools/check_compliance.sh || err "compliance check failed"
[ $fail -eq 0 ] || { echo "Not packaging." >&2; exit 1; }

STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
DEST="$STAGE"; [ "${WRAP:-0}" = 1 ] && DEST="$STAGE/$NAME" && mkdir -p "$DEST"
cp -a netcfg client server src README.md report.pdf "$DEST/"
[ -f Makefile ] && cp -a Makefile "$DEST/"
find "$DEST" \( -name '__pycache__' -o -name '*.pyc' -o -name '*.o' -o -name '*.pcap' -o -name '*.pcapng' \
  -o -name '.gitkeep' -o -name '.DS_Store' \) -prune -exec rm -rf {} +
while IFS= read -r -d '' f; do
  if head -c4 "$f" | grep -q $'\x7fELF'; then echo "ERROR: binary in submission: $f" >&2; exit 1; fi
done < <(find "$DEST" -type f -print0)
mkdir -p dist; rm -f "dist/$NAME.zip"
(cd "$STAGE" && zip -qrX "$ROOT/dist/$NAME.zip" .)
echo "Built dist/$NAME.zip"; unzip -Z1 "dist/$NAME.zip" | sort
