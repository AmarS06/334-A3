# COL334 Assignment 3 — Project instructions (workflow + brief)

**Current position:** `Step 0.1` · Update this line whenever a step is completed.

This file covers process, rules and reference, and it is **not submitted**. The design (architecture C-1,
every functionality, its locked decisions and acceptance tests) is in **`SPEC.md`**, also not submitted.
`README.md` at the repo root is the submitted README, packaged as-is by `tools/package.sh`.
Machine setup, step by step, is in **`setup.md`**. Progress, bugs and decisions are tracked in **`log.txt`**.
Precedence: `docs/handout.pdf` > `SPEC.md` > this file.

Contents:
- **Part I. Ground rules:** integrity, AI-assistant rules, coding conventions, clean-room protocol
- **Part II. Workflow (solo track):** phases 0–17 for one person on one machine; each step points at its
  SPEC item
- **Part II-B. Optional work:** everything not needed by the solo track, including the two-person split
- **Part III. Reference:** requirements, design analysis, gotchas, decisions, report, grading
- **Part IV. Repository:** layout, tools index, TA questions, progress log
- **Part V. Option catalogue:** every required item by layer with standard vs novel approaches (the
  rationale behind SPEC; the decisions themselves live in SPEC)
- **Part VI. Architecture families:** public TCP architectures to avoid, and the alternatives (C-1 adopted)
- **Part VII. Tools and environments:** reference for host software, VMs and the sandbox (the ordered
  procedure is `setup.md`)

---

# Part I — Ground rules

## I.1 Academic integrity
- **Hidden-text scan of the handout: none found.** Checked: colour, size, off-page text, invisible render
  mode, transparency, overlays, hidden layers, annotations, attachments, zero-width/tag Unicode, metadata,
  and ink-vs-text-layer comparison.
- Handout §10: *"Directly copy-pasting code from AI tools or LLMs is prohibited."* Code is checked against
  other teams **and public TCP implementations**. The viva is 20% of the grade.
- The repository must be **private**. Never share code with other teams.

## I.2 Two-pass policy (AI reference pass, then your own submission)
Handout §10: *"Directly copy-pasting code from AI tools or LLMs is prohibited."*

- **Pass 1 (reference, Claude):** a complete working implementation of SPEC.md is written into
  `reference/`, which mirrors the repo layout. `reference/` is gitignored, never packaged
  (`tools/package.sh` copies only the submission paths), and never copied into `src/`, `netcfg/`,
  `client/` or `server/`.
- **Review:** you go through every SPEC item in `reference/` with Claude: design decisions, alternatives
  (Part V) and trade-offs. Record anything you change in SPEC §16.
- **Pass 2 (submission, you):** write `src/`, `netcfg/` and the launchers from `SPEC.md` **with `reference/`
  closed**. Use it afterwards only to compare behaviour (run both, diff the logs).
- **Guard:** `tools/check_compliance.sh` warns when a submitted file is ≥ 60% similar to its `reference/`
  counterpart. Rewrite flagged files from the SPEC.
- Claude may also explain concepts, review your code, debug, and write `tools/`, `tests/` and docs.

## I.3 Coding conventions
- **No comments** in submitted code, except where something important must be defined: a protocol
  constant's meaning, a non-obvious invariant, or a deliberate deviation from an RFC. Explanations belong
  in the report.
- Same rule for docstrings. Function and variable names carry the meaning.
- Tooling in `tools/` keeps at most a one-line usage header.
- Python 3.10 compatible, stdlib only (see III.7). LF line endings. 4-space indent. One consistent style,
  enforced by ruff (`tools/host/ruff.toml`).
- Every step ends with `tools/check_compliance.sh` passing and a commit. Tag each milestone (`m1` … `m7`).

## I.4 Clean-room protocol (originality by construction)
**Solo rule (default):**
1. **Before Phase 15, don't read public TCP or HTTP implementation code.** Use the handout, RFCs, man pages,
   textbooks for concepts, `SPEC.md`, and Claude's explanations. `docs/clean-room/avoid.md` is pre-filled
   from Part VI.1 (public architecture families, described by shape and vocabulary only, without code), so
   you know what to stay away from without looking at it.
2. **Audit (Phase 15):** only then build `refcorpus/` (gitignored, HOST only, never copied to VMs or into
   `src/`), run the similarity tools, and rewrite avoidable matches from the SPEC without the matched
   source open. Re-test and re-audit until clean.

**Two-person variant (Part II-B.1 only):** the member who does **not** implement a component surveys
public code for it in Phase 0 and records high-level ideas and idioms (no code) in
`docs/clean-room/public-impls.md`. The implementer reads only `avoid.md`. Phase 15 is the same.

---

# Part II — Workflow (solo track, architecture C-1)

This workflow assumes **one person on one machine** (your Apple Silicon Mac with four VMs). The design is
fixed in **`SPEC.md`**, which has every item's behaviour, locked decisions and acceptance tests. This part
only covers order and time.

**Markers:**
- **unmarked:** required, because the handout grades it or nothing else works without it.
- **[Rec]:** not graded, but strongly recommended because it protects the grade (testing, originality,
  viva).
- **Optional work:** everything else lives in **Part II-B**. Skipping it never blocks a later step.

**Running it start to finish.** After `setup.md` is complete, every phase depends only on earlier phases,
your own work and Claude's reviews. Nothing waits on another person. The only external inputs are the TA
answers (Step 0.2), and each pending item has a default in SPEC §14, so even those never block you.
"Start to finish" doesn't mean one sitting: solo, budget **≈ 90–120 hours**, about 4 weeks part-time.
You write all submitted code yourself (handout §10; I.2). Claude explains, reviews and debugs.

**Where things run:** `HOST` = your Mac; `CLIENT`, `R1`, `R2`, `SERVER` = the VMs, with the repo at
`/mnt/a3`.

**Every step:**
1. Read the SPEC item.
2. Write the code.
3. Unit or harness tests green.
4. `tools/check_compliance.sh` passes (the pre-commit hook enforces it).
5. Commit.
6. Update "Current position" and `log.txt` (sections 0, 3, 5, 8).

If you change the SPEC, add a line to SPEC §16 first.

**Why C-1 sets this order:** the whole TCP core is proven in an in-process simulator (Phase 6) before any
socket code exists (Phase 8). The VMs then only test the thin driver.

```
P0 ─ P1 ─ P2 NET ─ P3 ENV+spike ─ P4 pipelines ─ P5 seams+parsers ─ P6 core ─ P7 HTTP client ─ P8 driver
   ─ P9 HTTP server ─ P10 integrate ─ P11 CC ─ P12 robust ─ P13 Part E+fairness ─ P14 regression
   ─ P15 audit ─ P16 report+package ─ P17 viva
```

| Milestone | Meaning | Tag |
|---|---|---|
| M1 | network verified on fresh VMs | `m1` |
| M2 | core passes every harness scenario | `m2` |
| M3 | real handshake, close and failure paths on the VMs | `m3` |
| M4 | first real download, md5 MATCH | `m4` |
| M5 | robust under loss and reordering | `m5` |
| M6 | fairness within bounds | `m6` |
| M7 | submitted | `m7` |

---

## Phase 0 — Kickoff (3–4 h)
- [ ] **0.1** Read the handout, Parts I and III of this file, and SPEC §1–§2.
- [ ] **0.2** Send TA questions Q1–Q10 (`docs/ta-questions.md`) and record the answers. **Q10 asks whether
      a solo submission is allowed**; the handout assumes two-person teams.
- [ ] **0.3** `setup.md` S0–S3 done (private repo, `setup-dev.sh`, first commit).
- [ ] **0.4 [Rec]** Read `docs/clean-room/avoid.md` (pre-filled from Part VI.1 and SPEC §1.6). Per the solo
      clean-room rule (I.4), **don't read any public TCP or HTTP implementation code** until Phase 15.
- [ ] **0.5** Contract freeze: review SPEC §1.4 (layout), §1.5 (invariants) and §2 (C1–C7). Rename
      anything you want, record the final names in SPEC §16, and mark the contracts frozen.
- [ ] **0.6** Fill in the team, language and build sections of `README.md`.

## Phase 1 — Environment (setup.md S4–S7, 2–3 h)
- [ ] **1.1** `tools/host/check-host.sh` shows no MISSING lines.
- [ ] **1.2** `setup.md` S4–S7: hypervisor, networks, base VM, four VMs, `fresh` snapshots, `docs/vm-map.md`.
- [ ] **1.3** R1 adapter-settings screenshots (`setup.md` S7.4).

## Phase 2 — Network configuration: SPEC §3 (4–6 h) → M1
- [ ] **2.1** On paper, re-derive SPEC §3 NET-3/4/5 and understand each line (viva).
- [ ] **2.2** NET-1 · **2.3** NET-2 · **2.4** NET-3 · **2.5** NET-4 (include the per-interface forwarding
      test on r1) · **2.6** NET-5 · **2.7** NET-6 (confirm it is out of scope) · **2.8** NET-7.
- [ ] **2.9** On each VM, run your script, then `bash /mnt/a3/tools/test/verify-routing.sh <node>`. Iterate
      with `sudo bash /mnt/a3/tools/vm/reset-net.sh <IFs>`. Then do a **fresh-boot test**: restore every
      VM's `fresh` snapshot and run the scripts once, with no manual steps.
- [ ] **2.10** R1, R2 and R3 screenshots and draft text. Snapshot every VM as `netcfg-ok`. Tag `m1`.

## Phase 3 — Launch environment and spike: SPEC §4 (4–5 h)
- [ ] **3.1** SERVER: `bash /mnt/a3/tools/test/gen-www.sh ~/www`, then
      `cd ~/www && python3 -m http.server 8000`. CLIENT: curl `1M.bin` and check its md5.
- [ ] **3.2** ENV-1 launchers.
- [ ] **3.3 [Rec]** Spike in `scratch/` (throwaway): send a hand-built SYN and see the SYN-ACK arrive on
      Link D, the kernel RST (screenshot it), the kernel's IP-header rewrites, and the TTLs.
- [ ] **3.4** ENV-2 chains: the handshake completes and the kernel RST is gone.
- [ ] **3.5** ENV-3 probe with `tools/vm/offloads.sh show|off` while receiving 10M.bin. Apply the SPEC
      rule and record the result in SPEC §16 and `docs/design/spike-notes.md`.

## Phase 4 — Pipelines: SPEC §2 + §5 (7–9 h)
- [ ] **4.1** C1 `settings.py` (APP-2).
- [ ] **4.2** C2 `packets/records.py`; C3 and C5 `core/vocab.py`.
- [ ] **4.3** IP-3 checksum.
- [ ] **4.4** TCP-5 sequence space.
- [ ] **4.5** TCP-1, IP-1, IP-2 and egress composition.
- [ ] **4.6** Ingress gates 1–7 (IP-4, TCP-4, TCP-2, TCP-3).
- [ ] **4.7** LOG-2 formatter, validated with `tools/test/check_log.py`.
- [ ] **4.8** Round-trip and capture tests (bytes from Step 3.3's pcaps via `tcpdump -xx`).
      `tools/test/run-unit.sh` is green.

## Phase 5 — Test seams and parsers: SPEC §6 (7–10 h)
- [ ] **5.1** APP-4a fake stream (C4).
- [ ] **5.2 [Rec]** APP-4b simulation harness: virtual clock, channel model, scenario library. It isn't
      graded, but C-1 relies on it: without it, Phase 6 can only be tested on the VMs, which is slower and
      much harder to debug.
- [ ] **5.3** API-2 parsers with byte-level tests.

## Phase 6 — Sans-I/O core: SPEC §7 (12–16 h) → M2
- [ ] **6.1** TCP-15 inbound half.
- [ ] **6.2** TCP-14a RTO estimator.
- [ ] **6.3** TCP-13/14b outbound half, with the placeholder congestion object.
- [ ] **6.4** Coordinator: TCP-6 hand-off, TCP-9 order, TCP-7, TCP-10, TCP-11, TCP-17.
- [ ] **6.5** TCP-8 listener.
- [ ] **6.6** Harness campaign: every scenario in SPEC APP-4b, with logs valid under `check_log.py`.
      Tag `m2`.

## Phase 7 — HTTP client: SPEC §8 (6–8 h; against the fake stream)
- [ ] **7.1** HCL-1 · **7.2** HCL-2 (30+ URL cases) · **7.3** HCL-3 · **7.4** HCL-4 · **7.5** HCL-5/6 ·
      **7.6** HCL-7 · **7.7** HCL-8 · **7.8** HCL-9.

## Phase 8 — Driver: SPEC §9 (7–10 h) → M3
- [ ] **8.1** IO-1, IO-2, IO-3 `wire.py`.
- [ ] **8.2** IP-5/IP-6 addressing, plus the TCP-6 UDP helper socket.
- [ ] **8.3** LOG-1/3/4 journal.
- [ ] **8.4** APP-3 trace.
- [ ] **8.5** TCP-12 pump.
- [ ] **8.6** C4 stream (API-1/3), plus ENV-4 and APP-5 entry hooks.
- [ ] **8.7 VM acceptance** (SPEC §9 list):
  - on R1, `sudo bash /mnt/a3/tools/test/netem.sh <IF_B> lossy 100` for 3 s, then `… clear`;
  - Refused / HandshakeTimeout checks;
  - all logs pass `check_log.py`.

  Tag `m3`.

## Phase 9 — HTTP server: SPEC §10 (7–9 h; against the fake stream)
- [ ] **9.1** HSV-1 · **9.2** HSV-4 · **9.3** HSV-5 · **9.4** HSV-6 · **9.5** HSV-7 · **9.6** HSV-8 ·
      **9.7** HSV-3 · **9.8** HSV-9 · **9.9** HSV-2/10.
- [ ] **9.10** Phase 9 acceptance on the fake stream (SPEC §10).

## Phase 10 — Integration: SPEC §11 (4–6 h) → M4
- [ ] **10.1** Client ↔ reference server, md5 MATCH for four files. Tag `m4`.
- [ ] **10.2** Real-server client cases. Write `tools/test/chunked-server.py` at this step. R4 screenshots.
- [ ] **10.3** Our server with curl, wget, our client and `server-edge.sh`. R5 screenshots.

## Phase 11 — Congestion control: SPEC §12 (4–6 h)
- [ ] **11.1** TCP-16 with unit tests per event.
- [ ] **11.2 [Rec]** Harness bottleneck scenario: sawtooth in the trace.
- [ ] **11.3** VMs: `netem.sh <R2_IF_D> bottleneck 20mbit 10ms`, 10M.bin, trace kept for R6.

## Phase 12 — Robustness: SPEC §13 (5–7 h) → M5
- [ ] **12.1** Loss and reordering matrix (T12) · **12.2** forced-ISN wrap · **12.3** failure paths ·
      **12.4** GRO on/off. Results go in `docs/test-results.md`. Clear all qdiscs. Tag `m5`.

## Phase 13 — Part E and fairness: SPEC §13 (4–6 h) → M6
- [ ] **13.1** Interop matrix.
- [ ] **13.2** `tools/test/fairness.sh` 1v1, then 3v3 (T14 says "several"). Tune TCP-16 if needed.
- [ ] **13.3** R6 capture, trace and description draft. Tag `m6`.

## Phase 14 — Regression [Rec] (3–4 h)
- [ ] **14.1** Fill unit-test gaps. Write `tools/test/run-all.sh` (unit tests plus the harness campaign,
      then print the VM checklist).
- [ ] **14.2** Full regression from `netcfg-ok`: 2.9, 8.7, 10.1–10.3, a reduced 12.1, 13.2.
- [ ] **14.3** Freeze behaviour.

## Phase 15 — Originality audit [Rec] (5–9 h)
The handout checks code against public TCP implementations. This phase finds accidental resemblance
before the graders do. It is the first time you look at public code (I.4).

- [ ] **15.1** Build the corpus in `refcorpus/`, using the families in Part VI.1 (F1, F2, F15 first) and the
      searches in `docs/clean-room/public-impls.md`.
- [ ] **15.2** Write `tools/audit/run-audit.sh` (Dolos and JPlag; `setup.md` S9) → `audit-out/`.
- [ ] **15.3** Triage matches as forced or avoidable in `docs/clean-room/audit-log.md`. Also compare the
      overall shape against VI.1.
- [ ] **15.4** Rewrite avoidable matches **in your own words from the SPEC**, without the matched source
      open.
- [ ] **15.5** Re-run 14.2, then re-audit until clean.
- [ ] **15.6** Comment review (SPEC I6).

## Phase 16 — Report and packaging (6–8 h) → M7
- [ ] **16.1** R1–R6 text, matching the final code (the SPEC §7 phase table goes into R6). Re-shoot stale
      screenshots.
- [ ] **16.2** Build `report.pdf` at the repo root.
- [ ] **16.3** `README.md` with no TODOs, including the ENV-2/ENV-3 launcher behaviour and the HCL-7
      partial-output note. Run `tools/package.sh <ENTRY>` (solo) or `tools/package.sh <E1> <E2>`.
- [ ] **16.4** Grader dry run: restore every VM's `fresh` snapshot, copy in only the zip, unzip it to
      `/tmp/sub`, run the netcfg scripts, then `verify-routing`, `md5check` and `server-edge`, with the
      launchers invoked from another directory.
- [ ] **16.5** Upload to Gradescope, re-download, and compare checksums. Tag `m7`.

## Phase 17 — Viva (3–4 h)
- [ ] **17.1** Explain every SPEC item out loud from the code alone, with no notes. Claude can quiz you.
- [ ] **17.2** Go through `docs/viva-prep.md` out loud. Re-derive the checksum and the r2 routing on paper.
- [ ] **17.3** Rehearse the demo: netcfg, traceroutes, a download under loss, fairness, the log lines.

---

# Part II-B — Optional work (never required by the solo track)

| ID | Optional item | When it helps | How |
|---|---|---|---|
| O1 | **x86-64 grader dry run** (strongly suggested if you can borrow one) | your VMs are arm64; the grader is x86-64 | repeat Step 16.4 on any x86-64 machine using `setup.md` O2; or rely on the TA's answer to Q9 |
| O2 | **Teammate or second machine** | parallel work, or a second pair of eyes before the viva | `setup.md` O1; the original two-person role split is in Part II-B.1 below |
| O3 | **netns sandbox** | fast network iteration without VMs | Linux or WSL2 hosts only (not macOS): `tools/netns/a3-topology.sh` (VII.5) |
| O4 | **Pacing** (SPEC §12 contingency) | only if Step 13.2 fairness is outside about 0.6–1.6 | SPEC §12, logged in SPEC §16 |
| O5 | **5v5 fairness runs** | stronger evidence for T14 and the report | `fairness.sh … 5 5` after 13.2 |
| O6 | **Plots for the report** | nicer R6 (cwnd and RTO over time) | from the APP-3 trace (JSON lines); any plotting tool |
| O7 | **Wireshark on the Mac** | reading captures graphically | `brew install --cask wireshark`; `tcpdump` in the VMs is enough otherwise |
| O8 | **pandoc** | building `report.pdf` from Markdown | `setup.md` S9; any word processor works |

### II-B.1 Two-person split (only if you have a teammate)
- **A:** Phases 2, 3, 4, 6, 8, 11.
- **B:** Phases 5, 7, 9, plus the report lead.
- **Both:** 0, 1, 10, 12–17.

Phases 5, 7 and 9 can run in parallel with 4, 6 and 8, which takes about 30% off the calendar time.
The two-person clean-room rule applies (I.4).

---

# Part III — Reference

## III.1 Assignment summary
Four Ubuntu VMs (client, r1, r2, server) on four isolated internal networks with hand-written,
deliberately **asymmetric** static routing. **TCP/IPv4 is implemented from scratch on raw sockets with
IP_HDRINCL.** On top of it go an HTTP/1.1 client and an HTTP/1.1 file server. They must interoperate with
curl, wget, and `python3 -m http.server`, survive loss and reordering, and share a bottleneck fairly with
kernel TCP. A report with VM screenshots is required, and there is a viva.

**Submission:** `A3_<E1>_<E2>.zip`, with entry numbers in CAPITALS, sorted alphabetically, exactly as on
the LMS, and no spaces or hyphens. One member uploads and adds the other. A solo submission would be
`A3_<E1>.zip`, if the TA allows it (Q10).
```
netcfg/{client,r1,r2,server}.sh · client/run-client · server/run-server · src/… ·
Makefile (optional; run as root, offline) · README.md · report.pdf
```
Never include binaries, captures, VM images, this file, `tools/`, `tests/`, `docs/`, or `refcorpus/`.

## III.2 Part A — addressing, requirements, design analysis
| Machine | Net | Address | Script args |
|---|---|---|---|
| client | LAN A / Link D | 10.10.1.10/24 · 10.10.4.2/30 | `client.sh IF_A IF_D` |
| r1 | LAN A / LAN B | 10.10.1.1/24 · 10.10.2.1/24 | `r1.sh IF_A IF_B` |
| r2 | LAN B / LAN C / Link D | 10.10.2.2/24 · 10.10.3.1/24 · 10.10.4.1/30 | `r2.sh IF_B IF_C IF_D` |
| server | LAN C | 10.10.3.10/24 | `server.sh IF_C` |

**A1** every machine reaches every address on LANs A, B, C; client and r2 reach each other over Link D ·
**A2** client→r1→r2→server · **A3** server→r2→client over Link D · **A4** r1/r2 forward, hosts don't ·
**A5** r1: one route for all non-attached networks, nothing else · **A6** r2: no default ·
**A7** baseline rp_filter=1 everywhere, stays strict on r1 and server · **A8** static only.
Scripts run once as root on a fresh boot (interfaces DOWN, no addresses), use **only `ip` and `sysctl`**,
and touch only the interfaces passed as arguments. No persistence is needed.

**Design analysis:**
- **client:** connected A, D. Everything else goes via r1 (10.10.1.1).
- **r1:** connected A, B, plus one default via r2 (10.10.2.2).
- **server:** default via r2 (10.10.3.1).
- **r2:** connected B, C, D, no default. LAN A goes **via r1**, and **only 10.10.1.10/32** goes via Link D
  (10.10.4.2). Sending all of 10.10.1.0/24 via Link D would break 10.10.1.1 reachability, since the client
  won't forward (A1/A4).
- **rp_filter:** strict mode breaks in exactly two places. On **client IF_D**, server traffic arrives on
  Link D, but the route back goes via IF_A. On **r2 IF_B**, client traffic arrives from r1, but r2's route
  back goes via Link D. Set both to **2 (loose)**. The effective value is `max(conf.all, conf.<if>)`, so
  setting an interface to 0 has no effect while all=1. r1 and the server remain strict and correct.
- **Forwarding:** global `ip_forward` affects all interfaces, while `conf.<IF>.forwarding` controls
  forwarding of packets received on that interface (kernel ip-sysctl docs). Verify in 2.5.
- **Expected traceroutes:** client→server `10.10.1.1, 10.10.4.1, 10.10.3.10`. r2's ICMP source is the
  address of its route **toward the client**, which is Link D. server→client `10.10.3.1, 10.10.1.10`.
- **G-TTL:** the client receives server packets with ttl=63 (one router); the server receives client
  packets with ttl=62 (two routers).

## III.3 Part B — TCP requirements
**T1** full IPv4 header and checksum, ID ≠ 0 · **T2** full TCP header and checksum ·
**T3** SYN/SYN-ACK carry exactly one option, MSS=1460; payload ≤ min(1460, peer MSS) ·
**T4** verify checksums and drop bad packets silently; use the peer's MSS, ignore other options ·
**T5** only own-connection packets · **T6** random ISN ·
**T7** SYN/SYN-ACK retransmit ≤1 s, keep trying ≥6 s · **T8** RST → abort immediately ·
**T9** ACK the peer's FIN; retransmit our FIN until ACKed and wait for the peer's FIN; give up ≤2 s; no TIME_WAIT ·
**T10** in-flight ≤ min(cwnd, rwnd), cumulative ACKs, RTO ≤1 s, give up after 10 s without progress ·
**T11** in-order exactly-once delivery, ACK every data segment, fixed window 65535 ·
**T12** correct under loss and reordering; buffer out-of-order segments within the window ·
**T13** client port random in 61000–65535; server port from `-p` ·
**T14** Reno-style CC, roughly fair with kernel TCP, including several flows of each kind.

**Log (`--log`):** `DIR SRC_IP:SPORT > DST_IP:DPORT ttl=T id=I seq=S ack=A flags=0xFF win=W len=L mss=M`.
One line per sent segment (including retransmissions and pure ACKs) or per accepted received segment.
Raw unsigned seq/ack; ack printed even without the ACK flag; flags = byte 13 as `0x%02x`; `mss=-` when
the option is absent. Flush each line.
**Not required:** window scaling, SACK, timestamps, TIME_WAIT, urgent data, IP options, fragmentation,
IPv6, zero-window probes, concurrent connections per process, keep-alive, HTTPS, redirects, compression,
request bodies.

## III.4 Parts C, D, E
**Client:** `sudo ./client/run-client URL [-o OUTFILE] [--log LOGFILE]`.
- URL: `http://HOST[:PORT][/PATH]`, default port 80, default path `/`, query strings allowed.
- Request: one GET with the target as written, Host as written, `Connection: close`, no Accept-Encoding.
- Body framing: Content-Length, chunked (ignoring extensions and trailers), or close-delimited.
  Header names are case-insensitive.
- Output: body to the file or stdout; status line to stderr.
- Exit codes: **0** complete 2xx · **1** complete non-2xx (body saved, no redirects) · **2** anything else.

**Server:** `sudo ./server/run-server [-p 8080] [-d ./www] [--log FILE]`.
- Runs forever, one connection at a time, and never exits because of a client.
- Accepts on any local address and replies from the SYN's destination address.
- Request head must complete within 10 s, otherwise the connection closes with no response.
- Status, checked in this order:
  - **400:** request line isn't `METHOD SP TARGET SP HTTP/x.y`, or the target doesn't start with `/`
  - **501:** method is not GET or HEAD
  - **403:** a path segment is `..`
  - **404:** the file doesn't exist
  - **200:** otherwise
- Path mapping: strip the query, append to DOCROOT. A trailing `/` or a directory maps to `index.html`.
  No percent-decoding.
- Every response is HTTP/1.1 with Content-Length, Content-Type, and `Connection: close`. Error responses
  carry small HTML bodies. HEAD returns the GET headers with no body.
- Content-Type by extension, case-insensitive:

  | Extension | Content-Type |
  |---|---|
  | html, htm | text/html |
  | txt | text/plain |
  | css | text/css |
  | js | application/javascript |
  | json | application/json |
  | png | image/png |
  | jpg, jpeg | image/jpeg |
  | gif | image/gif |
  | pdf | application/pdf |
  | anything else | application/octet-stream |

**Part E:** our client on CLIENT downloads from our server on SERVER. Loopback is not supported.

## III.5 Gotchas
- **G1 Kernel RSTs.** The kernel doesn't know our connections, so it RSTs the peer's SYN-ACK (client side)
  or SYN (server side). Running programs is allowed only in launchers, so suppress these with a scoped,
  idempotent firewall rule there. 61000–65535 sits above Linux's ephemeral range (32768–60999), so
  curl's ports never overlap ours.
- **G2 IP_HDRINCL.** The kernel still fills in the IP checksum and total length, and fills ID and source
  if they are zero (raw(7)). Checksum bugs are therefore invisible on the wire, so unit-test them.
- **G3 GRO.** Coalesced receive packets reach the raw socket with lengths over the MSS and a checksum field
  that isn't a full checksum. Probe this in Step 3.5 and decide a policy; ask the TA about grading VMs (Q3).
  Related: if the *sending* side leaves its TCP checksum to offload on a virtual link (seen on loopback and
  veth), every arriving segment fails T4 as `bad-tcp-csum` (visible with `A3_TRACE`). Check for it in the
  same probe; for tests, `ethtool -K <IF> tx off` on the sender fixes it.
- **G4 Shared raw socket.** The raw socket sees all TCP on the machine (including curl during fairness
  tests). Filter early and raise `SO_RCVBUF`.
- **G5 Source address.** Client: use the UDP `connect()` + `getsockname()` trick (no packet sent).
  Server: reply from the SYN's destination address.
- **G6** Sequence comparisons are modulo 2^32 everywhere.
- **G7** RTO and its backoff are capped at 1 s. Handshake: retransmit ≤1 s, persist ≥6 s.
- **G8** The 65535 window caps throughput at 64 KB per RTT. Keep the test bottleneck × RTT under 64 KB.
- **G9** SYN-ACK carries MSS only. This disables wscale, SACK, and timestamps for the peer too.
- **G10** "Several connections of each kind" combined with a one-connection server likely means several
  server instances on different ports (TA Q5).
- **G11** IP ID: random non-zero start, increment, skip 0. TTL 64. DF set.
- **G12 VM pitfalls.** Cloned netplan runs DHCP on internal NICs; `wait-online` adds a 2-minute boot
  delay; CRLF line endings break shebangs; a top-level dev Makefile would be run by the grader.

## III.6 Decisions (recommendation → final choice)
| # | Decision | Recommendation (reason) | Decision log |
|---|---|---|---|
| D1 | Language | **Python 3.10.** `struct` packing, no build step, fastest debugging, easiest viva | Adopted: Python 3.10 (SPEC §14) |
| D2 | Hypervisor/NIC | **VirtualBox + e1000** (UTM on Apple Silicon), Ubuntu 22.04 server, linked clones | Adopted |
| D3 | Client routes | **Default via r1** (conventional host setup) | Adopted (SPEC NET-3) |
| D4 | r2 LAN A routes | **/24 via r1 + 10.10.1.10/32 via Link D** (only the client deviates) | Adopted (SPEC NET-3) |
| D5 | rp_filter | **2 on client IF_D and r2 IF_B only**; per-interface keys, `conf.all` untouched | Adopted (SPEC NET-5) |
| D6 | Forwarding | **Per-interface `conf.<IF>.forwarding`**, verified in 2.5 (TA Q4) | Adopted, pending Step 2.5 / Q4 (SPEC NET-4) |
| D7 | RST suppression | **iptables in the launcher**, scoped to the port or range, idempotent; SO_MARK exemption if we ever send RSTs | Adopted: chains A3C/A3S, no SO_MARK (SPEC ENV-2) |
| D8 | Socket layout | **One `SOCK_RAW/IPPROTO_TCP` socket, `IP_HDRINCL=1` set explicitly** | Adopted (SPEC IO-1) |
| D9 | Concurrency | **Synchronous pump: single-threaded `select` loop driven by API calls, timers as deadline fields** (see V.5 TCP-12) | Adopted (SPEC TCP-12) |
| D10 | CC | **NewReno + byte counting (RFC 3465) + IW10** (see V.5 TCP-16) | Adopted (SPEC §12) |
| D11 | RTO | **RFC 6298 + Karn**, min ~200 ms, max 1 s | Adopted (SPEC TCP-14a) |
| D12 | Test impairments | **r2 IF_D** (data) and **r1 IF_B** (requests/ACKs) | Adopted |
| D13 | Roles | Solo track: one person does every phase (Part II); two-person split in Part II-B.1 | Adopted: solo |
| D14 | Whole-stack architecture (APP-1) | C-1: X1 sans-I/O core + X2 half-connections + X4 pipelines | **Adopted 2026-10-10** (SPEC §1) |
| D15+ | Per-item picks | All locked in SPEC §3–§12; pending items in SPEC §14 | SPEC §16 change log |

## III.7 Implementation rules
- C, C++, or **Python, stdlib only**, on Ubuntu 22.04 x86-64 (gcc 11 / Python 3.10), offline.
- **No IP_HDRINCL → zero for Part B.**
- **Forbidden → zero for Parts B–E:** `SOCK_STREAM`, `connect()` on TCP, `listen()`, `accept()`,
  `AF_PACKET`, scapy/dpkt/libpcap/libnet, `http.client`/`http.server`, `urllib` (including
  `urllib.parse`), requests, socketserver, asyncio, libcurl, and running programs (system, popen,
  subprocess, exec*) outside launchers.
- Launchers: executable, use `exec`, pass `"$@"`, and work from any working directory.

## III.8 Report and grading
- **R1** adapter settings, plus `ip -br addr` and `ip route` on all four VMs.
- **R2** `traceroute -n` in both directions, with every hop explained (why the directions differ, and r2's
  address).
- **R3** rp_filter per machine and why.
- **R4** our client against `python3 -m http.server` (HTML + ≥100 KB binary), with exit codes and md5 vs curl.
- **R5** curl, wget, and our client from our server; md5 matches the original.
- **R6** tcpdump/Wireshark of one full connection, plus retransmission, out-of-order buffering, and CC.

Grading: A 10 · B 15 · C 15 · D 15 · E 15 · Report 10 · **Viva 20**.

---

# Part IV — Repository

## IV.1 Layout
```
COL334_A3/
├── README.md                    SUBMITTED: team, language/runtime, build
├── SPEC.md                      design spec (NOT submitted)
├── instructions.md              this file (NOT submitted)
├── setup.md  log.txt            setup checklist; progress/bug log (NOT submitted)
├── reference/                   pass-1 AI reference implementation (gitignored, NEVER submitted; I.2)
├── netcfg/ client/ server/      SUBMITTED scripts and launchers
├── src/                         SUBMITTED code, laid out per SPEC §1.4:
│   ├── http_client.py http_server.py settings.py
│   ├── packets/  records checksum seqspace ipv4 tcpwire ingress egress logline
│   ├── core/     vocab inbound outbound rto congestion endpoint listener
│   ├── driver/   wire addressing journal pump stream
│   └── web/      parsing urlparts fetch serve content
├── report/report.md, screenshots/R1..R6/  → report.pdf at repo root before packaging
├── docs/
│   ├── handout.pdf  ta-questions.md  vm-map.md  viva-prep.md  test-results.md
│   ├── design/      spike-notes.md
│   └── clean-room/  public-impls.md  avoid.md  audit-log.md
├── tools/                       NOT submitted
│   ├── package.sh  check_compliance.sh
│   ├── host/        check-host.sh  setup-dev.sh  requirements-dev.txt  ruff.toml
│   ├── git-hooks/   pre-commit
│   ├── vm/          vbox-create-base.sh  vbox-clone-topology.sh  install-packages.sh  seal-base.sh
│   │                baseline-rpfilter.sh  reset-net.sh  offloads.sh
│   ├── netns/       a3-topology.sh
│   ├── test/        run-unit.sh  verify-routing.sh  netem.sh  gen-www.sh  md5check.sh  server-edge.sh
│   │                fairness.sh  check_log.py  (+ chunked-server.py @10.2, run-all.sh @14.1)
│   └── audit/       (run-audit.sh @15.2)
├── tests/                       NOT submitted: unit/, fakes.py @5.1, harness/ @5.2
├── .gitattributes .editorconfig .python-version .vscode/   editor/git config
└── (gitignored) .venv/ scratch/ refcorpus/ captures/ dist/ audit-out/ tests/www/
```

## IV.1b Copies of the repo and how they stay in sync
| Copy | Role | Synced by |
|---|---|---|
| `~/Desktop/COL334 A3` (Mac) | **master working copy**, git | you (edits, commits) and Claude (writes files into it) |
| GitHub private repo | backup and history | `git push` from the Mac |
| Claude Project "COL334 A3" → `COL334_A3/…` | mirror for reading in any Claude chat; same paths as the repo; `COL334_A3/MANIFEST.txt` lists every file incl. empty ones | Claude, when you ask "sync the project" (from the Mac folder) |
| VMs `/mnt/a3` | read-only copy for running | `make-transfer-iso.sh` + `vbox-clone-topology.sh transfer` |
Never commit from anywhere but the Mac copy. The Project mirror excludes `.git`, `.venv`, caches and binaries
(the handout PDF is already a Project file).

## IV.2 Tools index (where each is first used)
| Tool | Runs on | First used (step) |
|---|---|---|
| `tools/host/setup-dev.sh`, `check-host.sh` | HOST | 0.3, 1.1 |
| `tools/git-hooks/pre-commit` (auto) | HOST | every commit |
| `tools/vm/vbox-create-base.sh` | HOST (VirtualBox) | 1.2 |
| `tools/vm/install-packages.sh` | BASE VM (NAT attached) | 1.2 |
| `tools/vm/seal-base.sh` (+ `baseline-rpfilter.sh`) | BASE VM | 1.2 |
| `tools/vm/vbox-clone-topology.sh` | HOST (VirtualBox) | 1.2, 2.9, 2.10, 16.4 |
| `tools/netns/a3-topology.sh` | Linux/WSL2 HOST | 1.3, 2.9, then any time |
| `tools/vm/reset-net.sh` | any VM | 2.9 |
| `tools/test/verify-routing.sh` | each VM / sandbox node | 2.9, 14.2, 16.4 |
| `tools/test/gen-www.sh` | SERVER | 3.1 |
| `tools/vm/offloads.sh` | CLIENT, SERVER | 3.5, 12.4 |
| `tools/test/run-unit.sh` | HOST / VM | 4.3 onward (and pre-commit) |
| `tools/test/check_log.py` | any | 4.7, 6.6, 8.7 onward |
| `tests/fakes.py`, `tests/harness/` (you write) | HOST | 5.1, 5.2, then 6.x, 7.x, 9.x, 11.2 |
| `tools/test/netem.sh` | R1, R2 | 8.7, 11.3, 12.1, 13.2 |
| `tools/test/md5check.sh` | CLIENT | 10.1, 10.2, 10.3, 14.2, 16.4 |
| `tools/test/chunked-server.py` (to write) | SERVER | 10.2 |
| `tools/test/server-edge.sh` | CLIENT | 10.3, 14.2, 16.4 |
| `tools/test/fairness.sh` | CLIENT | 13.2 |
| `tools/test/run-all.sh` (to write) | HOST / VM | 14.1 |
| `tools/audit/run-audit.sh` (to write) | HOST | 15.2 |
| `tools/check_compliance.sh` | HOST | every step (and pre-commit) |
| `tools/package.sh` | HOST | 16.3 |

## IV.3 TA questions
See `docs/ta-questions.md` (Q1 zip root · Q2 iptables in launchers · Q3 GRO on grading VMs ·
Q4 per-interface forwarding · Q5 multi-instance fairness · Q6 AI-assisted tooling · Q7 stdlib modules ·
Q8 transfer image / shared folders under the isolation rule).

## IV.4 Progress log
| Date | Who | Step | Note |
|---|---|---|---|

---

# Part V — Functionalities and architecture options by layer

> **Catalogue only.** This part records the options and trade-offs considered for each item. The adopted
> choices are locked in `SPEC.md` (architecture C-1), which wins wherever the two differ (for example
> TCP-14 timeout handling, TCP-11 FIN gating and NET-6, which SPEC refines).

## V.0 Scope, legend, completeness

| Layer (bottom → top) | Who implements it | Section | Items |
|---|---|---|---|
| Ethernet, ARP, IP forwarding on r1/r2, ICMP, DNS protocol | kernel / libc (configured or called) | — | — |
| Network configuration | you (`netcfg/*.sh`) | V.1 NET | NET-1 … NET-7 |
| Launch environment | you (launchers) | V.2 ENV | ENV-1 … ENV-4 |
| Raw socket I/O | you | V.3 IO | IO-1 … IO-3 |
| IPv4 header processing | you | V.4 IP | IP-1 … IP-6 |
| TCP | you | V.5 TCP | TCP-1 … TCP-17 |
| Packet log | you | V.6 LOG | LOG-1 … LOG-4 |
| Byte-stream interface TCP↔HTTP | you | V.7 API | API-1 … API-3 |
| HTTP client | you | V.8 HCL | HCL-1 … HCL-9 |
| HTTP server | you | V.9 HSV | HSV-1 … HSV-10 |
| Program structure (cross-cutting) | you | V.10 APP | APP-1 … APP-5 |

Every item has the same four parts:
- **Required:** the exact behaviour, from the handout or from what the handout depends on. "(decision)"
  marks an edge case the handout leaves open and you must settle.
- **Approaches table:** S = standard (RFCs, textbooks, common stacks); N = uncommon in public
  implementations of this kind.
- **Pick:** the recommendation. Your final choice goes in the III.6 decision log.

When there is no sensible N option, the item says so and explains why.

**Completeness.** V.12 maps every handout clause to these items. Two classes of work are deliberately
outside the list: test-only tooling (`tools/`, `tests/`) and documents (README, report).
TA answers to Q2/Q3/Q5 may add launcher or socket code; V.12 tracks those as open items.

---

## V.1 NET — Network configuration (Part A, `netcfg/*.sh`)

### NET-1 Argument and interface validation
**Required:** the exact argument count (client 2, r1 2, r2 3, server 1); interfaces referenced only
through the arguments; fail without leaving a half-configured machine.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| `$#` check plus a usage message | S | simple | a typo in an interface name fails midway, leaving a partial config |
| Preflight `ip link show dev "$X"` for every argument before any change | N | all-or-nothing; clear errors | a few extra lines |

**Pick:** preflight.

### NET-2 Link bring-up and addressing
**Required:** Table 1 addresses with prefixes; links brought up; addresses configured before routes,
because a gateway must be on a connected network.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| One `ip addr add` / `ip link set … up` per line | S | familiar | `add` fails if the script is re-run |
| `ip addr replace` | S | idempotent | slightly less familiar |
| `ip -batch -` fed by a heredoc holding the machine's whole config | N | reads like the addressing table; one invocation that stops at the first error | less familiar; error line numbers refer to the batch |

**Pick:** `replace`, or batch.

### NET-3 Routing
**Required:**
- **client:** LANs B and C via r1.
- **r1:** connected routes plus exactly one other route.
- **server:** everything via r2.
- **r2:** no default route; LAN A via r1; 10.10.1.10/32 via Link D.

| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Static destination routes in the main table; default routes on the hosts and r1 | S | exactly what graders read in `ip route` | none |
| Explicit /24 routes on the hosts instead of defaults | S | no default route on the hosts | more lines, no gain |
| `src` hints on host routes (`… src 10.10.1.10`) | N | source selection is explicit (supports IP-5) | redundant with the kernel's choice |
| Nexthop objects (`ip nexthop` + `nhid`) | N | each gateway defined once | `ip route` shows `nhid`, which may confuse an automated A5 check |
| Policy routing (`ip rule` + extra table) | N | expresses intent | routes outside the main table may confuse A5/A6 checks |

**Pick:** main-table static routes, with optional `src` hints.

### NET-4 Forwarding control
**Required:** routers forward and hosts do not; touch only the given interfaces.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| `net.ipv4.ip_forward=1` | S | universally known | global: affects interfaces not passed as arguments |
| Per-interface `net.ipv4.conf.IF.forwarding` | S | respects the "given interfaces only" rule | verify it on the VMs |
| Least privilege: forward only on interfaces where forwarded traffic actually enters | N | tightest config | a generic grader test of A4 in both directions could fail |

Set 0 explicitly on the hosts' interfaces. **Pick:** per-interface, on all router interfaces.

### NET-5 Reverse-path filtering
**Required:** strict at the start; strict stays on r1 and the server; the asymmetric path still works.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Loose (2) on client IF_D and r2 IF_B only; `all` left at 1 | S | minimal relaxation (effective value is max(all, interface)) | the max rule must be explained |
| `all=0` plus per-interface 0 | S | — | disables the check entirely and touches `all` |
| Loose on every interface of the client and r2 | S | simple | over-permissive; weaker R3 |

There is no viable N option. Keeping the client strict would need the reverse lookup for packets from the
server to choose IF_D, but that lookup is the same flow as the client's own outgoing traffic to the server,
which must use r1 (A2). Use that argument in R3. **Pick:** minimal per-interface loose.

### NET-6 Redirect hardening (optional)
**Required:** nothing. This only protects A2/A3 from ICMP redirects changing the paths.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Kernel defaults | S | nothing to explain | — |
| Hosts set `accept_redirects=0` on their own interfaces | N | paths can't be silently changed | no redirects are expected in this topology |

**Pick:** optional.

### NET-7 Script robustness and self-check
**Required:** the script runs once on a fresh boot and leaves the machine compliant; it must not report
success after a failure.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| `set -e` | S | stops at the first error | — |
| End-of-script self-check using `ip route get <dst>` plus bash pattern matching, printing PASS/FAIL per expected next hop | N | proves the config with `ip` only; good R1 material | must not fail on checks that need other machines up |

**Pick:** both.

---

## V.2 ENV — Launch environment (`client/run-client`, `server/run-server`)

### ENV-1 Locating code and exec
**Required:** executable; uses `exec`; passes `"$@"`; works from any working directory; Python 3.10.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| The handout's `exec python3 "$(dirname "$0")/../src/x.py" "$@"` | S | given in the handout | breaks when invoked through a symlink |
| Resolve the path with `readlink -f "$0"` | N | survives symlinks | runs an extra program (allowed in launchers) |
| `python3 -B -E -s` | N | no `.pyc` files written as root; environment and user site-packages ignored | **never use `-I`**: it drops the script directory from `sys.path` |

**Pick:** the handout form plus `-B -E -s`.

### ENV-2 Kernel RST suppression (G1)
**Required:** the kernel must not reset connections it doesn't know about. Only the launchers may run
programs. Scope: the client's port range 61000:65535; the server's `-p` port (default 8080).
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Idempotent `iptables -C … \|\| iptables -I OUTPUT … --tcp-flags RST RST -j DROP` | S | short | also drops RSTs you send yourselves |
| The same rule in `nft` | S | modern | the `nft` binary may be missing |
| A dedicated chain (`-N A3`, flushed and refilled each launch, one jump from OUTPUT) | N | no rule pile-up; easy to inspect | more lines |
| `SO_MARK` on your own packets; drop only unmarked RSTs | N | your own RSTs still go out | needs a setsockopt; must be documented |

**Pick:** the dedicated chain; add SO_MARK only if TCP-10 decides you send RSTs.

### ENV-3 NIC offloads (G3)
**Required:** received segments must be ≤ MSS with valid checksums, or T4 drops them and transfers stall.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Leave offloads alone | S | no side effects | stalls if the grading NICs coalesce received packets (GRO) |
| The launcher disables GRO on non-loopback interfaces via `ethtool` | N | removes the failure mode | invasive change to the grader's machine |

**Pick:** decide after the GRO probe and the answer to TA Q3.

### ENV-4 Privilege check
**Required:** raw sockets need root; failure must be an exit-2 case with a clear message.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Let socket creation raise `PermissionError` | S | nothing to write | cryptic |
| Check `os.geteuid() == 0` at startup | N | clear message, exit 2 | — |

**Pick:** N.

---

## V.3 IO — Raw socket I/O

### IO-1 Socket creation and options
**Required:** `AF_INET`/`SOCK_RAW`; `IP_HDRINCL` effectively on (§6.2 gives zero marks without it); no
`AF_PACKET`; a receive buffer large enough for bursts while curl traffic shares the socket (G4).
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| One `IPPROTO_TCP` socket with `IP_HDRINCL=1` set explicitly, used for both send and receive | S | header inclusion visible to the grader; one descriptor | receives all TCP traffic on the machine |
| A send socket (`IPPROTO_RAW`, implies HDRINCL) plus a receive socket (`IPPROTO_TCP`) | S | clean direction split | HDRINCL implicit; two descriptors |
| One socket plus `SO_RCVBUF` raised (and `SO_MARK` if ENV-2 uses it) | N | fewer drops under load | must check the kernel actually granted the size |

**Pick:** one socket, explicit HDRINCL, raised `SO_RCVBUF`.

### IO-2 Transmit path
**Required:** send complete IPv4 datagrams to the peer address; never block the pump indefinitely; a send
error must surface as a TCP failure, not a crash.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Blocking `sendto(bytes, (dst, 0))` per packet | S | simple | a full socket buffer could stall timers |
| Non-blocking `sendto` with retry on the next pump iteration | S | timers never stall | a small retry queue is needed |
| A single `transmit(packet)` chokepoint that also logs (LOG-1) and traces (APP-3) | N | one place for send, log and trace | — |

**Pick:** non-blocking, through a single chokepoint.

### IO-3 Receive path and readiness
**Required:** wait for packets with a timeout equal to the nearest deadline; drain everything available
each time the socket is readable; cheap rejection of foreign traffic (TCP-4).
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Blocking `recvfrom` with `settimeout` | S | simple | one packet per wake-up; awkward with multiple deadlines |
| `select` then drain a non-blocking socket until `BlockingIOError` | S | handles bursts; one wake-up per burst | — |
| `recvfrom_into` a preallocated buffer plus `memoryview` | N | no per-packet allocation | lifetime care (copy anything kept) |
| Kernel BPF filter (`SO_ATTACH_FILTER` via `ctypes`) | N | foreign packets never reach Python | complex; TA Q7 |

**Pick:** `select` + drain + `recvfrom_into`; BPF only if needed.

---

## V.4 IP — IPv4 header processing

### IP-1 Header construction (T1)
**Required:** version 4, IHL 5, TOS 0, total length, ID ≠ 0, DF set, fragment offset 0, TTL 64,
protocol 6, header checksum, source and destination. The values written must equal the values logged.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| One `struct.pack` with a whole-header format string | S | compact | the most widely copied tutorial line |
| Field-by-field `int.to_bytes` into a bytearray | S | readable | verbose and slower |
| `ctypes.BigEndianStructure` with bitfields | N | mirrors the RFC 791 diagram | `ctypes` acceptability (Q7); slower |
| A per-connection 20-byte template, patching length, ID and checksum per packet (RFC 1624 incremental) | N | fast; distinctive | the incremental checksum needs tests |

**Pick:** field-level codec or template.

### IP-2 Identification
**Required:** never zero. Uniqueness doesn't matter with DF set (RFC 6864).
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Random start, add 1 per packet, skip 0 | S | trivial | the wraparound needs a test |
| A 16-bit maximal-length LFSR, which visits all 65,535 non-zero values | N | zero impossible by construction | needs a viva explanation |

**Pick:** either; the LFSR if you want the distinctive option and can explain it.

### IP-3 Internet checksum (shared with TCP)
**Required:** an RFC 1071 one's-complement sum, odd-length padding; computed on send and verified on
receive.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| RFC 1071 loop over 16-bit words | S | canonical | slow in Python; the most-copied snippet |
| Bulk unpack of all words, sum, fold carries | S | fast | common |
| `int.from_bytes(buf, "big") % 0xFFFF` | N | one expression, fast | the 0 vs 0xFFFF representation nuance must be explained |
| RFC 1624 incremental update | N | fastest with templates | only for patched headers |

**Pick:** bulk unpack or modular; incremental only together with IP-1 templates.

### IP-4 Parsing and validation of received datagrams
**Required:**
- version 4; IHL ≥ 5 (skip options)
- total length within the bytes received (trim padding)
- protocol 6; header checksum valid
- fragments (MF set or offset ≠ 0) dropped silently

| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Unpack 20 bytes, then an if-chain | S | simple | silent drops are hard to debug |
| Ordered validation gates returning a drop reason, with counters under the debug trace | N | shows why packets vanish | slightly more code |

**Pick:** gates.

### IP-5 Source-address selection
**Required:** the client uses the kernel's chosen source for the server's address (10.10.1.10 here). The
server replies from the address the SYN was sent to.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| UDP socket `connect()` + `getsockname()` (sends nothing) | S | the kernel's real choice | must be visibly UDP (compliance checker flags `connect` for review) |
| Parse `/proc/net/route` plus interface addresses via ioctl | S | no extra socket | fragile |
| A netlink `RTM_GETROUTE` query | N | exactly what `ip route get` does | heavy |

**Pick:** the UDP trick (client); the SYN's destination (server).

### IP-6 Local-address acceptance
**Required:** accept only datagrams addressed to this machine, for any of its addresses (server). Code
cannot run `ip` to list them.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Rely on the kernel: a raw socket only receives locally delivered datagrams | S | zero code | must be stated in the report |
| Enumerate addresses via ioctl `SIOCGIFCONF` | S | explicit check | complex; redundant |
| After the handshake, pin to the exact local address from the SYN (client: the chosen source) | N | the connection key becomes exact | — |

**Pick:** kernel delivery plus pinning after the handshake.

---

## V.5 TCP

### TCP-1 Segment encoding and outbound options (T2, T3)
**Required:**
- ports, seq, ack, data offset, flags, window **65535**, checksum (pseudo-header), urgent pointer 0, reserved bits 0
- SYN and SYN-ACK carry exactly one option, MSS = 1460; other segments carry none
- (decision) whether to set PSH on data segments

| Approach | Kind | Pros | Cons |
|---|---|---|---|
| A whole-header struct format plus a generic options builder | S | standard | copy risk |
| A field-level encoder with the MSS option as a constant 4-byte literal (kind 2, length 4, 1460) | N | no options code on the send side | — |

**Pick:** N; set PSH on the last segment of each `send` call.

### TCP-2 Inbound segment validation (T4)
**Required:** the TCP checksum over the pseudo-header built from the *received* IP addresses; data offset
≥ 5 and within the segment; bad segments dropped silently and never logged; options scanned defensively.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Parse fully, then verify | S | simple | parse cost for packets that turn out bad |
| Verify the checksum first, then parse | S | cheap rejection | — |
| A gate pipeline shared with IP-4 (cheapest test first, each returning a reason) | N | one consistent drop-reason system | — |

**Pick:** N.

### TCP-3 MSS negotiation (T3, T4)
**Required:** read the peer's MSS from its SYN or SYN-ACK; default to **536** if absent (RFC 9293
§3.7.1); effective send MSS = min(1460, peer MSS); ignore other options; skip unknown options by their
length; drop malformed option lists.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| A generic TLV loop decoding every option into a dict | S | general | decodes options you ignore |
| A scan that only looks for kind 2, skipping others by length, with a guard against zero length | N | small and robust | — |

**Pick:** N.

### TCP-4 Demultiplexing (T5)
**Required:**
- **listening server:** destination port = listening port, any local address.
- **after the handshake:** the exact four-tuple.
- **everything else:** ignored and not logged.

| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Parse the header and compare fields | S | clear | parses every foreign packet |
| Compare a raw 12-byte key (IP bytes 12–19 + TCP bytes 0–3) with a precomputed key before parsing | N | near-free rejection | IHL must be read first |

**Pick:** N.

### TCP-5 Sequence-number arithmetic
**Required:** correct comparisons and arithmetic across 2^32 wraparound for every field (seq, ack, window
edges).
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Modular comparisons everywhere | S | textbook | wraparound bugs can appear anywhere |
| Unwrapped offsets from the ISN using Python integers; convert at the codec; unwrap incoming values to the nearest candidate | N | wrap logic confined to two functions | the unwrap needs careful tests |

**Pick:** N.

### TCP-6 ISN and port selection (T6, T13)
**Required:** a random 32-bit ISN for each connection; client source port random in 61000–65535; the
server uses `-p`.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| `secrets.randbits(32)` ISN; `random.randint(61000, 65535)` port | S | trivial | — |
| RFC 6528 ISN (clock plus keyed hash of the four-tuple) | S | resists prediction | overkill |
| Hold a UDP socket bound to the same port number as a cross-process lock | N | two of your client processes never collide | extra socket; only coordinates your own processes |

**Pick:** S; the lock is optional.

### TCP-7 Connection establishment (T7)
**Required:**
- **Client (active open):** SYN → SYN-ACK → ACK. Retransmit the SYN at most 1 s apart and keep trying
  for at least 6 s; then fail with exit 2. Re-ACK any retransmitted SYN-ACK.
- **Server (passive open):** SYN → SYN-ACK, retransmitted at most 1 s apart for at least 6 s. Complete on
  the ACK, or on a data-bearing ACK, since curl sends its request at once. Resend the SYN-ACK on a
  duplicate SYN. If the handshake gives up, return to listening.

| Approach | Kind | Pros | Cons |
|---|---|---|---|
| A fixed 1 s retransmit interval, about 7 attempts | S | meets the spec exactly | slow recovery of a lost first SYN |
| Exponential backoff (Linux 1, 2, 4 s) | S | standard | violates the ≤1 s rule unless capped |
| A short-start schedule (250 ms, 500 ms, then 1 s until ≥6 s) | N | faster recovery | justify in the report |

**Pick:** N.

### TCP-8 Listening-state rules (server)
**Required:**
- only a SYN starts a connection
- non-SYN segments while listening are ignored (e.g. late retransmits from the previous connection)
- SYNs from other clients while busy are ignored (they retry)
- after a connection ends, return to listening on the same port
- never exit because of any of this

| Approach | Kind | Pros | Cons |
|---|---|---|---|
| A LISTEN state inside the full FSM | S | textbook | mixes listener logic into the connection state machine |
| A separate listener object that hands a validated SYN to a fresh connection object | N | the connection object never sees listener concerns; clean reset between connections | two objects to explain |

**Pick:** N.

### TCP-9 Connection state representation
**Required:** represent every reachable condition from establishment to the end of teardown, plus aborts,
with a deterministic per-segment processing order: acceptability → RST → SYN → ACK → data → FIN.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| The full 11-state RFC 9293 machine | S | textbook; easy to explain | many unused states |
| Table dispatch (state, event) → handler | S | explicit | verbose |
| State-pattern classes | S | per-state clarity | shared logic gets scattered |
| A hybrid: phase enum (CLOSED, SYN_SENT, SYN_RCVD, ESTABLISHED) plus close flags (fin_sent, fin_acked, fin_rcvd) | N | matches T9 directly | needs a mapping table to RFC names |

**Pick:** N.

### TCP-10 RST handling and outbound abort policy (T8)
**Required:**
- **SYN_SENT:** abort on a RST that acknowledges our SYN; this is "connection refused" → exit 2.
- **Synchronized states:** abort immediately on a valid RST.
- **Ignore** RSTs that don't belong to the connection.
- **(decision)** whether you ever *send* RSTs, e.g. on give-up or on an unexpected segment. Nothing in
  the handout requires it.

| Approach | Kind | Pros | Cons |
|---|---|---|---|
| RFC rule: accept a RST if its seq is in the window | S | correct | — |
| Accept any RST matching the four-tuple | S | simplest | stray RSTs abort the connection |
| RFC 5961-lite: abort on an exact `rcv_nxt` match; ignore an in-window but inexact RST | N | robust | slightly more code |
| Outbound: never send RSTs | S | simplest; consistent with ENV-2 dropping RSTs | the peer only learns of an abort by timeout |
| Outbound: send one RST on give-up (requires the SO_MARK variant of ENV-2) | N | the peer frees resources quickly | interacts with the launcher rule |

**Pick:** RFC 5961-lite inbound; never send outbound.

### TCP-11 Teardown (T9)
**Required:**
- ACK the peer's FIN only once all data before it has arrived (FIN processed in sequence order)
- after sending our FIN, retransmit it until ACKed and wait for the peer's FIN, giving up after at most 2 s
- handle simultaneous close
- no TIME_WAIT

| Approach | Kind | Pros | Cons |
|---|---|---|---|
| RFC states FIN_WAIT_1/2, CLOSING, LAST_ACK, CLOSE_WAIT | S | textbook | more states |
| A single 2 s close deadline over the three close flags | N | matches T9 exactly | — |
| Piggyback the FIN on the last data segment | N | saves one segment | the log shows FIN with data (valid, but explain it) |

**Pick:** the close deadline; piggybacking is optional.

### TCP-12 Event loop and timers
**Required timers:**
- handshake: ≤1 s apart, ≥6 s total
- retransmission: RTO ≤ 1 s
- no progress for 10 s → give up
- close: 2 s
- server request head: 10 s (in HTTP, via API deadlines)

| Approach | Kind | Pros | Cons |
|---|---|---|---|
| A background receive thread with locks and condition variables | S | TCP advances independently | races; GIL jitter in RTT samples |
| A callback reactor | S | efficient | inverts the HTTP code |
| A timer heap, timer wheel, or coarse ticks | S | general | unnecessary for one connection; ticks too coarse |
| A synchronous pump: every API call runs `select` until its condition or deadline; timers are deadline fields; `select` timeout = nearest deadline | N | single-threaded, deterministic | TCP progresses only inside API calls |

**Pick:** N, using `time.monotonic()`.

### TCP-13 Send buffer, segmentation and flow control (T3, T10)
**Required:**
- segment size ≤ the effective MSS
- data in flight ≤ min(cwnd, peer window); the peer window is unscaled because no window-scale option is negotiated
- accept window updates only per the RFC 9293 SND.WL1/WL2 rule
- a zero window must not deadlock: the retransmission timer acts as the probe

| Approach | Kind | Pros | Cons |
|---|---|---|---|
| A byte buffer, cutting segments from [snd_una, snd_nxt) | S | re-segmenting is free | RTT timing needs side information |
| A segment queue with per-segment metadata | S | Karn's rule and RTT sampling are trivial | an ACK landing mid-segment needs trimming |
| The whole response pre-loaded, sliced with `memoryview` | N | simplest; zero-copy | memory grows with the response size |
| A byte buffer plus a side list of (end offset, send time, retransmitted) | N | the advantages of both | small bookkeeping |

**Pick:** byte buffer plus side list.

### TCP-14 Retransmission and RTO (T10, T12)
**Required:**
- RTO ≤ 1 s, with any backoff capped at 1 s
- retransmit lost data
- fast retransmit after 3 duplicate ACKs (needed in practice for T12 and T14)
- give up after 10 s with no ACK progress

| Approach | Kind | Pros | Cons |
|---|---|---|---|
| RFC 6298 smoothed RTT/variance plus Karn's rule, clamped to [~200 ms, 1 s] | S | standard | the minimum matters given Python jitter |
| A fixed RTO | S | trivial | spurious retransmits or slow recovery |
| On timeout, go back (snd_nxt = snd_una) | S | simple | resends data the peer already has |
| On timeout, resend the first unACKed segment and let the cumulative ACK jump | S | efficient | interacts with NewReno partial ACKs |
| Backoff doubles, capped at 1 s, reset on any new ACK | N | spec-shaped backoff | — |

**Pick:** RFC 6298 + Karn; resend the first unACKed; fast retransmit; capped backoff.

### TCP-15 Receive side, reassembly and ACK generation (T11, T12)
**Required:**
- deliver in order, exactly once
- send a cumulative ACK for every data segment, including duplicate, out-of-window and out-of-order ones
- advertise exactly 65535 on every segment
- buffer out-of-order data within the window
- process the FIN at its sequence position, after any gap is filled
- trim segments that overlap the window edges

| Approach | Kind | Pros | Cons |
|---|---|---|---|
| A dict keyed by seq | S | trivial | overlap handling; very common in public code |
| A sorted interval list with merging | S | compact | merge edge cases |
| A balanced tree of segments | S | scales well | not in the stdlib |
| A fixed 65,535-byte window buffer plus a set of filled ranges, delivering the contiguous prefix; the FIN recorded as a pending position | N | bounded; overlap-proof; FIN ordering falls out naturally | range bookkeeping |

**Pick:** N.

### TCP-16 Congestion control (T14)
**Required:** grow while there is spare capacity; back off on loss; roughly fair against kernel TCP
(curl) with one or several flows of each kind.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Tahoe | S | simplest | loses share to curl |
| Reno (RFC 5681) | S | the handout's named style | multiple losses per window → timeout |
| NewReno (RFC 6582) | S | strong under random loss | more state |
| CUBIC | S | what curl's kernel runs | complex; at small bandwidth-delay products it behaves like Reno |
| Byte counting (RFC 3465) instead of per-ACK increments | S | the curl client delays ACKs, so per-ACK growth runs at half speed | — |
| IW10 (RFC 6928) vs 2–4 (RFC 5681); initial ssthresh high | S | IW10 matches Linux | — |
| Pacing each window over one smoothed RTT | N | fewer burst losses at the bottleneck | complex; limited by Python timer granularity |

**Pick:** NewReno + byte counting + IW10; pacing only if fairness is poor.

### TCP-17 Failure semantics
**Required:** every failure (refused, reset, handshake timeout, 10 s no progress, local error) reaches
HTTP as a distinguishable outcome, mapping to exit 2 (client) or connection end (server).
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Return codes | S | simple | easy to ignore by mistake |
| A small exception hierarchy raised through the API | N | one mapping point | — |

**Pick:** N.

---

## V.6 LOG — Packet log (§2.6)

### LOG-1 Hook placement
**Required:** one line for every segment sent (including retransmissions and pure ACKs) and every segment
received and accepted (belongs to the connection, both checksums valid).
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Log calls at each send site | S | obvious | easy to miss a path |
| One transmit chokepoint (IO-2) and one accept chokepoint (after TCP-4) | N | complete by construction | — |

**Pick:** N.

### LOG-2 Field source and format
**Required:** exactly `DIR SRC_IP:SPORT > DST_IP:DPORT ttl= id= seq= ack= flags=0x.. win= len= mss=`,
with raw unsigned values, `ack` printed even without the ACK flag, `0x%02x` lowercase flags, and `mss=-`
when the option is absent.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Format from the variables used to build the packet | S | simple | could diverge from the bytes actually sent |
| SEND lines formatted by parsing back the exact bytes handed to the socket | N | log equals wire by construction | double parse |

**Pick:** N.

### LOG-3 Output and flushing
**Required:** `--log FILE` creates or truncates the file; flush after every line; no other output
in it.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| The `logging` module | S | stdlib | must strip its default formatting |
| A file opened line-buffered (`buffering=1`) | S | exact format, flushed per line | — |
| `os.open` + `os.write` per line (no Python buffering at all) | N | flush semantics are trivially true | a syscall per line |

**Pick:** line-buffered file.

### LOG-4 Scope while listening
**Required:** the SYN that creates a connection is logged as RECV; segments ignored while listening or busy
are not logged; nothing is logged after the connection ends.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| A logger owned by the connection; the listener decides acceptance before handing over | S | clear ownership | the SYN must be logged right at hand-over |
| The listener logs the SYN, then passes the same logger to the connection | N | one log stream across hand-over | — |

**Pick:** N (pairs with TCP-8).

---

## V.7 API — Byte-stream interface between TCP and HTTP

### API-1 Shape
**Required:** client open (address, port, log path) → stream; server accept (port, log path) → stream;
send; receive with a limit; close per T9; EOF and failures (TCP-17) signalled distinctly.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| A socket-like object: open/accept, send, recv(max, deadline), close | S | familiar; maps 1:1 onto the test fake | low-level |
| Callbacks | S | efficient | inverts the HTTP logic |
| A generator of chunks | S | Pythonic | awkward with timeouts |
| Socket-like plus an ambient deadline context (`with deadline(10):` applies to every call inside) | N | the server's head timeout is one line; no deadline threading through calls | must be explained |

**Pick:** socket-like (optionally with the deadline context).

### API-2 Parsing support
**Required:** HTTP must read lines, exact byte counts and until-EOF, with any bytes read past a boundary
kept for the next read.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| A buffered reader over recv (read line, read exactly N, read until EOF) | S | simple | parsing tied to I/O |
| A sans-I/O parser fed raw bytes that returns events | N | tests are pure byte strings; streaming comes free | design discipline |

**Pick:** N.

### API-3 Deadlines
**Required:** the server's 10 s head limit spans many reads; the client's overall progress is bounded by
TCP timeouts.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| A relative timeout per call | S | familiar | a slow-drip peer can extend the total indefinitely |
| An absolute monotonic deadline passed through (or ambient, per API-1) | N | spec-exact | — |

**Pick:** N.

---

## V.8 HCL — HTTP client (Part C)

### HCL-1 Command line
**Required:** `URL [-o OUTFILE] [--log LOGFILE]`, options in any position; bad usage → exit 2.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| `argparse` (its usage errors already exit with 2) | S | robust | its message format is fixed |
| A manual `sys.argv` loop | S | full control | more code |
| A small declarative option table driving a tiny parser | N | the same table serves client and server | must be written and tested |

**Pick:** `argparse`.

### HCL-2 URL parsing
**Required:**
- form `http://HOST[:PORT][/PATH]`; default port 80, default path `/`
- PATH (including query) kept exactly as written; HOST kept as written for the Host header
- no `urllib`

Edge cases (decision):
- scheme case (`HTTP://`)
- port must be digits in 1–65535; an empty port is invalid
- userinfo (`@`) and `#fragment` are invalid or taken literally
- IPv6 brackets are invalid

| Approach | Kind | Pros | Cons |
|---|---|---|---|
| One anchored regex | S | compact | widely copied; edge cases hidden |
| `partition`-based splitting | S | readable | branches |
| An explicit character scanner | N | precise errors | longer |

**Pick:** `partition`-based with table-driven tests.

### HCL-3 Name resolution
**Required:** an IPv4 literal or a hostname resolved to IPv4 (`/etc/hosts` and DNS); failure → exit 2.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| `getaddrinfo(host, None, AF_INET)` | S | standard | blocking |
| Try `inet_aton` first, resolve only if that fails | N | no resolver call for literals | — |

**Pick:** N.

### HCL-4 Request construction
**Required, byte-exact:** `GET <PATH> HTTP/1.1\r\nHost: <HOST[:PORT] as written>\r\nConnection: close\r\n\r\n`;
no Accept-Encoding; exactly one request.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| An f-string template | S | obvious | — |
| A header list joined with CRLF (extra headers become data) | N | easy to extend and test | slightly more code |

**Pick:** either, plus a byte-exact unit test.

### HCL-5 Response head
**Required:** status line `HTTP/x.y SP code SP reason` (an empty reason is allowed); the status line goes
to stderr; header names case-insensitive; a malformed or incomplete head → exit 2; repeated headers kept;
conflicting Content-Length values → exit 2.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Read until CRLFCRLF, then split | S | simple | boundary care |
| Also accept bare-LF line endings (RFC 9112 permits this for recipients) | S | robust | — |
| A sans-I/O head parser (API-2) | N | testable, streaming | discipline |

**Pick:** N with LF tolerance.

### HCL-6 Body framing
**Required:** apply the RFC 9112 §6.3 order:
1. 1xx, 204 and 304 responses have no body.
2. `Transfer-Encoding: chunked` overrides Content-Length.
3. Otherwise use Content-Length.
4. Otherwise read until the connection closes.

Chunked bodies ignore chunk extensions and trailers. EOF before completion → exit 2.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| A chunked loop (size line, data, CRLF; size 0 then trailers) | S | standard | — |
| A decoder that yields body pieces to the sink | N | streams end to end | — |
| Every mode reports completion explicitly; EOF before it → exit 2 | N | one rule for all three modes | — |

**Pick:** both N rows.

### HCL-7 Output sink
**Required:** write only the body to OUTFILE, or to stdout (binary-safe) without `-o`. If OUTFILE can't be
opened → exit 2 (decision: check before or after connecting). On exit 1 the body is still saved.
Behaviour on exit 2 with a partial body (decision).
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Buffer everything, then write | S | simple | memory |
| Stream as data arrives | S | constant memory | partial output on error |
| Temporary file plus rename on completion | N | OUTFILE is never left half-written | needs a documented decision for exit 1 vs 2 |

**Pick:** stream; document what happens to partial output.

### HCL-8 Exit-code model
**Required:** 0 = complete + 2xx; 1 = complete + other status; 2 = everything else, including invalid URL,
DNS failure, refused, timeout and incomplete body.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| `sys.exit` at each error site | S | direct | scattered |
| One top-level handler mapping exception types to codes; 0 vs 1 decided only after completion | N | auditable | — |

**Pick:** N.

### HCL-9 Close
**Required:** once the response is complete, close per T9. For close-delimited bodies, completion is the
peer's FIN.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Finish writing output, then close | S | simple | the server may retransmit its FIN meanwhile |
| Start the close as soon as the last body byte arrives, then finish writing | N | teardown overlaps disk I/O | ordering subtleties |

**Pick:** N.

---

## V.9 HSV — HTTP server (Part D)

### HSV-1 Command line and startup
**Required:** `[-p PORT] [-d DOCROOT] [--log LOGFILE]`, defaults 8080 and `./www`, with the docroot relative
to the working directory. Decide what happens if the docroot is missing (every request → 404 is
consistent with the spec).
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| `argparse` | S | robust | — |
| The shared declarative option table (HCL-1 N) | N | one parser for both programs | must be written |

**Pick:** `argparse`; resolve the docroot to an absolute path once at startup.

### HSV-2 Serve loop and robustness
**Required:** run until killed; one connection at a time; never exit because of a client, whatever it
sends or does.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| `while True` with `try/except Exception` around each connection | S | standard | must always clean up |
| Plus an overall per-connection budget | N | a stuck client can't hold the server | the budget must suit large transfers under loss |

**Pick:** S, with N if testing shows a need.

### HSV-3 Request-head reading
**Required:** read until the end of the head (CRLFCRLF, or LFLF if tolerant) within 10 s of the
connection being established; otherwise close with no response. Ignore any bytes after the head
(no request bodies). Head size limit (decision).
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| A per-read timeout | S | simple | a slow-drip client can stretch it forever |
| One absolute deadline (API-3) | N | spec-exact | — |
| A head size cap (e.g. 64 KiB → close or 400) | N | prevents memory abuse | not in the spec; document it |

**Pick:** both N rows.

### HSV-4 Request-line validation (rule 1 → 400)
**Required:** the line must be `METHOD SP TARGET SP HTTP/x.y` with single spaces and digit versions, and
TARGET must start with `/`. Header lines aren't validated (decision).
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| A regex | S | compact | single-space subtleties |
| `split(" ")` → exactly 3 parts, each checked | S | explicit | — |
| A validator that returns the parsed triple or the status to send | N | validation and parsing in one step | — |

**Pick:** split-based, as N.

### HSV-5 Method check (rule 2 → 501)
**Required:** only `GET` and `HEAD`, case-sensitive; checked after rule 1 and before rule 3.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Set membership | S | trivial | — |
| A method → handler dispatch table (HEAD = GET with the body suppressed); a missing key means 501 | N | the 501 check and HEAD consistency come from one structure | — |

**Pick:** N.

### HSV-6 Target → file (rules 3–4 → 403, 404)
**Required:**
- strip the query (from `?`)
- any path segment equal to `..` → 403
- append the path to DOCROOT
- a path ending in `/` or naming a directory → `index.html` in it
- missing → 404; no percent-decoding

Decisions:
- `..` in the query is not a path segment
- empty segments from `//`
- `.` segments
- a directory without `index.html` → 404
- an existing but unreadable file → 404 or 403

| Approach | Kind | Pros | Cons |
|---|---|---|---|
| `join` + `normpath` + `realpath` containment check | S | a common defence | adds behaviour the spec doesn't define |
| Spec-literal segment check, then join | S | matches Table 4 exactly | — |
| An index of the docroot built at startup and rescanned on a miss | N | traversal impossible by construction | stale until rescan |

**Pick:** spec-literal.

### HSV-7 Content-Type
**Required:** Table 5 by extension, case-insensitive; anything else → `application/octet-stream`.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| The `mimetypes` module | S | stdlib | its answers differ from Table 5 |
| A dict keyed by the lowercased `splitext` extension | S | exact | dotfile edge case (`.html` has no extension per `splitext`) |
| Suffix matching on the lowercased name (`endswith` per type) | N | the dotfile case is decided explicitly | ordering matters (`.jpeg`/`.jpg` are fine) |

**Pick:** dict, with the dotfile decision recorded.

### HSV-8 Response construction
**Required:**
- every response is `HTTP/1.1` with correct Content-Length, Content-Type and `Connection: close`
- error responses carry small HTML bodies with Content-Type text/html
- HEAD gets identical headers (same Content-Length) with no body

| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Format each response per request | S | simple | — |
| One header builder (status, length, type) shared by GET and HEAD; error responses pre-built at startup | N | HEAD/GET consistency guaranteed | — |

**Pick:** N.

### HSV-9 Body transmission
**Required:** send the complete file bytes after the head; files of at least 10 MB must work.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Read the whole file into memory | S | trivial | memory |
| Read and send in chunks | S | constant memory | more calls |
| `mmap` + `memoryview` passed into the TCP send buffer | N | zero-copy | empty files can't be mmapped |

**Pick:** chunks, or `mmap` with the empty-file case handled.

### HSV-10 Connection end
**Required:** after the response (or the head timeout), close per T9, then return to listening (TCP-8).
Errors mid-response end only that connection.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Close after the last send | S | simple | — |
| FIN piggybacked on the last data segment (TCP-11 N) | N | one segment fewer | explain it in the log |

**Pick:** S.

---

## V.10 APP — Program structure (cross-cutting)

### APP-1 Core layout
**Required:** a structure you can explain in full, that fits the clean-room split and keeps the
forbidden APIs out.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Layered modules (`src/rawtcp/…`, `http_*`) | S | splits cleanly | more interfaces |
| One large module | S | nothing to wire | untestable |
| A sans-I/O TCP core plus a thin I/O shell | N | testable without sockets; pcap replay | the most up-front design |

Part VI lists whole-stack architecture families. **Pick:** decided in Phase 0 using Part VI.

### APP-2 Constants and configuration
**Required:** one authoritative place for MSS, window, port range, and every timeout. This is the place
where defining comments are justified (I.3).
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| A constants module | S | simple | tests can't easily shorten timeouts |
| A frozen config object passed in (with defaults) | N | tests can inject short timeouts | more plumbing |

**Pick:** N.

### APP-3 Tracing and diagnostics
**Required:** off by default and never written into the `--log` file; enough detail for debugging and the
R6 description (cwnd, RTO, drop reasons).
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| An environment variable enabling stderr prints | S | simple | hard to plot |
| An environment variable enabling a JSON-lines trace file | N | directly plottable | a few more lines |

**Pick:** N.

### APP-4 Test seams (tests only, not shipped behaviour)
**Required:** HTTP testable without TCP; TCP testable without VMs.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Test only on the VMs | S | real conditions | slow |
| An injectable clock and raw-socket fake; an in-process lossy, reordering channel between two endpoints | N | deterministic, fast | must be written |

**Pick:** N.

### APP-5 Test hooks in shipped code
**Required:** the Step 8.2 wraparound test needs a forced ISN; the R6 plots need the trace (APP-3). Both
are inert unless an environment variable is set.
| Approach | Kind | Pros | Cons |
|---|---|---|---|
| Environment variables read at startup | S | simple | must stay harmless if set by accident |
| Hooks only through the APP-2 config object, which the launcher path never sets | N | the production path can't trigger them | tests construct the config themselves |

**Pick:** S for the ISN (needed on the VMs); N where possible.

---

## V.11 Recommended stack (summary of picks)
| Layer | Picks |
|---|---|
| NET | preflight · `addr replace` / batch · main-table routes (+`src`) · per-interface forwarding · loose on client IF_D + r2 IF_B · `set -e` + `ip route get` self-check |
| ENV | handout launcher + `-B -E -s` · dedicated iptables chain · GRO policy after probe/Q3 · root check |
| IO | one HDRINCL socket + big `SO_RCVBUF` · non-blocking transmit chokepoint · `select` + drain + `recvfrom_into` |
| IP | field-level or template · skip-zero/LFSR ID · bulk/modular checksum · validation gates · UDP source trick · kernel delivery + pinning |
| TCP | constant MSS bytes · gate validation · kind-2 scan with 536 default · 12-byte demux key · unwrapped offsets · `secrets` ISN · short-start handshake · separate listener · hybrid phases + flags · RFC 5961-lite, no outbound RST · close deadline · synchronous pump · byte buffer + side list · RFC 6298 + Karn [200 ms, 1 s] · window buffer + ranges + positional FIN · NewReno + byte counting + IW10 · exceptions |
| LOG | chokepoints · parse-back for SEND · line-buffered file · listener logs the SYN |
| API | socket-like + absolute/ambient deadlines · sans-I/O parsers |
| HCL | argparse · partition URL parser · literal-first resolution · byte-exact request · §6.3 framing order · streaming sink · single exit handler · early close |
| HSV | argparse · try/except loop · absolute head deadline + size cap · split validator · dispatch table · spec-literal path · extension dict · shared header builder · chunked/mmap body |
| APP | Part VI decision · config object · JSON-lines trace · in-process simulator · env/config hooks |

## V.12 Traceability (handout clause → items)
| Handout clause | Items |
|---|---|
| A1–A8; §1.4 script rules | NET-1 … NET-7 |
| §1.5 VM rules (static, isolated, rp_filter baseline) | VII (environment), NET-5 |
| T1 | IP-1, IP-2, IP-3 |
| T2 | TCP-1, IP-3 |
| T3 | TCP-1, TCP-3, TCP-13 |
| T4 | IP-4, TCP-2, TCP-3 |
| T5 | TCP-4, TCP-8, IP-6 |
| T6 | TCP-6 |
| T7 | TCP-7, TCP-9, TCP-12 |
| T8 | TCP-10 |
| T9 | TCP-11, TCP-9, TCP-12, HCL-9, HSV-10 |
| T10 | TCP-13, TCP-14, TCP-12 |
| T11, T12 | TCP-15, TCP-5 |
| T13 | TCP-6, HSV-1 |
| T14 | TCP-16 |
| §2.6 packet log | LOG-1 … LOG-4, HCL-1, HSV-1 |
| §2.7 not required | deliberately absent |
| Part C (usage, URL, request, framing, output, exit codes, close) | HCL-1 … HCL-9, TCP-17, API-1 … API-3 |
| Part D (usage, loop, any address, head timeout, Table 4, mapping, headers, HEAD, Table 5) | HSV-1 … HSV-10, TCP-8, IP-5, IP-6, API-3 |
| Part E | no new code (integration) |
| §6.1 language/build | APP-1, ENV-1 |
| §6.2 raw sockets + HDRINCL | IO-1, IO-2, IO-3, IP-1 |
| §6.3 not allowed | constraint on every item (`tools/check_compliance.sh`) |
| §6.4 launchers | ENV-1, ENV-2, ENV-3, ENV-4 |
| Kernel interference (implied by §6.2) | ENV-2, ENV-3, IO-1, IP-5, IP-6 |
| All timeouts and constants (T7, T9, T10, T13, Part D 10 s) | APP-2 |
| Workflow hooks and test seams (wrap test, R6 plots, offline testing) | APP-3, APP-4, APP-5 |
| Open TA items that could add code | Q2 → ENV-2/TCP-10, Q3 → ENV-3, Q5 → TCP-6/ENV-2 |

---

# Part VI — Whole-stack architecture families

This part is about the **overall shape** of the TCP implementation: which units exist, who drives whom, and
how state and time flow. Per-function choices are in Part V.

Similarity checkers (MOSS, JPlag, Dolos) compare **token sequences within one language**. So the real risk
comes from same-language code that shares *shape*: unit boundaries, method sets, call order and naming.
Using a standard *algorithm* (Reno, RFC 6298) is not a risk.

This catalogue is as complete as public knowledge allows, but it can't list every repository. The survey
(Phase 15; Step 0.4 in the two-person variant) verifies it and extends it, especially with previous-year COL334 repos.

## VI.1 Public families to avoid

| # | Family | Where it appears | Recognisable shape (avoid this shape and its vocabulary) | Risk for this assignment |
|---|---|---|---|---|
| F1 | **Flat raw-socket tutorial script** | BinaryTides-style tutorials, Stack Overflow answers, countless gists | One procedural file: build the IP header with one format string, a pseudo-header variable, a word-loop `checksum(msg)` function, send a SYN, loop over `recvfrom` | **Very high**: the most-copied Python raw-socket code in existence |
| F2 | **"Raw-socket HTTP GET" course projects** (e.g. NEU CS5700 *rawhttpget* and similar) | Hundreds of public student repos, mostly Python | A RawSocket-style class wrapping a send socket (`IPPROTO_RAW`) and a receive socket; procedural methods for handshake, send, receive and teardown; simple cwnd rules from that course's spec (start at 1, +1 per ACK, cap, reset on loss) | **Very high**: same problem, same language. *(Verify the details in the survey.)* |
| F3 | **CS144-style layered classes** (Stanford Sponge/Minnow) | Thousands of public solutions, C++ | Separate ByteStream, Reassembler, Receiver, Sender and Connection classes; time advanced through a `tick(ms)` call; the sender "fills the window" in a push method; adapters underneath | **High** (structure), though the language differs. Python ports exist |
| F4 | **Textbook RDT** (Kurose & Ross: rdt 2.x/3.0, Go-Back-N, Selective Repeat) | Most "reliable transfer over UDP" assignments | `rdt_send`/`udt_send`/`rdt_rcv`/`deliver_data` vocabulary; per-packet timers (SR); base/nextseqnum window variables; separate sender and receiver programs | **High**: students fall back on it naturally |
| F5 | **Thread-per-concern Python design** | Many student TCP/RDT projects; a typical LLM answer | A sender thread, a receiver thread and a timer thread sharing state under locks; queues between threads; `threading.Timer` per segment | **High**: and LLM-assisted code by other teams converges on it |
| F6 | **"TCPConnection god class" generated shape** | Typical LLM output for "implement TCP over raw sockets in Python" | One class with `send_syn`, `handshake`, `send_data`, `receive`, `close` methods; whole-header format strings; `while True` receive loops with `settimeout` | **High**: other teams may submit exactly this |
| F7 | **BSD monolithic TCB** (4.4BSD/FreeBSD; Stevens Vol. 2) | BSD descendants, many teaching stacks | One control block; a giant input routine with header prediction; a single output routine that decides what to send from state; fast/slow tick timers; mbuf chains | Medium (C), but its shape is widely imitated |
| F8 | **Linux stack shape** | Linux kernel, and ports that mimic it | A socket-buffer write queue / retransmit queue / out-of-order tree; pluggable congestion-ops struct; split slow-path and fast-path receive routines; per-type timers | Medium (C); imitations exist |
| F9 | **lwIP / uIP / picoTCP embedded shapes** | Embedded stacks and their tutorials | lwIP: PCB lists, input → process → receive chain, a callback "raw API". uIP: one global buffer, a connection array, an application callback, no retransmit buffer (the app regenerates data). picoTCP: protocol modules with in/out frame queues | Medium (C) |
| F10 | **TAP/TUN user-space stacks** (level-ip, PyTCP and similar) | Hobby stacks, blog series | A full stack from Ethernet up over TAP; per-protocol parser/assembler class pairs; a packet-handler dispatcher; stack threads | Medium; PyTCP is Python |
| F11 | **Poll-driven interface stacks** (smoltcp, Rust) | Rust/embedded | An interface `poll(timestamp)` loop over a socket set; ring buffers; time passed in explicitly | Low (different language), but conceptually close to a sans-I/O design |
| F12 | **Goroutine-per-endpoint stacks** (gVisor netstack and others) | Go | A protocol main-loop goroutine per endpoint; separate sender and receiver types; segment queues | Low (Go) |
| F13 | **Simulator stacks** (ns-3 TcpSocketBase + congestion-ops) | Networking research | A socket-base class with overridable congestion ops; event scheduler | Low (C++), but CC code shapes get copied |
| F14 | **Transport/Protocol callback pairs** (Twisted/asyncio style) | Python networking code | `connection_made`/`data_received`/`connection_lost` callbacks; transport objects | Low to medium; asyncio itself is forbidden, but the pattern gets imitated |
| F15 | **Previous offerings of this course** | Public repos named after COL334 assignments | Unknown until surveyed | **Potentially the highest**: graders may include them in the checker corpus |

What to avoid in practice is the combination of unit boundaries, method set and names from any single
row. Having a sender and a receiver is fine. Having CS144's exact five classes, with its method names and
a tick-driven API, is not.

## VI.2 Alternative whole-stack architectures

| # | Architecture | Core idea | Pros | Cons | Fit |
|---|---|---|---|---|---|
| X1 | **Sans-I/O core + thin driver** | Pure TCP logic objects take events (bytes in, time now, app request) and return actions (bytes out, data delivered, deadline wanted). A small driver owns the socket, the clock and `select` | Fully unit-testable without sockets; deterministic replay of pcaps; easy to explain | More up-front interface design; conceptually close to F11, but that's a different language | **High** |
| X2 | **Half-connection pair** | Two independent objects, one per direction: an outbound stream (send buffer, RTO, cwnd, our FIN) and an inbound stream (reassembly, rcv_nxt, peer FIN), coupled only by a segment composer that piggybacks ACKs | Mirrors TCP's full-duplex nature; teardown becomes two independent "FIN done" facts; splits work cleanly | Coordination of handshake and RST needs a thin owner | **High** (combines well with X1) |
| X3 | **Byte-range ledger** | All connection state is interval sets over unwrapped sequence space: sent, acknowledged, received, delivered. Every operation is set arithmetic (in-flight = sent − acked; deliverable = contiguous received prefix) | Very little special-case code; wraparound-free with Part V TCP-5; distinctive | Interval-set utility must be solid; performance needs care in Python | Medium–high |
| X4 | **Pipeline of stages** | Inbound: decode → validate → demux → classify → act. Outbound: compose → encode → log → transmit. Each stage is a small function returning a verdict or a transformed record | Matches the validation gates and logging chokepoints in Part V; each stage is testable | Cross-stage state needs explicit passing | **High** for the packet path, combined with X1 or X2 |
| X5 | **Reducer / event-sourced state** | `state' = step(state, event)` with immutable records; side effects returned as a list; state history kept for debugging | Deterministic; time-travel debugging; trivially testable | Copying cost in Python (fine at these rates); unfamiliar style | Medium |
| X6 | **Declarative transition table + tiny engine** | Connection behaviour as data: (phase, segment class) → action list, interpreted by a small engine | Behaviour is reviewable at a glance; distinctive | Actions still need code; tables can hide subtle ordering | Medium (good for establishment and teardown only) |
| X7 | **Generator-based protocol tasks** | Handshake, transfer and teardown written as plain generators that `yield` waits ("segment matching X or deadline T") to a hand-written scheduler (no asyncio) | Sequential, readable code for timer-heavy phases; matches T7/T9 wording | Generator plumbing must be explained; mixing with the data path needs care | Medium–high |
| X8 | **Single-process actor model** | Components (wire, sender, receiver, clock, application) exchange messages through mailboxes; one deterministic scheduler, no threads | Clear boundaries; deterministic | Message boilerplate | Medium |

### Suggested combinations (C-1 adopted 2026-10-10; see SPEC.md)
- **C-1 (balanced):** X1 sans-I/O core + X2 half-connections + X4 pipelines for the packet path. Testable,
  distinctive, and maps onto the A/B split.
- **C-2 (most distinctive):** X1 + X3 ledger + X7 generators for establishment and teardown.
- **C-3 (conservative but still different from F1–F6):** X4 pipelines + X2 half-connections around a
  synchronous pump driver (Part V TCP-12), without a strict sans-I/O boundary.

All three are compatible with the Part V picks. They differ in how much up-front design they need and how
much you'll need to explain in the viva.

---

# Part VII — Tools, software and environments

> Reference only. The ordered, per-machine procedure is **`setup.md`**; where they differ, `setup.md` wins.

## VII.1 Is a VM required?
**Yes, four Ubuntu VMs are mandatory.** The reasons:
- Part A is graded as configuration of four machines on isolated internal networks.
- Report items R1–R6 require screenshots **taken on your four VMs, "not in a simulated network"**.
- The grader runs Ubuntu 22.04 x86-64 with Python 3.10 / gcc 11. Final testing must match that.

**What doesn't need the VMs:**
- unit tests (any OS, ideally Python 3.10)
- the whole TCP core, in the simulation harness (Phase 6)
- HTTP logic against the fake stream (Phases 7 and 9)
- day-to-day TCP debugging in the optional **netns sandbox** (VII.5), which reproduces the exact
  topology with Linux network namespaces in seconds

The netns sandbox is a development convenience only. Every milestone is re-verified on the VMs, and every
screenshot comes from the VMs.

## VII.2 Host software (your laptop)
| Tool | Needed for | Required? | Ubuntu/Debian | macOS | Windows |
|---|---|---|---|---|---|
| Hypervisor | the 4 VMs | **yes** | `sudo apt install virtualbox` (or Oracle's 7.x package) | `brew install --cask virtualbox` (7.1+ runs on Apple Silicon) | `winget install Oracle.VirtualBox` |
| Ubuntu 22.04 live-server ISO | VM OS | **yes** | amd64 image from releases.ubuntu.com/22.04 | Apple Silicon: arm64 image from cdimage.ubuntu.com (grader is x86-64; see VII.4) | amd64 image |
| Git (+ private remote) | version control | **yes** | `apt install git` | `brew install git` | `winget install Git.Git` |
| Python 3.10 | host-side unit tests at grader version | **yes** | native on 22.04; else deadsnakes `python3.10 python3.10-venv`, or pyenv | conda env `a3` (`conda create -n a3 python=3.10`); brew python@3.10 fails on macOS 14 | inside WSL2 (below), or `winget install Python.Python.3.10` |
| zip / unzip | `tools/package.sh` | **yes** | `apt install zip unzip` | preinstalled | inside WSL2 |
| Bash environment | all `tools/` scripts | **yes** | native | native (bash 3.2 is enough for most scripts; `brew install bash` for `package.sh`) | **WSL2 Ubuntu 22.04** (`wsl --install -d Ubuntu-22.04`) |
| Wireshark | reading captures (R6, debugging) | recommended | `apt install wireshark` | `brew install --cask wireshark` | `winget install WiresharkFoundation.Wireshark` |
| Editor | coding | recommended | VS Code + extensions in `.vscode/extensions.json` | same | same |
| ruff (dev venv) | lint/format to one house style | recommended | installed by `tools/host/setup-dev.sh` | same | same (in WSL2) |
| pandoc (+ a PDF engine) | `report.md` → `report.pdf` | optional (a word processor works too) | `apt install pandoc texlive-xetex` | `brew install pandoc` + `brew install --cask basictex` | `winget install JohnMacFarlane.Pandoc` |
| Node.js LTS + Dolos | originality audit (Phase 15) | needed in Phase 15 | nvm or NodeSource, then `npm i -g @dodona/dolos` | `brew install node` | `winget install OpenJS.NodeJS.LTS` |
| JDK + JPlag jar | originality audit (Phase 15) | needed in Phase 15 | `apt install openjdk-21-jdk`; jar from JPlag's GitHub releases (check its minimum Java version) | `brew install --cask temurin` | `winget install EclipseAdoptium.Temurin.21.JDK` |
| netns sandbox tools | VII.5 (Linux/WSL2 only) | optional | `apt install iproute2 iptables tcpdump traceroute curl wget netcat-openbsd` | n/a (use a Linux VM) | inside WSL2; `tc netem` may be missing from WSL2's kernel |

**Windows note:** VirtualBox 7 can run alongside WSL2/Hyper-V, but more slowly. If VMs crawl, see
VirtualBox's Hyper-V notes. VMware Workstation is an alternative hypervisor with "LAN segments" as
internal networks.

Check the host with `bash tools/host/check-host.sh`. It prints OK, MISSING or optional with install hints.

## VII.3 Software inside the VMs
Installed on the base VM by `tools/vm/install-packages.sh --vbox` while NAT is attached:
| Package | Used for |
|---|---|
| iproute2 (`ip`, `tc`), procps (`sysctl`) | netcfg scripts, netem/tbf impairment (preinstalled) |
| python3 (3.10 on 22.04) | running the submission |
| build-essential (gcc 11) | only if you choose C/C++ |
| iptables | launcher RST suppression (ENV-2) |
| ethtool | GRO probe (ENV-3) |
| tcpdump, tshark | captures (R6, debugging) |
| traceroute, iputils-ping | Part A verification, R2 |
| curl, wget | reference clients (R4, R5, fairness) |
| netcat-openbsd | raw requests in `server-edge.sh` |
| virtualbox-guest-utils | the `/mnt/a3` shared folder (VirtualBox on Intel hosts only; Apple Silicon uses the transfer image) |

## VII.4 Creating the VMs
### VirtualBox (Windows, Linux, Intel Mac): scripted
1. HOST: `bash tools/vm/vbox-create-base.sh ~/Downloads/ubuntu-22.04.*-live-server-amd64.iso`
   creates `a3-base`: 1 vCPU, 1 GB, 10 GB disk, NAT adapter (e1000), ISO attached, shared folder `a3`
   pointing at this repo and auto-mounted at `/mnt/a3`.
2. `VBoxManage startvm a3-base` and install Ubuntu Server with these choices:
   - default "Ubuntu Server" (not minimized)
   - DHCP on the NAT NIC, no proxy
   - use the entire disk
   - create your user
   - **skip OpenSSH and all snaps**
   Reboot when done.
3. In `a3-base`: `sudo bash /mnt/a3/tools/vm/install-packages.sh --vbox`, then
   `sudo usermod -aG vboxsf $USER`, then reboot and check `ls /mnt/a3`.
4. In `a3-base`: `sudo bash /mnt/a3/tools/vm/seal-base.sh`, then `sudo poweroff`.
5. HOST: `bash tools/vm/vbox-clone-topology.sh create` makes the 4 linked clones `a3-client`, `a3-r1`,
   `a3-r2`, `a3-server`. They get new MACs, internal networks LAN_A/LAN_B/LAN_C/LINK_D per the topology,
   no NAT, and the shared folder. The script warns if any DHCP server is attached to those networks.
6. Boot each clone and run `sudo hostnamectl set-hostname <client|r1|r2|server>`.
   Fill `docs/vm-map.md` using `bash tools/vm/vbox-clone-topology.sh map` (adapter MAC → network) and
   `ip -br link` inside each VM. Confirm the fresh-boot state, then power off.
7. HOST: `bash tools/vm/vbox-clone-topology.sh snapshot fresh`. Later:
   `… restore fresh` (fresh-boot tests) and `… snapshot netcfg-ok`.

### Apple Silicon Macs (this team's host): VirtualBox 7.1+, adopted 2026-10-10
The authoritative step list is `setup.md` S4–S7. Differences from the Intel path above:
- Create `a3-base` in the VirtualBox GUI (type *Ubuntu (64-bit ARM)*, skip unattended installation);
  `vbox-create-base.sh` refuses to run on Arm hosts on purpose.
- **No shared folders.** Ubuntu 22.04's Arm kernel lacks the VirtualBox guest driver (it reached mainline
  Linux only in 2025), so the repo reaches the VMs as a read-only CD image:
  `tools/host/make-transfer-iso.sh` builds `~/A3-VMs/a3-transfer.iso` and
  `tools/vm/vbox-clone-topology.sh transfer` inserts it into all four VMs, mounted at `/mnt/a3`.
  `/mnt/a3` is read-only: write logs, captures and downloads to `~` or `/tmp` inside the VMs.
- `vbox-clone-topology.sh create` reuses the base VM's adapter type (shown as *Adapter Type* in
  Settings → Network → Advanced), so it works whichever types the Arm build offers.
- Results go back to the Mac as screenshots or pasted text (the transfer image is one-way by design: it
  never connects the VMs to the host).
- arm64 VMs are allowed for development (handout §1.5 names Apple Silicon hosts); the grader runs
  x86-64 (§6.1), so a final dry run on x86-64 is still worthwhile (Part II-B, O1).

The Fusion and UTM notes below are kept for reference only.

### VMware Workstation/Fusion
Same steps as UTM, using "LAN segments" (Workstation) or custom private networks (Fusion) as the four
internal networks.

## VII.5 netns sandbox (optional, Linux or WSL2 host)
`sudo bash tools/netns/a3-topology.sh up` creates namespaces `a3-client`, `a3-r1`, `a3-r2` and
`a3-server`, joined by veth pairs named `ethA`/`ethB`/`ethC`/`ethD`. Every interface starts DOWN with no
addresses and rp_filter=1, the same as a fresh VM.

- `… configure` runs your real `netcfg/*.sh` in each namespace.
- `… exec client bash` gives a shell "on" the client, where you can use `client/run-client`, tcpdump,
  netem, and so on.
- `… status` shows addresses and routes.
- `… down` removes everything.

**Limitations:**
- veth doesn't do GRO by default, so G3 can't be reproduced here; probe it on the VMs.
- The kernel version differs from 22.04's.
- WSL2 kernels may lack `sch_netem`.

## VII.6 Repository dev setup (done once per machine)
`bash tools/host/setup-dev.sh` does the following:
- creates `.venv` with Python 3.10, or warns and falls back to your Python
- installs ruff from `tools/host/requirements-dev.txt`
- creates the gitignored working directories
- fixes executable bits
- points git at `tools/git-hooks/` and sets `autocrlf=input`
- runs `check-host.sh`

From then on, every commit runs the **pre-commit hook**: `check_compliance.sh`, then ruff on `src/` and
`tests/`, then the unit tests against `reference/src`. A failing commit is refused. Once your own `src/`
is far enough along to import (submission pass), turn on testing it too with
`git config a3.testsrc true` (or run `bash tools/test/run-unit.sh` by hand at any time).

**Repository config files:**
- `.gitattributes`: forces LF, including in the launchers.
- `.editorconfig` and `.vscode/settings.json`: one house style; the editor hides and search-excludes
  `refcorpus/` to support the clean room.
- `.python-version`: `3.10`, for pyenv.
