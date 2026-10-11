# Phase 8 — driver on the VMs (M3)
- [ ] `client-handshake-close.png` — full connection: SYN, data, FIN both ways, exit 0
- [ ] `client-refused.png` — closed port → exit code 2, "Refused"
- [ ] `client-handshake-timeout.png` — unreachable/blackholed server → HandshakeTimeout, exit code
- [ ] `client-stall.png` — `netem.sh <IF_B> lossy 100` for 3 s mid-transfer, recovery
- [ ] `client-logcheck.png` — `check_log.py` on the client and server logs: 0 problems
