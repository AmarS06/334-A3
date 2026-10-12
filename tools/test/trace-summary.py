#!/usr/bin/env python3
# usage: python3 trace-summary.py TRACE.jsonl [ROWS=25]   (prints a readable cwnd/RTO/retransmission summary)
import json
import sys

path = sys.argv[1]
rows = int(sys.argv[2]) if len(sys.argv) > 2 else 25
events = [json.loads(line) for line in open(path, encoding="utf-8") if line.strip()]
cwnd = [e for e in events if e.get("k") == "cwnd"]
rtx = [e for e in events if e.get("k") == "rtx"]
rto = [e for e in events if e.get("k") == "rto"]
drops = {}
for e in events:
    if e.get("k") == "drop":
        drops[e["reason"]] = drops.get(e["reason"], 0) + 1
fast = sum(1 for e in rtx if e.get("cause") == "fast")
timeout = sum(1 for e in rtx if e.get("cause") == "timeout")
print(f"events {len(events)}  cwnd updates {len(cwnd)}  retransmissions fast={fast} timeout={timeout}")
if rto:
    print(f"last srtt {rto[-1]['srtt']} s  last rto {rto[-1]['rto']} s")
print("drops", drops if drops else "none")
if cwnd:
    peak = max(e["cwnd"] for e in cwnd)
    step = max(1, len(cwnd) // rows)
    print(f"{'t (s)':>8}  {'cwnd':>8}  {'ssthresh':>9}  state")
    for e in cwnd[::step]:
        bar = "#" * max(1, round(40 * e["cwnd"] / peak))
        ss = e["ssthresh"] if e["ssthresh"] < 10**9 else "inf"
        print(f"{e['t']:8.3f}  {e['cwnd']:8d}  {ss!s:>9}  {e['state']:<9} {bar}")
