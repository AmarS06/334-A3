# Phase 2 — network configuration (also R1–R3 in report/screenshots/)

## Here (docs/evidence/phase2-netcfg/)
- [ ] `r1-netcfg.png` — `clear; sudo bash /mnt/a3/reference/netcfg/r1.sh enp0s8 enp0s9`
- [ ] `r2-netcfg.png` — `clear; sudo bash /mnt/a3/reference/netcfg/r2.sh enp0s8 enp0s9 enp0s10`
- [ ] `client-netcfg.png` — `clear; sudo bash /mnt/a3/reference/netcfg/client.sh enp0s8 enp0s9`
- [ ] `server-netcfg.png` — `clear; sudo bash /mnt/a3/reference/netcfg/server.sh enp0s8`
- [ ] `client-verify.png`, `r1-verify.png`, `r2-verify.png`, `server-verify.png` —
      `clear; bash /mnt/a3/tools/test/verify-routing.sh <vm> | grep -E 'PASS|FAIL|pings'`

## report/screenshots/R1/
- [x] 8 adapter-settings shots (done in S7)
- [ ] `client-addr-route.png`, `r1-addr-route.png`, `r2-addr-route.png`, `server-addr-route.png` —
      `clear; hostname; ip -br addr; ip route`

## report/screenshots/R2/
- [ ] `client-traceroute.png` — `clear; traceroute -n 10.10.3.10` (10.10.1.1 → 10.10.4.1 → 10.10.3.10)
- [ ] `server-traceroute.png` — `clear; traceroute -n 10.10.1.10` (10.10.3.1 → 10.10.1.10)
- [ ] `client-ttl.png` — `clear; ping -c2 10.10.3.10` (ttl=63)
- [ ] `server-ttl.png` — `clear; ping -c2 10.10.1.10` (ttl=62)

## report/screenshots/R3/
- [ ] `client-rpfilter.png`, `r1-rpfilter.png`, `r2-rpfilter.png`, `server-rpfilter.png` —
      `clear; hostname; sysctl -a 2>/dev/null | grep -E '\.rp_filter|ipv4.*\.forwarding'`

Then: power off all, `bash tools/vm/vbox-clone-topology.sh snapshot netcfg-ok`, commit.
