#!/usr/bin/env bash
# usage: tools/check_compliance.sh   (exit 1 on hard violations)
. "$(dirname "$0")/host/gnu-path.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
rc=0
hard(){ echo "VIOLATION: $*"; rc=1; }
warn(){ echo "REVIEW:    $*"; }
SRC=$(find "${A3_SRC:-src}" -type f \( -name '*.py' -o -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \) | sort)
scan(){
  local hits; hits=$(grep -nE "$1" $SRC 2>/dev/null | grep -vE '^\S+:[0-9]+:\s*(#|//)')
  [ -n "$hits" ] && { [ "$3" = hard ] && hard "$2" || warn "$2"; echo "$hits" | sed 's/^/    /'; }
}
if [ -n "$SRC" ]; then
  scan 'SOCK_STREAM' 'kernel TCP socket (SOCK_STREAM)' hard
  scan '\blisten\s*\(|\.listen\s*\(' 'listen()' hard
  scan '\baccept\s*\(|\.accept\s*\(' 'accept(): OK only if it is your own function' warn
  scan '\bconnect\s*\(|\.connect\s*\(' 'connect(): allowed only on UDP or your own API' warn
  scan 'AF_PACKET|PF_PACKET' 'AF_PACKET socket' hard
  scan '\b(scapy|dpkt|pcap|libnet|requests|socketserver|asyncio|curl)\b' 'packet/HTTP library' hard
  scan 'http\.client|http\.server|\burllib\b|import http\b|from http\b' 'http.* / urllib' hard
  scan '\bsubprocess\b|os\.system|os\.popen|os\.exec|os\.spawn|\bpopen\s*\(|\bsystem\s*\(|\bexec[lv]p?e?\s*\(' 'running other programs' hard
  scan '\b(tomllib|ExceptionGroup|datetime\.UTC|typing\.Self)\b|except\*' 'Python >3.10 feature' hard
  scan '^\s*def\s+(connect|listen|accept|send|recv)\s*\(' 'SPEC I4: API names that trip forbidden-API greps' hard
  io=$(grep -lE '^\s*(import|from)\s+(socket|select|time)\b' $SRC 2>/dev/null | grep -v "^${A3_SRC:-src}/driver/" | grep -vE "^${A3_SRC:-src}/http_(client|server)\.py$")
  [ -n "$io" ] && { warn "SPEC I1: socket/select/time imported outside driver/: $(echo $io)"; }
  pr=$(grep -nE '\bprint\s*\(' $SRC 2>/dev/null | grep -v 'file=sys.stderr')
  [ -n "$pr" ] && { warn "SPEC I7: print() without file=sys.stderr (stdout is the body)"; echo "$pr" | sed 's/^/    /'; }
  grep -qE 'IP_HDRINCL|IPPROTO_RAW' $SRC || warn "IP_HDRINCL not found in src/ (mandatory for Part B)"
  cl=$(grep -nE '^\s*(#|//)|"""|/\*' $SRC)
  [ -n "$cl" ] && { warn "comments/docstrings in src: $(echo "$cl" | wc -l) line(s); keep only essential definitions (instructions.md I.3)"; echo "$cl" | sed 's/^/    /'; }
fi
if [ -d reference ]; then
  sim=$(python3 - <<'PY'
import difflib, os
pairs=[]
for root in ("src","netcfg","client","server"):
    for d,_,fs in os.walk(root):
        for f in fs:
            p=os.path.join(d,f); r=os.path.join("reference",p)
            if os.path.isfile(r) and os.path.getsize(p)>0:
                a=open(p,errors="ignore").read().split(); b=open(r,errors="ignore").read().split()
                q=difflib.SequenceMatcher(None,a,b,autojunk=False).ratio()
                if q>=0.60: pairs.append(f"{p} {q:.2f}")
print("\n".join(pairs))
PY
)
  [ -n "$sim" ] && { warn "two-pass guard: submitted files >=60% token-similar to reference/ (rewrite from SPEC)"; echo "$sim" | sed 's/^/    /'; }
fi
for f in netcfg/*.sh; do
  bad=$(grep -vE '^\s*(#|$)' "$f" | grep -oE '(^|[;&|]|then|do|else)\s*[a-zA-Z_./-]+' | sed -E 's/^([;&|]|then|do|else)?\s*//' \
        | grep -vxE 'ip|sysctl|set|if|then|fi|for|do|done|else|elif|echo|exit|return|local|shift|true|false|test|\[|\[\[|case|esac|in|while|printf|[A-Za-z_][A-Za-z0-9_]*=.*' | sort -u)
  [ -n "$bad" ] && warn "$f uses commands other than ip/sysctl: $(echo $bad)"
  grep -vE '^\s*#' "$f" | grep -qE '>\s*/(proc|sys)' && hard "$f writes /proc or /sys directly (use sysctl)"
done
for f in netcfg/*.sh client/run-client server/run-server; do grep -q $'\r' "$f" && hard "$f has CRLF"; done
[ -f Makefile ] && warn "top-level Makefile exists: grader runs it as root, offline"
if command -v python3.10 >/dev/null && [ -n "$(find src -name '*.py' -size +0)" ]; then
  python3.10 -m py_compile $(find src -name '*.py') && echo "OK:        python3.10 compiles src/" || hard "python3.10 compile failed"
  find src -name __pycache__ -prune -exec rm -rf {} +
else echo "NOTE:      python3.10 unavailable or src empty; version check skipped (run inside a VM)"; fi
[ $rc -eq 0 ] && echo "No hard violations (heuristic; review REVIEW lines)."
exit $rc
