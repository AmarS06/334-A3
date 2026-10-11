# Phase 3 — launch environment (commands given when the phase starts)
- [ ] `server-httpserver.png` — `python3 -m http.server 8000` serving ~/www
- [ ] `client-curl-md5.png` — curl of 1M.bin + md5 vs the server's MD5SUMS
- [ ] `client-kernel-rst.png` — tcpdump showing the kernel RST before suppression (spike, optional)
- [ ] `client-iptables.png`, `server-iptables.png` — A3C / A3S chains after the launchers ran
- [ ] `client-handshake.png` — handshake completes, no RST
- [ ] `client-offloads.png` — `tools/vm/offloads.sh show` result (GRO decision for SPEC §16)
