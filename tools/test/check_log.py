#!/usr/bin/env python3
"""usage: check_log.py LOGFILE"""

import re
import sys
import collections

LINE = re.compile(
    r"^(SEND|RECV) (\d{1,3}(?:\.\d{1,3}){3}):(\d+) > (\d{1,3}(?:\.\d{1,3}){3}):(\d+) "
    r"ttl=(\d+) id=(\d+) seq=(\d+) ack=(\d+) flags=0x([0-9a-f]{2}) win=(\d+) len=(\d+) mss=(\d+|-)$"
)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    errs, stats = [], collections.Counter()
    ttls = collections.Counter()
    with open(sys.argv[1], newline="") as f:
        for n, raw in enumerate(f, 1):
            line = raw.rstrip("\n")
            if raw.endswith("\r\n"):
                errs.append(f"{n}: CRLF line ending")
            m = LINE.match(line)
            if not m:
                errs.append(f"{n}: bad format: {line!r}")
                continue
            d, sip, sp, dip, dp, ttl, ipid, seq, ack, fl, win, ln, mss = m.groups()
            fl = int(fl, 16)
            syn = fl & 0x02
            for name, v, hi in (
                ("sport", sp, 65535),
                ("dport", dp, 65535),
                ("ttl", ttl, 255),
                ("id", ipid, 65535),
                ("seq", seq, 2**32 - 1),
                ("ack", ack, 2**32 - 1),
                ("win", win, 65535),
            ):
                if int(v) > hi:
                    errs.append(f"{n}: {name}={v} out of range")
            if d == "SEND":
                if int(ipid) == 0:
                    errs.append(f"{n}: SEND with id=0 (T1)")
                if syn and mss != "1460":
                    errs.append(f"{n}: SEND SYN without mss=1460 (T3)")
                if not syn and mss != "-":
                    errs.append(f"{n}: SEND non-SYN carries MSS option (T3)")
                if int(win) != 65535:
                    errs.append(f"{n}: SEND win={win}, expected fixed 65535 (T11)")
                if int(ln) > 1460:
                    errs.append(f"{n}: SEND len={ln} > 1460 (T3)")
                if int(ttl) == 0:
                    errs.append(f"{n}: SEND ttl=0")
            else:
                ttls[int(ttl)] += 1
                if int(ln) > 1460:
                    errs.append(f"{n}: RECV len={ln} > 1460 — GRO coalescing? (instructions.md G3)")
            stats[(d, fl)] += 1
    names = {
        0x02: "SYN",
        0x12: "SYN-ACK",
        0x10: "ACK",
        0x18: "PSH-ACK",
        0x11: "FIN-ACK",
        0x19: "FIN-PSH-ACK",
        0x04: "RST",
        0x14: "RST-ACK",
    }
    print("segments by direction/flags:")
    for (d, fl), c in sorted(stats.items()):
        print(f"  {d} 0x{fl:02x} {names.get(fl, ''):12s} {c}")
    if ttls:
        print("RECV ttl values:", dict(ttls), "(client expects 63 via r2; server expects 62)")
    print(f"{len(errs)} problem(s)")
    [print("  " + e) for e in errs[:50]]
    sys.exit(1 if errs else 0)


if __name__ == "__main__":
    main()
