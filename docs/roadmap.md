# Roadmap to submission and design rationale (audit of 2026-10-12)

## 1. Audit result

| Area | State | Evidence |
|---|---|---|
| Handout hidden text | none | all 12,547 glyphs black, sizes 8–17 pt, none off-page; no zero-width characters; only internal link annotations |
| Comments / docstrings in `reference/` | 0 | Python tokenizer + AST scan of every file; `#` scan of netcfg scripts and launchers |
| Stray words (LLM, TODO, hidden, canary, …) | 0 | case-insensitive grep of `reference/` |
| Banned vocabulary (SPEC §1.6) | 0 | 460 identifiers listed and checked; `base` renamed on 2026-10-12 |
| Forbidden APIs (handout §6) | 0 | imports are sys, os, time, socket, select, random, errno, argparse, json, collections, dataclasses, enum, typing, bisect |
| `IP_HDRINCL` | set explicitly | `driver/wire.py` |
| Byte order | explicit big-endian everywhere | `to_bytes`/`from_bytes(…, "big")`; nothing depends on arm64 vs x86-64 |
| Python 3.10 | 47/47 tests pass on 3.10.20; every file parses as 3.10 | |
| Sandbox end-to-end | MATCH for 6.5 KB, 1 MB, 10 MB, 1 MB at 5 % loss; 404 → 1; refused → 2; server-edge 17/17 | 4 network namespaces |
| VMs | Setup done; Phase 2 PASS (M1); Phase 3 paused at Step B | `docs/evidence/phase2-netcfg/`, `report/screenshots/R1–R3` |
| `src/` (your submission) | empty | |
| TA questions | none sent | `docs/ta-questions.md` |

Open issue: Phase 3 Step B — `curl` from client to `python3 -m http.server` on the server is refused
in 0 ms although the server listens on 0.0.0.0:8000. Not reproducible in the sandbox. Diagnose first
(server-side `tcpdump`, client `iptables -S`, `curl -v`).

## 2. Remaining phases

Hours are for one person. Track A validates the reference design on your VMs and collects all report
evidence; Track B is the code you submit; Track C finishes. Do the admin items now.

### Admin (now, 15 min)
- Send `docs/ta-questions.md` — **Q10 first** (solo allowed? zip name `A3_<entry>.zip`?). Q9 is partly
  answered by the handout (later Ubuntu releases allowed; no language features newer than 3.10).
- Confirm the submission deadline and the viva slot; write both into log.txt section 0.

### Track A — reference on the VMs (7–9 h)
| Phase | Tasks | Evidence | Est. |
|---|---|---|---|
| 3 Launch (resume) | fix the curl refusal; Steps A–F: md5 baseline, kernel RST without launcher, handshake with launcher, iptables chains, GRO probe → ENV-3 decision | `docs/evidence/phase3-launch/` (8 shots) | 1–1.5 h |
| 8 Driver | full connection + close; Refused (closed port, exit 2); HandshakeTimeout (unreachable); 3 s of 100 % loss mid-transfer then recovery; `check_log.py` 0 problems | `phase8-driver/` | 1 h |
| 10 Integration | rebuild + transfer image; `md5check.sh` against `python3 -m http.server` (HTML + ≥100 KB) and our server; `chunked-server.py` cases; curl, wget, our client from our server; `server-edge.sh` | `phase10-integration/`, **R4, R5** | 1.5 h |
| 11 Congestion | `netem.sh enp0s10 bottleneck 20mbit 10ms` on r2; 10M.bin with `A3_TRACE`; slow start → fast recovery → sawtooth | `phase11-congestion/`, R6 | 1 h |
| 12 Robustness | loss 5/10 % and reordering on r1 `enp0s9` and r2 `enp0s10`; forced ISN wrap; GRO on/off; `tcpdump -nn` of one full connection, a retransmission, out-of-order buffering; clear qdiscs | `phase12-robustness/`, **R6**, `test-results.md` | 1.5 h |
| 13 Part E | interop matrix; `fairness.sh` 1v1 and 3v3 against curl (ratio 0.6–1.6) | `phase13-fairness/` | 1 h |

### Track B — your own `src/` (45–70 h)
Write from SPEC.md, not by copying `reference/`. After each phase: unit/harness tests green,
`check_compliance.sh` clean (it also flags ≥ 0.60 similarity to `reference/`), commit.
| Phase | Tasks | Est. |
|---|---|---|
| 0.5–0.6 | freeze contracts C1–C7 (rename anything, record in SPEC §16); README team/language/build | 1 h |
| 2 | your `netcfg/*.sh` (NET-1…7); fresh-boot test from `fresh`; tag `m1` | 3–4 h |
| 3 | your launchers (ENV-1/2, ENV-3 per the probe) | 1–2 h |
| 4 | settings, records, vocab, checksum, sequence space, IPv4/TCP codecs, ingress gates, log line | 6–8 h |
| 5 | HTTP parsers (fake stream and harness already exist in `tests/`) | 4–6 h |
| 6 | inbound half, RTO, outbound half, coordinator, listener; harness campaign; tag `m2` | 10–14 h |
| 7 | HTTP client (HCL-1…9) against the fake stream | 5–7 h |
| 8 | driver: wire, addressing + UDP helper, journal, trace, pump, stream; VM acceptance; tag `m3` | 6–9 h |
| 9 | HTTP server (HSV-1…10) against the fake stream | 5–8 h |
| 10–13 | rerun Track A with `src/` (now `client/run-client`, `server/run-server`); tags `m4`–`m6` | 4–6 h |

### Track C — finish (15–25 h)
| Phase | Tasks | Est. |
|---|---|---|
| 14 Regression | `tools/test/run-all.sh`; fill unit gaps (per-event congestion, RTO, listener); full regression from `netcfg-ok` | 3–4 h |
| 15 Originality | build `refcorpus/`; Dolos + JPlag (`setup.md` S8); triage in `docs/clean-room/audit-log.md`; rewrite avoidable matches from the SPEC; also compare `src/` with `reference/` | 5–9 h |
| 16 Report + package | R1–R6 text in your own words; `report.pdf`; README with no TODOs (launcher behaviour, partial-output note); `tools/package.sh`; grader dry run from `fresh` with only the zip; upload; re-download and compare checksums; tag `m7` | 5–8 h |
| 17 Viva | explain every SPEC item from the code; re-derive checksum and r2 routing on paper; demo rehearsal; `docs/viva-prep.md` | 3–4 h |

**Total remaining:** about 70–105 h (Track A 7–9, Track B 45–70, Track C 15–25).

## 3. Decisions and why they hold

### Environment
| Decision | Why it is solid | Rejected alternative |
|---|---|---|
| VirtualBox 7.2, Intel 82540EM (e1000) NICs, internal networks LAN_A/B/C + LINK_D | Handout §1.5 names VirtualBox; internal networks have no DHCP and no host link, exactly what §1.5 requires; e1000 is VirtualBox's default and well supported by Linux | VMware Fusion (login wall); UTM (no simple isolated multi-VM networks) |
| Ubuntu Server 24.04.5 arm64 for development | 22.04 arm64 doesn't boot in VirtualBox on Apple Silicon (known black-screen issue); handout allows "a later release"; the code uses only stdlib + iproute2 + iptables, which behave the same | Desktop image (too large), keep fighting 22.04 |
| Python 3.10 checks on the Mac (conda `a3`) | Grader runs 3.10; the VMs have 3.12, which accepts newer syntax — the pre-commit hook catches that | trusting the VMs' Python |
| Linked clones from one sealed base + snapshots `fresh`, `netcfg-ok` | Identical machines, seconds to reset; `fresh` reproduces the grader's start state (rp_filter 1, no addresses) | four separate installs |
| Code reaches VMs on a read-only Rock Ridge CD image (xorriso) | Keeps the internal networks isolated (no shared folder, no host network), keeps names and execute bits | shared folders (no Arm guest additions), a NAT adapter (breaks isolation) |

### Part A — network
| Decision | Why it is solid |
|---|---|
| Client: default route via r1 | Normal host configuration; requests go A → r1 → B → r2 → C, matching the handout's asymmetric design |
| r2: `10.10.1.0/24 via r1` **plus** `10.10.1.10/32 via LINK_D` | Longest-prefix match sends only traffic for the client over Link D; r1 itself stays reachable over LAN_B. Verified: traceroutes 10.10.1.1 → 10.10.4.1 → 10.10.3.10 and 10.10.3.1 → 10.10.1.10; TTL 63/62 |
| rp_filter = 2 only on client `enp0s9` (Link D) and r2 `enp0s8` (LAN_B); 1 elsewhere | These are exactly the two interfaces where packets arrive on an interface that isn't the route back to their source (asymmetry). Strict mode would drop them; loose mode still requires the source to be routable. Minimal change from the required baseline of 1 |
| Per-interface `conf.<if>.forwarding=1` on routers only | Forwarding is enabled only where needed; hosts never forward |
| Idempotent scripts (`ip addr replace`, `ip route replace`) with a built-in route self-check | Safe to rerun; fails loudly if a route is wrong |

### Part B — TCP
| Decision | Why it is solid |
|---|---|
| Architecture C-1: a sans-I/O core (pure state machines) + thin driver | The whole TCP logic is tested deterministically in an in-process simulator with loss, reordering, duplication and corruption before any socket exists; VM bugs are then limited to the thin driver. Easy to explain in a viva: inputs (segments, time) → outputs (segments to send, events) |
| Half-connections (inbound half, outbound half, coordinator) | Sending and receiving rules are independent in RFC 9293; splitting them keeps each small and testable |
| One raw `SOCK_RAW/IPPROTO_TCP` socket with explicit `IP_HDRINCL` | Mandatory per handout; one socket for both directions keeps the event loop simple |
| Single-threaded pump (select loop driven by API calls, timers as deadlines) | No threads, no races, deterministic; the next `select` timeout is simply the nearest deadline |
| Kernel RST suppression by iptables in the launchers (chains A3C/A3S, scoped to our ports) | The kernel doesn't know our connections and would reset them; the rule is narrow (only RSTs from our ports), idempotent, and lives where the handout allows setup (launchers) |
| UDP helper socket to pick the source address and reserve the port | The kernel chooses the correct source IP for the route and keeps the port from being reused by others; no TCP `connect()` (forbidden) |
| Unwrapped sequence numbers inside the core | Wraparound handled once at the boundary; core comparisons are plain integers (tested with a forced ISN near 2³²) |
| RTO per RFC 6298 + Karn, clamped to [0.2, 1] s | The standard estimator; the 1 s ceiling matches the handout's timing limits; Karn avoids samples from retransmissions |
| NewReno (RFC 5681 + 6582) + byte counting (RFC 3465) + initial window 10 (RFC 6928) | Standard, widely deployed congestion control; byte counting avoids ACK-division tricks; gives the textbook slow-start/sawtooth trace R6 asks for; fair against Linux's TCP in the 3v3 test |
| Handshake retries at 0.25, 0.5, then 1 s | Fast connection under loss while never exceeding the handout's 1 s limit |
| Log lines written in exactly one SEND and one RECV place | Every packet is logged once and in order; checked automatically by `check_log.py` |

### Parts C/D — HTTP
| Decision | Why it is solid |
|---|---|
| Byte-level incremental parsers (no `http.*`, no `urllib`) | Required by the handout; incremental parsing handles headers split across segments |
| Client: Content-Length, chunked, and close-delimited bodies; exit 0 only for 2xx | Covers every framing a real server can use; tested against `chunked-server.py` |
| Server: status rules 400 → 501 → 403 → 404 in that order; 10 s head timeout; never exits on a bad request | Matches the handout's rule order; `server-edge.sh` 17/17 |

## 4. Known risks
- **Solo submission** not confirmed (TA Q10).
- **Grader is x86-64 Ubuntu 22.04**: covered by stdlib-only code, explicit byte order and Python 3.10 checks, but run the Phase 16 dry run carefully.
- **Submitting `reference/`** would break handout §10 ("directly copy-pasting code from AI tools … is prohibited"); Track B exists for that reason.
