# VM runbook: every remaining phase, in order (reference pass)

Supersedes the per-phase CHECKLIST.md files. Screenshots go in `docs/evidence/<phase>/` unless a
`report/screenshots/R#/` folder is named. Rules for every step:
- `clear` before a screenshot command; ⌘⇧4 → Space → click the VM window; rename; move into the folder.
- Type each command on one line. `>` prompt = unclosed quote → Ctrl+C (the **Control** key), retype.
- Run `sudo -v` right before any command that ends in `&`; never type your password at a `$` prompt.
- If a result differs from "expect", stop and send Claude that screenshot.
- Interfaces: client enp0s8=LAN_A enp0s9=LINK_D · r1 enp0s8=LAN_A enp0s9=LAN_B ·
  r2 enp0s8=LAN_B enp0s9=LAN_C enp0s10=LINK_D · server enp0s8=LAN_C.
- Impairment points: requests/ACKs → r1 `enp0s9`; data to the client → r2 `enp0s10`.

---

## 0. Once, before resuming (Mac; all VMs powered off)
```
cd ~/Desktop/"COL334 A3"
bash tools/vm/vbox-clone-topology.sh restore netcfg-ok
bash tools/host/make-transfer-iso.sh
bash tools/vm/vbox-clone-topology.sh transfer
```
Start all four VMs. In each: `cat /mnt/a3/TRANSFER_STAMP` shows today's build time.
**netem check (r1 and r2):** `sudo tc qdisc add dev lo root netem delay 1ms && sudo tc qdisc del dev lo root && echo NETEM-OK`
- `NETEM-OK` → fine. `Specified qdisc kind is unknown` → tell Claude before Phase 8 (needs a module package).

---

## Phase 3 — launch environment (resume) → `docs/evidence/phase3-launch/`

### 3A SERVER
```
sudo -v
bash /mnt/a3/tools/test/gen-www.sh ~/www > /dev/null
cd ~/www
python3 -m http.server 8000 > /dev/null 2>&1 &
cd ~
sudo -v
sudo bash /mnt/a3/reference/server/run-server -p 8080 -d ~/www --log ~/srv.log &
```
| Shot | Command | Expect |
|---|---|---|
| `server-md5sums.png` | `clear; cat ~/www/MD5SUMS` | md5 list |
| `server-iptables.png` | `clear; sudo iptables -S \| grep A3` | `-N A3S`, `-A OUTPUT -j A3S`, `-A A3S … --sport 8080 … RST RST -j DROP` |
| `server-listen.png` | `clear; ss -ltn` | `0.0.0.0:8000` LISTEN |

### 3B CLIENT — the curl refusal, diagnosed in one command
| Shot | Command | Expect |
|---|---|---|
| `client-diag.png` | `clear; sudo bash /mnt/a3/tools/test/diag-connect.sh 10.10.3.10 8000` | `http=200`, `curl exit=0`, packets `enp0s8 Out [S]` → `enp0s9 In [S.]` → … |

If it fails, send `client-diag.png`: the packet lines show who refuses (`[R.]` from 10.10.3.10 = nothing
listening at that moment; no packets at all = blocked locally).
| `client-curl-md5.png` | `clear; curl -sS -o /tmp/1M.curl http://10.10.3.10:8000/1M.bin; echo "curl exit=$?"; md5sum /tmp/1M.curl` | exit 0; md5 = `./1M.bin` |

### 3C CLIENT — without the launcher (expected to fail)
```
clear
sudo -v
sudo timeout 20 tcpdump -nn -i any 'tcp port 8080' &
sudo timeout 15 python3 -B /mnt/a3/reference/src/http_client.py http://10.10.3.10:8080/index.html -o /tmp/x; echo "exit=$?"
```
Wait for `packets captured`. **`client-kernel-rst.png`**: `enp0s8 Out [S]`, `enp0s9 In [S.]`, `enp0s8 Out [R]`; exit ≠ 0.

### 3D CLIENT — with the launcher
```
clear
sudo -v
sudo timeout 10 tcpdump -nn -i any 'tcp port 8080' &
sudo bash /mnt/a3/reference/client/run-client http://10.10.3.10:8080/index.html -o /tmp/index.html --log /tmp/c.log; echo "exit=$?"
```
| Shot | Command | Expect |
|---|---|---|
| `client-handshake.png` | (above, after `packets captured`) | no `[R]`; `exit=0` |
| `client-handshake-check.png` | `clear; md5sum /tmp/index.html; sudo iptables -S \| grep A3; python3 /mnt/a3/tools/test/check_log.py /tmp/c.log` | md5 = `./index.html`; A3C rule + OUTPUT jump; `0 problem(s)` |

### 3E CLIENT — offload probe (decides ENV-3)
```
clear
sudo bash /mnt/a3/tools/vm/offloads.sh show enp0s8 enp0s9
sudo A3_TRACE=/tmp/t.jsonl bash /mnt/a3/reference/client/run-client http://10.10.3.10:8080/10M.bin -o /tmp/10M --log /tmp/c10.log; echo "exit=$?"
md5sum /tmp/10M
awk '/^RECV/ {split($11,a,"="); if (a[2]>1460) n++} END {print n+0, "RECV segments longer than 1460"}' /tmp/c10.log
grep -c bad-tcp-csum /tmp/t.jsonl
```
**`client-offloads.png`**: GRO state, exit 0, md5 = `./10M.bin`, two counts (both 0 → no change).

Leave all VMs running and go straight on to Phase 8.

---

## Phase 8 — driver: connection life cycle and failure paths → `docs/evidence/phase8-driver/`
Servers from 3A keep running.
| Shot | VM | Command | Expect |
|---|---|---|---|
| `client-full-connection.png` | client | `clear; sudo -v; sudo timeout 10 tcpdump -nn -i any 'tcp port 8080' &` then `sudo bash /mnt/a3/reference/client/run-client http://10.10.3.10:8080/a.txt -o /tmp/a.txt; echo "exit=$?"; cat /tmp/a.txt` | SYN, SYN-ACK, ACK, GET, data, FIN both ways, `exit=0`, `plain text` |
| `client-refused.png` | client | `clear; sudo bash /mnt/a3/reference/client/run-client http://10.10.3.10:9999/ -o /tmp/x; echo "exit=$?"` | `error: Refused …`, `exit=2` |
| `client-handshake-timeout.png` | client | `clear; time sudo bash /mnt/a3/reference/client/run-client http://10.10.3.99:8080/ -o /tmp/x; echo "exit=$?"` | `error: HandshakeTimeout …` after ~7 s, `exit=2` |
| `client-stall-recovery.png` | client + r1 | client: `clear; sudo bash /mnt/a3/reference/client/run-client http://10.10.3.10:8080/10M.bin -o /tmp/s10 --log /tmp/s.log; echo "exit=$?"; md5sum /tmp/s10` — **while it runs**, r1: `sudo bash /mnt/a3/tools/test/netem.sh enp0s9 lossy 100; sleep 3; sudo bash /mnt/a3/tools/test/netem.sh enp0s9 clear` | download pauses then completes; `exit=0`; md5 = `./10M.bin` |
| `logs-valid.png` | client | `clear; for f in /tmp/c.log /tmp/c10.log /tmp/s.log; do python3 /mnt/a3/tools/test/check_log.py $f; done` | `0 problem(s)` ×3 |
| `server-log-valid.png` | server | `clear; sudo python3 /mnt/a3/tools/test/check_log.py ~/srv.log` | `0 problem(s)` |

---

## Phase 10 — integration → R4, R5, `docs/evidence/phase10-integration/`
SERVER, start the extra test server:
```
python3 /mnt/a3/tools/test/chunked-server.py 8001 > /dev/null 2>&1 &
```
CLIENT, set the client once: `export C=/mnt/a3/reference/client/run-client`
| Shot | Folder | Command (client) | Expect |
|---|---|---|---|
| `client-vs-pyserver-html.png` | R4 | `clear; sudo A3_CLIENT=$C bash /mnt/a3/tools/test/md5check.sh http://10.10.3.10:8000/big.html` | curl/wget/ours exit 0, three equal md5, `MATCH` |
| `client-vs-pyserver-bin.png` | R4 | same with `/blob.bin` (150 KB) | `MATCH` |
| `client-vs-pyserver-404.png` | R4 | `clear; sudo bash $C http://10.10.3.10:8000/nope -o /tmp/x; echo "exit=$?"` | `404`, `exit=1` |
| `ourserver-curl-wget-ours.png` | R5 | `clear; sudo A3_CLIENT=$C bash /mnt/a3/tools/test/md5check.sh http://10.10.3.10:8080/1M.bin` | `MATCH`; md5 = `./1M.bin` in server-md5sums.png |
| `ourserver-html.png` | R5 | same with `/index.html` | `MATCH` |
| `client-chunked.png` | phase10 | `clear; for p in chunked trailers close length; do sudo bash $C http://10.10.3.10:8001/$p -o /tmp/$p; echo "$p exit=$?"; done; md5sum /tmp/chunked /tmp/trailers /tmp/close /tmp/length` | four exit 0, four equal md5 |
| `client-chunked-bad.png` | phase10 | `clear; for p in bad truncated 204; do sudo bash $C http://10.10.3.10:8001/$p -o /tmp/$p; echo "$p exit=$?"; done` | bad/truncated exit ≠ 0, 204 exit 0 |
| `client-server-edge.png` | phase10 | `clear; bash /mnt/a3/tools/test/server-edge.sh 10.10.3.10 8080 2>&1 \| tail -25` | every line `PASS` (17) |

---

## Phase 11 — congestion control → `docs/evidence/phase11-congestion/`, R6
SERVER, a traced server on 8081: `sudo -v` then
`sudo A3_TRACE=/tmp/st.jsonl bash /mnt/a3/reference/server/run-server -p 8081 -d ~/www &`
| Shot | VM | Command | Expect |
|---|---|---|---|
| `r2-bottleneck.png` | r2 | `clear; sudo bash /mnt/a3/tools/test/netem.sh enp0s10 bottleneck 20mbit 10ms 1; sudo bash /mnt/a3/tools/test/netem.sh enp0s10 show` | netem + tbf qdiscs |
| `client-10M-bottleneck.png` | client | `clear; time sudo bash $C http://10.10.3.10:8081/10M.bin -o /tmp/b10; echo "exit=$?"; md5sum /tmp/b10` | exit 0, md5 = `./10M.bin`, a few seconds |
| `server-cwnd-trace.png` (also copy to R6) | server | `clear; sudo python3 /mnt/a3/tools/test/trace-summary.py /tmp/st.jsonl 25` | slow start, then drops at loss (fast retransmissions), congestion avoidance: a sawtooth |
r2 afterwards: `sudo bash /mnt/a3/tools/test/netem.sh enp0s10 clear`.
(The trace is on the server because the server is the sender of a download.)

---

## Phase 12 — robustness → `docs/evidence/phase12-robustness/`, R6
| Shot | VM | Command | Expect |
|---|---|---|---|
| (setup) | r2 | `sudo bash /mnt/a3/tools/test/netem.sh enp0s10 lossy 5 10ms 25` | — |
| `client-loss5-reorder.png` | client | `clear; time sudo bash $C http://10.10.3.10:8080/1M.bin -o /tmp/l5 --log /tmp/l5.log; echo "exit=$?"; md5sum /tmp/l5; awk '/^RECV/ {split($7,a,"="); s=a[2]+0; if (s<m) o++; if (s>m) m=s} END {print o+0, "out-of-order arrivals"}' /tmp/l5.log` | exit 0, md5 = `./1M.bin`, out-of-order count > 0 |
| (setup) | r2 | `sudo bash /mnt/a3/tools/test/netem.sh enp0s10 lossy 10 10ms 25` | — |
| `client-loss10.png` | client | same command, files `/tmp/l10` | exit 0, md5 matches |
| (setup) | r1 | `sudo bash /mnt/a3/tools/test/netem.sh enp0s9 lossy 5` | loss on the request/ACK path too |
| `client-loss-both.png` | client | same command, files `/tmp/lb` | exit 0, md5 matches |
| `capture-retransmission.png` (R6) | client | `clear; sudo -v; sudo timeout 15 tcpdump -l -nn -i enp0s9 'tcp src port 8080' 2>/dev/null \| awk '{print $1, $7, $9}' \| head -40 &` then `sudo bash $C http://10.10.3.10:8080/blob.bin -o /tmp/r` | repeated or out-of-order `seq` ranges (retransmissions and reordering) |
| `server-loss-trace.png` (R6) | server | traced server: `sudo -v; sudo A3_TRACE=/tmp/lt.jsonl bash /mnt/a3/reference/server/run-server -p 8082 -d ~/www &`; client: `sudo bash $C http://10.10.3.10:8082/1M.bin -o /tmp/lt`; server: `clear; sudo python3 /mnt/a3/tools/test/trace-summary.py /tmp/lt.jsonl 20` | `retransmissions fast=… timeout=…` > 0 |
| (clear) | r1, r2 | r1: `sudo bash /mnt/a3/tools/test/netem.sh enp0s9 clear` · r2: `… enp0s10 clear` | `cleared` |
| `client-isn-wrap.png` | client | `clear; sudo A3_FORCE_ISN=4294967000 bash $C http://10.10.3.10:8080/1M.bin -o /tmp/w; echo "exit=$?"; md5sum /tmp/w` | exit 0, md5 matches (sequence numbers wrap past 2³²) |
| `client-gro-off-on.png` | client | `clear; sudo bash /mnt/a3/tools/vm/offloads.sh off enp0s8 enp0s9; time sudo bash $C http://10.10.3.10:8080/10M.bin -o /tmp/g0; sudo bash /mnt/a3/tools/vm/offloads.sh on enp0s8 enp0s9; time sudo bash $C http://10.10.3.10:8080/10M.bin -o /tmp/g1; md5sum /tmp/g0 /tmp/g1` | both md5 = `./10M.bin`; similar times |
| `capture-full-connection.png` (R6) | client | `clear; sudo -v; sudo timeout 8 tcpdump -nn -i any 'tcp port 8080' &` then `sudo bash $C http://10.10.3.10:8080/a.txt -o /tmp/a` | one complete connection, handshake to FIN (can reuse Phase 8's shot) |
| `qdiscs-cleared.png` | r1, r2 | `clear; tc qdisc show` | only default qdiscs (no netem/tbf) |

---

## Phase 13 — Part E: interop and fairness → `docs/evidence/phase13-fairness/`
SERVER (8080 and 8081 already run; add 8082 if not running):
`sudo -v; sudo bash /mnt/a3/reference/server/run-server -p 8082 -d ~/www &`
r2: `sudo bash /mnt/a3/tools/test/netem.sh enp0s10 bottleneck 20mbit 10ms`
| Shot | Command (client) | Expect |
|---|---|---|
| `client-fairness-1v1.png` | `clear; sudo A3_CLIENT=$C bash /mnt/a3/tools/test/fairness.sh http://10.10.3.10:8080/10M.bin http://10.10.3.10:8000/10M.bin 1 1` | both rc=0; Mbit/s ratio ours/curl between 0.6 and 1.6 |
| `client-fairness-3v3.png` | `clear; sudo A3_CLIENT=$C bash /mnt/a3/tools/test/fairness.sh http://10.10.3.10:8080/10M.bin,http://10.10.3.10:8081/10M.bin,http://10.10.3.10:8082/10M.bin http://10.10.3.10:8000/10M.bin 3 3` | six rc=0; similar per-flow Mbit/s |
| `interop-summary.png` | (no command) — the matrix is R4 + R5 + chunked: our client ↔ python server, our server ↔ curl/wget/our client | — |
r2 afterwards: `sudo bash /mnt/a3/tools/test/netem.sh enp0s10 clear`. Power off all VMs. Mac: commit.
**End of Track A.** Tell Claude after each phase; Claude checks the shots and fills `test-results.md`, `log.txt`, SPEC §16.

---

## Track B — your own `src/` (Mac + VMs)
Per phase: read the SPEC section → write the code → `bash tools/test/run-unit.sh` (with `src/`) →
`bash tools/check_compliance.sh` → commit. VM checks reuse the commands above with
`/mnt/a3/client/run-client` and `/mnt/a3/server/run-server` instead of the reference paths.
| Phase | Write | Check |
|---|---|---|
| 0.5–0.6 | contract freeze (SPEC §2, names in §16); README team/language/build | — |
| 2 | `netcfg/*.sh` | Phase 2 commands from `restore fresh`; `snapshot netcfg-ok` |
| 3 | `client/run-client`, `server/run-server` | Phase 3 |
| 4 | `src/settings.py`, `src/packets/*` | `test_packets.py` |
| 5 | `src/web/parsing.py`, `urlparts.py` | `test_web.py` (parsers) |
| 6 | `src/core/*` | `test_core_sim.py` (harness campaign) |
| 7 | `src/web/fetch.py` | `test_web.py` (client) |
| 8 | `src/driver/*`, entry points | Phase 8 |
| 9 | `src/web/serve.py`, `content.py` | `test_web.py` (server) |
| 10–13 | — | Phases 10–13 with your launchers |

## Track C — finish
| Phase | Tasks |
|---|---|
| 14 | `tools/test/run-all.sh`; unit gaps; regression from `netcfg-ok` (Phases 8, 10, reduced 12, 13) |
| 15 | `refcorpus/` (sources in `docs/clean-room/avoid.md`); Dolos + JPlag on `src/` (setup.md S8); triage in `audit-log.md`; rewrite avoidable matches; rerun 14 |
| 16 | report text R1–R6 in your words → `report.pdf`; README without TODOs; `bash tools/package.sh <ENTRY>`; dry run: zip-only ISO (`mkdir -p /tmp/z && cp dist/*.zip /tmp/z && xorriso -as mkisofs -r -J -o ~/A3-VMs/a3-zip.iso /tmp/z && bash tools/vm/vbox-clone-topology.sh restore fresh && bash tools/vm/vbox-clone-topology.sh transfer ~/A3-VMs/a3-zip.iso`; in VMs `python3 -m zipfile -e /mnt/a3/A3_*.zip /tmp/sub` then netcfg, verify-routing, md5check, server-edge from another directory); upload; re-download; compare checksums |
| 17 | viva: explain every SPEC item from your code; checksum and r2 routing on paper; demo rehearsal |
