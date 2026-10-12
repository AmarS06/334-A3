# Phase 3 — launch environment (reference pass on the VMs)

All screenshots go in `docs/evidence/phase3-launch/`. Run `clear` before each screenshot command.
Type each command on one line; a `>` prompt means an unclosed quote (Ctrl+C, retype).

## 0. Start (Mac, then each VM)
```
cd ~/Desktop/"COL334 A3"
bash tools/vm/vbox-clone-topology.sh restore netcfg-ok
```
Start all four VMs, log in. In each: `cat /mnt/a3/TRANSFER_STAMP` → `2026-10-12 00:41:54`, then `sudo -v`.

## A. SERVER — test files, a standard web server, our server
```
bash /mnt/a3/tools/test/gen-www.sh ~/www > /dev/null
cd ~/www && (python3 -m http.server 8000 > /dev/null 2>&1 &) ; cd ~
sudo bash /mnt/a3/reference/server/run-server -p 8080 -d ~/www --log ~/srv.log &
```
Press Enter once if the prompt doesn't reappear.
- [ ] `server-md5sums.png` — `clear; cat ~/www/MD5SUMS`
- [ ] `server-iptables.png` — `clear; sudo iptables -S | grep A3`
      expect `-N A3S`, `-A OUTPUT -j A3S`, `-A A3S -p tcp -m tcp --sport 8080 --tcp-flags RST RST -j DROP`

## B. CLIENT — baseline with the kernel's own TCP
- [ ] `client-curl-md5.png` —
      `clear; curl -s -o /tmp/1M.curl http://10.10.3.10:8000/1M.bin; echo "curl exit=$?"; md5sum /tmp/1M.curl`
      expect exit 0; md5 equals the `./1M.bin` line in server-md5sums.png

## C. CLIENT — without the launcher: the kernel resets our connection
```
clear
sudo timeout 20 tcpdump -nn -i any 'tcp port 8080' &
sudo timeout 15 python3 -B /mnt/a3/reference/src/http_client.py http://10.10.3.10:8080/index.html -o /tmp/x; echo "exit=$?"
```
Wait ~20 s until tcpdump prints its "packets captured" summary.
- [ ] `client-kernel-rst.png` — expect: `enp0s8 Out … Flags [S]` (our SYN), `enp0s9 In … Flags [S.]`
      (SYN-ACK, arriving over Link D), `enp0s8 Out … Flags [R]` (kernel RST), then a failed or timed-out
      download (exit ≠ 0). If the window is too small, take two screenshots (-a, -b).

## D. CLIENT — with the launcher: rules installed, handshake and transfer complete
```
clear
sudo timeout 10 tcpdump -nn -i any 'tcp port 8080' &
sudo bash /mnt/a3/reference/client/run-client http://10.10.3.10:8080/index.html -o /tmp/index.html --log /tmp/c.log; echo "exit=$?"
```
Wait for the tcpdump summary.
- [ ] `client-handshake.png` — expect no `[R]` lines, `exit=0`
- [ ] `client-handshake-check.png` —
      `clear; md5sum /tmp/index.html; sudo iptables -S | grep A3; python3 /mnt/a3/tools/test/check_log.py /tmp/c.log`
      expect md5 = `./index.html` line; `-A A3C -p tcp -m tcp --sport 61000:65535 --tcp-flags RST RST -j DROP`
      and `-A OUTPUT -j A3C`; `0 problem(s)`

## E. CLIENT — offload probe (decides SPEC ENV-3)
```
clear
sudo bash /mnt/a3/tools/vm/offloads.sh show enp0s8 enp0s9
sudo A3_TRACE=/tmp/t.jsonl bash /mnt/a3/reference/client/run-client http://10.10.3.10:8080/10M.bin -o /tmp/10M --log /tmp/c10.log; echo "exit=$?"
md5sum /tmp/10M
awk '/^RECV/ {split($11,a,"="); if (a[2]>1460) n++} END {print n+0, "RECV segments longer than 1460"}' /tmp/c10.log
grep -c bad-tcp-csum /tmp/t.jsonl
```
- [ ] `client-offloads.png` — GRO state per interface, exit 0, md5 = `./10M.bin`, both counts
      (both 0 → launchers leave offloads alone; either > 0 → tell Claude)

## F. Finish
- `sudo poweroff` in all four VMs (no new snapshot needed).
- Mac: `conda activate a3 && git add -A && git commit -m "Phase 3: launchers, RST suppression, offload probe" && git push`
- Tell Claude.
