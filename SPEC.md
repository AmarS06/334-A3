# COL334 A3 — Design Specification (architecture C-1)

**Status:** v1.0, adopted 2026-10-10. Contracts in §2 are *proposed* until you freeze them at Step 0.5.
**Precedence:** `docs/handout.pdf` > this file > `instructions.md` Part V (option catalogue and rationale).
**Not submitted.** Names of units, records and functions below are proposals. Rename them at Step 0.5 if you
like, but keep the shapes and record the final names in §16.

How to use this file:
- Sections §3–§13 follow the workflow order in `instructions.md` Part II. Each item names its workflow
  step, so "what am I building now?" is always one lookup.
- Every item has the same parts: **Unit** (file), **Behaviour** (what it must do),
  **Locked** (decisions already made; changing one needs a §16 entry first),
  **Acceptance** (how it is proven done).
- Item IDs (NET-1, TCP-15, …) are the same as in `instructions.md` Part V, where the alternatives and
  their trade-offs are recorded.

---

## §1 Architecture C-1

C-1 combines three ideas from `instructions.md` Part VI.2:
- **X1 Sans-I/O core.** TCP logic never touches a socket or a clock. It consumes events and returns
  actions.
- **X2 Half-connection pair.** The core's state is split into an *outbound half* (everything about the
  bytes we send) and an *inbound half* (everything about the bytes we receive), plus a small *coordinator*
  that owns phases, handshake, RST and teardown.
- **X4 Pipelines.** Packets move through ordered, pure stages: *ingress* (bytes → validated record) and
  *egress* (segment intent → bytes). Every stage either passes a value on or returns a named drop reason.

A thin **driver** is the only part that performs I/O: the raw socket, the monotonic clock, `select`,
the log file and the trace file.

### §1.1 Unit map

```
                 HTTP layer (web/)  ── uses only the Stream API (C4)
                        │  put / take / finish / drop
 ┌──────────────────────▼───────────────────────────────────────────────┐
 │ DRIVER (driver/)   stream.py · pump.py · wire.py · journal.py · addressing.py
 │   owns: raw socket, clock, select loop, log file, trace file         │
 │   feeds events ▼                         ▲ executes actions          │
 │ ┌──────────────────────────── CORE (core/) ── pure, no I/O ────────┐ │
 │ │ listener.py  (server only: admits SYNs, one connection at a time)│ │
 │ │ endpoint.py  COORDINATOR: phase, handshake, RST, teardown,       │ │
 │ │              per-segment processing order, ACK composition       │ │
 │ │   ├── outbound.py  OUTBOUND HALF: send buffer, retransmission,   │ │
 │ │   │                window, our FIN  ── rto.py, congestion.py     │ │
 │ │   └── inbound.py   INBOUND HALF: window buffer, reassembly,      │ │
 │ │                    in-order delivery, peer FIN                   │ │
 │ └──────────────────────────────────────────────────────────────────┘ │
 │ PIPELINES (packets/) ── pure functions + tiny state (ID generator)   │
 │   ingress.py: shape → demux → fragment/proto → IP csum → TCP len →   │
 │               TCP csum → decode+options → InboundRecord              │
 │   egress.py:  intent → wrap seq → TCP encode → IP encode → bytes     │
 │   ipv4.py · tcpwire.py · checksum.py · seqspace.py · logline.py      │
 └──────────────────────────────────────────────────────────────────────┘
```

### §1.2 Control flow and time
- The HTTP code calls a Stream method. The method runs the **pump** until its condition holds or its
  deadline passes. TCP advances only while some Stream method is running. That is enough, because both
  HTTP programs are strictly sequential.
- The pump computes `wake = min(core's next deadline, caller's deadline)`, waits in `select` on the raw
  socket until `wake`, reads `now` from `time.monotonic()`, then feeds the core:
  1. every accepted inbound record, as an *Arrival* event;
  2. one *Clock* event carrying `now`.

  It then executes the returned actions in order.
- The core receives time **only** through events. It never calls the clock. Tests can therefore drive it
  with a virtual clock.

### §1.3 Packet journeys
- **Inbound:** the socket's bytes go through the ingress stages. A drop reason ends the journey (counted
  in the trace, never logged). An accepted record is logged as **RECV** (LOG-1), then delivered to the
  listener (while listening) or to the endpoint.
- **Outbound:** an *Emit* action goes through the egress stages to bytes. Those bytes are decoded again
  and logged as **SEND** (parse-back, LOG-2), then handed to the socket.

### §1.4 File layout
```
src/
├── http_client.py     entry for client/run-client (HCL-1, ENV-4, APP-5)
├── http_server.py     entry for server/run-server (HSV-1, ENV-4, APP-5)
├── settings.py        C1 Settings (APP-2)
├── packets/           pipelines
│   ├── __init__.py  records.py  checksum.py  seqspace.py
│   ├── ipv4.py  tcpwire.py  ingress.py  egress.py  logline.py
├── core/              sans-I/O core
│   ├── __init__.py  vocab.py  inbound.py  outbound.py  rto.py
│   ├── congestion.py  endpoint.py  listener.py
├── driver/            I/O shell
│   ├── __init__.py  wire.py  addressing.py  journal.py  pump.py  stream.py
└── web/               HTTP
    ├── __init__.py  parsing.py  urlparts.py  fetch.py  serve.py  content.py
tests/                 not submitted: unit/, fakes.py (C4 fake), harness/ (APP-4 simulator)
```
Never name a package `http`, `select`, `socket`, `queue` or any other stdlib module. The `src/`
directory is first on `sys.path`, so such a package would shadow the stdlib.

### §1.5 Invariants (checked in reviews and by `tools/check_compliance.sh`)
- **I1** Only `driver/` imports `socket`, `select` or `time`, or opens files for the log or trace.
  `web/` opens docroot and output files only.
- **I2** `core/` and `packets/` are deterministic: same inputs, same outputs. Randomness (ISN, port, IP ID
  seed) is injected by the driver.
- **I3** Exactly one place emits SEND lines and exactly one emits RECV lines (LOG-1).
- **I4** No function or method is named `connect`, `listen`, `accept`, `send` or `recv`. These would
  trip forbidden-API greps (§6.3). The one permitted `connect` is on the UDP helper socket (TCP-6).
- **I5** Sequence numbers are unwrapped integers everywhere except inside `packets/seqspace.py` and the
  codecs (TCP-5).
- **I6** No comments except essential definitions (instructions.md I.3). The module list above is the
  documentation of structure.
- **I7** Nothing writes to stdout except the HTTP client's body output.

### §1.6 Naming rules (clean room)
Do not use the vocabulary of the public families in instructions.md VI.1. In particular:
- **F3 (CS144-style):** `ByteStream`, `Reassembler`, `TCPSender`, `TCPReceiver`, `TCPConnection`, `tick`
- **F4 (textbook RDT):** `rdt_send`, `udt_send`, `deliver_data`, `nextseqnum`, `base`
- **F2 / F6 (course projects and generated code):** a `RawSocket` class, `send_syn`, `handshake`,
  `three_way_handshake`
- **F1 (tutorials):** a function called `checksum(msg)` with a loop over word pairs

Add names found in the Phase 15 audit to `docs/clean-room/avoid.md`.

---

## §2 Contracts (freeze at Step 0.5)

### C1 Settings (`settings.py`, APP-2)
An immutable record of every constant. Entry points build it with defaults; tests build it with
overrides.

| Field | Default | Source |
|---|---|---|
| `local_mss` | 1460 | T3 |
| `default_peer_mss` | 536 | RFC 9293 §3.7.1 (TCP-3) |
| `advertised_window` | 65535 | T11 |
| `ttl` | 64 | G11 |
| `client_port_low`, `client_port_high` | 61000, 65535 | T13 |
| `handshake_retry_gaps` | 0.25, 0.5, then 1.0 repeated | T7 (≤1 s) |
| `handshake_give_up` | 7.0 s after the first SYN/SYN-ACK | T7 (≥6 s) |
| `rto_initial`, `rto_min`, `rto_max` | 1.0, 0.2, 1.0 s | T10 |
| `stall_limit` | 10.0 s | T10 |
| `close_limit` | 2.0 s | T9 |
| `idle_limit` | 10.0 s (client waiting for data) | Part C "timeout" |
| `head_limit` | 10.0 s | Part D |
| `head_cap` | 65536 bytes | HSV-3 |
| `initial_cwnd_segments` | 10 | RFC 6928 (TCP-16) |
| `dupack_threshold` | 3 | RFC 5681 |
| `abc_limit_segments` | 2 | RFC 3465 |
| `send_buffer_cap` | 262144 bytes | TCP-13 |
| `socket_rcvbuf` | 4194304 bytes | IO-1 |
| `forced_isn` | None | APP-5 |
| `trace_path` | None | APP-3 |

### C2 Segment records (`packets/records.py`)
- **InboundRecord:** src_ip, dst_ip, src_port, dst_port, ttl, ip_id, seq (raw 32-bit), ack (raw 32-bit),
  flags (byte 13), window, mss (int or None), payload (bytes).
- **SegmentIntent** (core → egress): seq (unwrapped), ack (unwrapped or None), flags, carries_mss (bool),
  payload. Addresses, ports, TTL, ID and window are filled in by egress from the connection's template
  and C1.
- **DropReason:** `SHORT`, `NOT_IPV4`, `BAD_IHL`, `BAD_LENGTH`, `FOREIGN`, `NOT_TCP`, `FRAGMENT`,
  `BAD_IP_CSUM`, `BAD_TCP_LEN`, `BAD_TCP_CSUM`, `BAD_OPTIONS`.

### C3 Core vocabulary (`core/vocab.py`)
| Events in (core methods) | Meaning |
|---|---|
| Arrival(record, now) | an accepted inbound record |
| Clock(now) | time has advanced (called every pump iteration) |
| Begin-active(iss, local addr/port, remote addr/port, now) | client: start the handshake |
| Begin-passive(syn record, iss, now) | server: created by the listener from an admitted SYN |
| Queue(data) | the application appends bytes to the outbound half |
| Wind-down(now) | the application has no more data; start our close |

| Actions out (returned list, executed in order by the driver) | Meaning |
|---|---|
| Emit(SegmentIntent) | transmit one segment |
| Deliver(bytes) | in-order bytes for the application |
| PeerDone | the peer's FIN has been consumed (EOF after the delivered bytes) |
| Opened | the handshake completed |
| Finished(clean: bool) | teardown completed (clean) or the 2 s close limit expired |
| Failed(kind) | connection failed (C5); no further actions follow |
| Note(dict) | trace information (cwnd, rto, phase, retransmission); ignored unless tracing |

Each core object also exposes **next_deadline** (an absolute time, or None) and read-only counters used
by the Stream for backpressure: queued bytes and unacknowledged bytes.

### C4 Stream API (`driver/stream.py`, API-1/API-3)
Deadlines are absolute `time.monotonic()` values, or None.

| Call | Behaviour |
|---|---|
| `dial(ip, port, settings, journal)` → Stream | client active open. Raises Refused, HandshakeTimeout or LocalError |
| `Rendezvous(port, settings, journal)` and its `.next_stream()` → Stream | server. Blocks until a handshake completes; failed handshakes are absorbed and listening resumes |
| `stream.put(data, deadline=None)` | queue bytes; pumps while queued bytes exceed `send_buffer_cap` |
| `stream.take(limit, deadline=None)` → bytes | returns 1..limit bytes, or `b""` at EOF; raises TimedOut at the deadline (the connection is still usable), or a failure (C5) |
| `stream.finish()` → bool | pumps until all data is acknowledged, then performs the T9 close; True if clean |
| `stream.drop()` | forget the connection silently (nothing is sent) |
| `stream.local`, `stream.remote` | (ip, port) pairs |

### C5 Failure kinds (`core/vocab.py`, TCP-17)
- `Refused`: a RST answering our SYN.
- `Reset`: a valid RST later in the connection.
- `HandshakeTimeout`: T7 limit reached.
- `Stalled`: 10 s with no acknowledgement progress while data or FIN is outstanding.
- `LocalError`: socket, permission or OS error.
- `TimedOut`: an API deadline. This is not a connection failure.

All of them are exception types under a single base class, so HTTP can map them in one place.

### C6 HTTP parser events (`web/parsing.py`, API-2)
- **ResponseReader** (sans-I/O):
  - `feed(bytes)` → list of `StatusLine(version, code, reason, raw)`, `Fields(pairs)`, `BodyPiece(bytes)`,
    `Done`.
  - `at_eof()` → `[Done]` if the body is close-delimited, else raises `Incomplete`.
  - Raises `Malformed` on any syntax error.
- **RequestHeadReader:** `feed(bytes)` → None (more needed) or `RequestHead(request_line, fields)`. Raises
  `Oversize` past `head_cap`.

### C7 Trace record (APP-3)
One JSON object per line: `{"t": seconds_since_start, "k": kind, ...}`. Kinds: `drop` (reason), `cwnd`
(cwnd, ssthresh, state), `rto` (rto, srtt), `rtx` (seq, cause: timeout/fast), `phase` (from, to).

---

## §3 Network configuration — Phase 2

**Units:** `netcfg/client.sh`, `netcfg/r1.sh`, `netcfg/r2.sh`, `netcfg/server.sh`.
**Shared rules:** bash; `set -eu`; only `ip`, `sysctl` and shell builtins; interfaces only from the
arguments.

**NET-1 Validation (Step 2.2)**
- **Behaviour:** if the argument count isn't exactly 2 / 2 / 3 / 1, print usage to stderr and exit 1.
  Run `ip link show dev "$X"` for every argument before changing anything; any failure → exit 1 with
  nothing changed.
- **Acceptance:** a wrong count or bad name leaves `ip -br addr` unchanged.

**NET-2 Links and addresses (Step 2.3)**
- **Behaviour:** `ip addr replace` with the Table 1 address and prefix, then `ip link set up`, for each
  argument. All addresses go in before any route.
- **Locked:** `replace` (re-runnable), not `add`.

**NET-3 Routes (Step 2.4)**
- **Behaviour:**

  | Machine | Routes besides connected ones |
  |---|---|
  | client | `default via 10.10.1.1 dev IF_A` |
  | r1 | `default via 10.10.2.2 dev IF_B` (its only extra route) |
  | r2 | `10.10.1.0/24 via 10.10.2.1 dev IF_B`; `10.10.1.10/32 via 10.10.4.2 dev IF_D`; no default |
  | server | `default via 10.10.3.1 dev IF_C` |

- **Locked:** use `ip route replace`. No `src` hints, nexthop objects or policy rules.

**NET-4 Forwarding (Step 2.5)**
- **Behaviour:** routers set `net.ipv4.conf.<IF>.forwarding=1` on each of their argument interfaces;
  hosts set `=0` on theirs.
- **Locked:** per-interface keys only; the global `ip_forward` is untouched. Pending: if Step 2.5's test
  or TA Q4 shows per-interface keys are insufficient, switch to `ip_forward=1` on routers and log it in §16.

**NET-5 Reverse-path filtering (Step 2.6)**
- **Behaviour:** client `IF_D` → 2; r2 `IF_B` → 2; every other argument interface is explicitly 1;
  `conf.all` is untouched.
- **Acceptance:** `sysctl` shows 1 on r1 and server, and the two loose interfaces as 2.

**NET-6 Redirect hardening (Step 2.7)**
- **Locked:** not implemented. This is deliberately out of scope; mention it in the viva if asked.

**NET-7 Self-check (Step 2.8)**
- **Behaviour:** at the end of the script, run `ip route get` for the machine's key destinations and
  compare the next hop and device using bash `[[ … == *pattern* ]]`. Print `selfcheck: PASS|FAIL <dst>`
  to stderr; exit 1 on any FAIL. The checks are local route decisions only, so they don't depend on other
  machines being up.

  | Machine | Destination | Expected next hop and device |
  |---|---|---|
  | client | 10.10.3.10 | via 10.10.1.1 dev IF_A |
  | r1 | 10.10.3.10 | via 10.10.2.2 |
  | r2 | 10.10.1.10 | via 10.10.4.2 dev IF_D |
  | r2 | 10.10.1.1 | via 10.10.2.1 dev IF_B |
  | server | 10.10.1.10 | via 10.10.3.1 |

**Phase 2 acceptance:**
- On all four VMs from the fresh snapshot: `tools/test/verify-routing.sh` passes; the traceroutes match
  instructions.md III.2; no default route on r2; r1 has exactly one non-connected route.
- `tools/check_compliance.sh` shows no non-`ip`/`sysctl` commands.

---

## §4 Launch environment — Phase 3

**ENV-1 Launchers (Step 3.2)**
- **Behaviour:** POSIX sh. Setup lines (ENV-2, ENV-3) come first, then
  `exec python3 -B -E -s "$(dirname "$0")/../src/http_client.py" "$@"` (or `http_server.py`).
- **Locked:** every setup command sends stdout and stderr to `/dev/null` (I7: stdout belongs to the body).
  A setup failure never prevents the `exec`.

**ENV-2 Kernel RST suppression (Step 3.4)**
- **Client:** chain `A3C`. Create it if missing, flush it, add
  `-p tcp --sport 61000:65535 --tcp-flags RST RST -j DROP`. Ensure exactly one `-j A3C` jump in OUTPUT
  (`-C … || -I …`).
- **Server:** chain `A3S`. Find PORT by scanning the arguments for `-p VALUE` (default 8080). Add
  `-p tcp --sport PORT --tcp-flags RST RST -j DROP` with `-C … || -A …`. **Never flush** this chain,
  because several server instances may run at once for the fairness tests. Ensure one jump from OUTPUT.
- **Locked:** we never send RSTs ourselves (TCP-10), so no SO_MARK exemption is needed.
- **Acceptance:** the spike handshake completes, and tcpdump shows no kernel RST.

**ENV-3 Offload policy (Step 3.5)**
- **Pending** the probe result and TA Q3. The default rule:
  - If the probe sees coalesced segments (RECV `len` > 1460 or checksum failures under load), both
    launchers run `ethtool -K <if> gro off` for every non-loopback interface under `/sys/class/net`,
    ignoring errors, and README.md states this.
  - Otherwise, the launchers don't touch offloads.

  Record the outcome in §16.

**ENV-4 Root check (Step 8.6)**
- **Behaviour:** each entry checks `os.geteuid() == 0` first. If not root, print a one-line stderr message
  and exit 2.

---

## §5 Packet pipelines — Phase 4 (pure, unit-tested)

**IP-3 Internet checksum (`packets/checksum.py`, Step 4.3)**
- **Behaviour:** the one's-complement 16-bit checksum of a byte string. Odd lengths are padded with a
  trailing zero byte.
- **Locked:** the modular formulation. Interpret the padded bytes as one big-endian integer N; the folded
  sum is `N mod 65535`, mapped so that a non-zero input with remainder 0 yields 0xFFFF. The checksum field
  is the complement. Verification: the sum over a header that includes its checksum must be 0 mod 65535.
- **Acceptance:** matches header checksums in a real capture (`tcpdump -xx`); covers odd lengths, all
  zeros, and the 0 vs 0xFFFF cases.

**TCP-5 Sequence space (`packets/seqspace.py`, Step 4.4)**
- **Behaviour:** `wrap(unwrapped) → raw = unwrapped mod 2^32`. `unwrap(raw, reference) →` the unique
  integer ≡ raw (mod 2^32) nearest to `reference` (within ±2^31).
- **Locked:** each half keeps its own reference: the outbound half uses `snd_una`, the inbound half uses
  `rcv_nxt`. Unwrapped values start at the ISS or IRS as plain integers and grow past 2^32 freely.
- **Acceptance:** property tests around 0, 2^31 and 2^32 − 1 (wrap ∘ unwrap = identity).

**TCP-1 Segment encoding (`packets/tcpwire.py`, Step 4.5)**
- **Behaviour:** encode src/dst ports, seq, ack, data offset (5, or 6 with MSS), flags, window 65535,
  checksum over the pseudo-header (src, dst, 0, 6, TCP length) plus segment, urgent pointer 0, reserved
  bits 0.
- **Locked:**
  - The MSS option is the constant 4 bytes `02 04 05 B4`, included exactly when the intent's
    `carries_mss` is set (SYN, SYN-ACK).
  - The ack field is 0 when the intent's ack is None.
  - PSH is set on a data segment that empties the send buffer.

**IP-1 / IP-2 IPv4 encoding and ID (`packets/ipv4.py`, Step 4.5)**
- **Behaviour:** a 20-byte header: 0x45, TOS 0, total length, ID, flags = DF (0x4000), TTL 64,
  protocol 6, checksum (IP-3), src, dst.
- **Locked:**
  - A per-connection header **template** fixes the version, TOS, flags, TTL, protocol and addresses.
    Each packet patches the total length and ID and recomputes the full checksum. No incremental
    checksum.
  - The ID comes from a 16-bit **maximal-length LFSR** (period 65535, never 0), seeded with a random
    non-zero value by the driver. It is shared by all connections in one process.

**Egress composition (`packets/egress.py`, Step 4.5)**
- **Behaviour:** `(SegmentIntent, connection template, LFSR) → bytes`. It wraps seq and ack (TCP-5),
  encodes TCP (TCP-1), then encodes IPv4 (IP-1).

**IP-4 / TCP-4 / TCP-2 / TCP-3 Ingress stages (`packets/ingress.py`, `ipv4.py`, `tcpwire.py`, Step 4.6)**
Ingress is a fixed order of gates. Each returns the next value or a DropReason (C2):

| # | Gate | Drops as |
|---|---|---|
| 1 | Shape: ≥ 20 bytes, version 4, 20 ≤ IHL×4 ≤ length, total length ≤ bytes received (trim extra) | SHORT, NOT_IPV4, BAD_IHL, BAD_LENGTH |
| 2 | **Demux** on raw bytes before any checksum (TCP-4): see the filter rules below | FOREIGN |
| 3 | Protocol = 6; MF = 0 and offset = 0 | NOT_TCP, FRAGMENT |
| 4 | IPv4 header checksum (IP-3) | BAD_IP_CSUM |
| 5 | TCP length ≥ 20; 20 ≤ data offset × 4 ≤ TCP length | BAD_TCP_LEN |
| 6 | TCP checksum with the pseudo-header from the **received** addresses | BAD_TCP_CSUM |
| 7 | Decode fields; options scan (TCP-3) | BAD_OPTIONS |

- **Filter rules (gate 2):** `Listening(port)` matches when the destination port equals `port`, for any
  local address. `Exact(local ip, local port, remote ip, remote port)` matches the full four-tuple. The
  driver chooses the filter (§9).
- **TCP-3 options scan:**
  - kind 0 ends the scan; kind 1 is skipped as one byte;
  - any other kind needs a length ≥ 2 that stays within the options area, else BAD_OPTIONS;
  - kind 2 must have length 4, and its value is the record's `mss`. Any other kind is skipped.
  - The `mss` field is filled whenever the option is present, whatever the flags. The core only uses it
    on SYN and SYN-ACK.
- **Acceptance:** for every case, `ingress(egress(intent)) == intent` as a field-level round trip. One test
  per drop reason, using crafted bytes. Real captures decode correctly.

**LOG-2 Log line formatter (`packets/logline.py`, Step 4.7)**
- **Behaviour:** `(direction, InboundRecord) →` the exact line
  `DIR SRC:SPORT > DST:DPORT ttl=T id=I seq=S ack=A flags=0xFF win=W len=L mss=M`, with decimal fields,
  `flags` as `0x%02x`, `mss=-` when absent, and no trailing space.
- **Locked:** SEND lines are formatted from the **decoded egress bytes** (decode-only path, gate 7), never
  from the intent.
- **Acceptance:** `tools/test/check_log.py` accepts the output, and the handout example reproduces
  byte-for-byte.

**Phase 4 done when:** all of the above are unit-tested, `tools/test/run-unit.sh` is green, and the
pre-commit hook passes.

---

## §6 Test seams and HTTP parsers — Phase 5

**APP-4a Fake stream (`tests/fakes.py`, Step 5.1)**
- **Behaviour:** implements C4 exactly, over scripted byte chunks. It can simulate EOF, Reset or
  Stalled at a chosen point, and records what was `put`.

**APP-4b Simulation harness (`tests/harness/`, Step 5.2)**
- **Behaviour:**
  - A **virtual clock** and two core endpoints (client active, server passive via the listener).
  - Segments go through the **real egress and ingress pipelines** (stub records until Phase 4 lands)
    and then a channel.
  - **Channel parameters:** loss probability, reorder probability with extra delay, duplicate
    probability, base delay, and an optional rate limit with a drop-tail queue.
  - The same seed reproduces the same run.
  - Logs are formatted with LOG-2 so `check_log.py` can validate them.
- **Scenario library:**
  - handshake with first SYN, SYN-ACK or final ACK lost
  - 1 MB transfer under 0/1/5/10% loss × 0/25% reordering × duplicates
  - ISN near 2^32
  - RST during the handshake and mid-transfer
  - FIN loss and simultaneous close
  - peer silence (stall)
  - bottleneck queue (for TCP-16)
- **Acceptance:** an "echo" smoke test passes using placeholder endpoints. The harness is ready when
  Phase 6 starts.

**API-2 HTTP parsers (`web/parsing.py`, Step 5.3)**
- **Behaviour:** C6 readers.
  - **Response head:** the status line `HTTP/<d>.<d> SP <3 digits> [SP reason]`. Field lines contain
    `name:value`; names are case-insensitive; values are trimmed. Bare LF line endings are accepted.
    Head size is capped at `head_cap`. Interim 1xx responses are skipped.
  - **Body framing (RFC 9112 §6.3 order):**
    1. 1xx, 204 and 304 responses have no body.
    2. A Transfer-Encoding whose final coding is `chunked` means chunked.
    3. Any other Transfer-Encoding means close-delimited.
    4. Otherwise a valid Content-Length (one value, or identical repeats) is used.
    5. Otherwise the body is close-delimited.
    - Invalid or conflicting Content-Length → Malformed.
  - **Chunked decoding:** a hex size line (extension after `;` stripped, whitespace trimmed), then the
    data, then a line ending; size 0 is followed by trailer lines up to an empty line, then Done.
  - **Request head:** read until an empty line; Oversize past `head_cap`.
- **Acceptance:** byte-level tests:
  - every framing mode, fed one byte at a time and all at once
  - truncation at every boundary
  - chunk extensions and trailers
  - conflicting Content-Length
  - LF-only messages

---

## §7 Sans-I/O core — Phase 6 (verified in the harness before any socket is involved)

**TCP-15 Inbound half (`core/inbound.py`, Step 6.1)**
- **State:** `irs`, `rcv_nxt` (unwrapped), a 65536-byte **ring** indexed by unwrapped offset mod 65536,
  a sorted list of filled ranges `[start, end)` above `rcv_nxt`, the peer FIN position (or None), and an
  EOF flag.
- **Behaviour:**
  - Each segment is trimmed to `[rcv_nxt, rcv_nxt + 65535)`. Bytes inside the window are copied into the
    ring and their range merged.
  - The contiguous prefix starting at `rcv_nxt` becomes a **Deliver** and `rcv_nxt` advances.
  - A FIN at `seq + len` is recorded only if that position is inside the window. When `rcv_nxt` reaches
    it, `rcv_nxt` += 1 and **PeerDone** is emitted.
  - The half reports `owes_ack = True` for any segment that carried data or a FIN (including duplicates
    and segments outside the window). Pure ACKs owe nothing.
  - The current ACK number is always `rcv_nxt`.
- **Acceptance:** unit tests for in-order data, gaps then fills, overlaps on both edges, duplicates,
  segments beyond the window, a FIN before a gap is filled, and wrap near 2^32.

**TCP-14a RTO estimator (`core/rto.py`, Step 6.2)**
- **Behaviour:** RFC 6298.
  - First sample R: `srtt = R`, `rttvar = R/2`.
  - Later samples: `rttvar = ¾·rttvar + ¼·|srtt − R|`, then `srtt = ⅞·srtt + ⅛·R`.
  - `rto = clamp(srtt + max(0.01, 4·rttvar), rto_min, rto_max)`; initial `rto_initial`.
  - Backoff doubles the RTO, capped at `rto_max`. Any new sample clears the backoff.
- **Acceptance:** numeric tests against hand-computed sequences.

**TCP-13 / TCP-14b Outbound half (`core/outbound.py`, Step 6.3)**
- **State:**
  - `iss`, `snd_una`, `snd_nxt`, and `snd_max` (highest sent), all unwrapped
  - a send buffer as a byte array starting at `snd_una`
  - the peer window plus `wl1`/`wl2`, the effective MSS, and the duplicate-ACK count
  - a recovery point; FIN flags (wanted / sent / acked)
  - the retransmission deadline and the stall deadline
  - the **timing list**: entries of (end offset, first-send time, retransmitted)
- **Behaviour:**
  - **Segmentation:** `usable = min(cwnd, peer_window) − (snd_nxt − snd_una)`. While usable > 0 and
    unsent data exists, emit segments of `min(eff_mss, usable, unsent)`. A small final segment is allowed
    (no Nagle).
  - **ACK processing:** `ack` is unwrapped against `snd_una`. If `ack > snd_max` it is ignored. If
    `ack > snd_una`, then:
    - trim the buffer;
    - take an RTT sample from the newest timing entry with end ≤ ack that was never retransmitted
      (Karn's rule);
    - drop timing entries ≤ ack;
    - reset the backoff, restart the retransmission deadline, and reset the stall deadline;
    - `snd_nxt = max(snd_nxt, ack)`. This lets a receiver's out-of-order buffer skip data it already has.
  - **Window update (RFC 9293 rule):** accept the segment's window if `seq > wl1`, or if `seq == wl1` and
    `ack ≥ wl2`.
  - **Duplicate ACK** (RFC 5681 definition): `ack == snd_una`, no data, no SYN or FIN, unchanged window,
    and outstanding data > 0.
  - **Retransmission timeout:**
    - `snd_nxt = snd_una` (go back), mark the timing entries as retransmitted, double the RTO (cap 1 s),
      notify congestion (`on_timeout`), and emit from `snd_una` as the window allows.
    - With nothing outstanding the timer is disarmed. If the peer window is 0 while data is queued, the
      timer stays armed and its expiry emits one segment of at most 1 byte (deadlock guard only; no
      persist logic).
  - **Fast retransmit:** on the 3rd duplicate ACK, retransmit one segment at `snd_una` with no go-back.
    Congestion handles recovery (TCP-16, `on_triple_dup`). During recovery, a partial ACK retransmits the
    next segment at the new `snd_una`.
  - **Stall:** while anything is outstanding (data, SYN or FIN), the deadline is `last progress + 10 s`.
    Expiry → **Failed(Stalled)**.
  - **Our FIN:** emitted only when Wind-down has been requested **and every queued byte is acknowledged**.
    It occupies one sequence number and is retransmitted by the same timer.
- **Locked:** in Phase 6 the congestion object is a placeholder with a fixed window of 65535; Phase 11
  replaces it.
- **Congestion interface (internal):** `window()`, `on_new_ack(bytes_acked, flight)`,
  `on_triple_dup(flight)`, `on_extra_dup()`, `on_partial_ack(bytes_acked)`, `on_full_ack(flight)`,
  `on_timeout(flight)`, and `in_recovery`.
- **Acceptance:** unit tests for segmentation limits, a stale window update rejected, the dup-ACK
  definition, timeout go-back, ACK jumping over already-delivered data, the stall, and FIN gating.

**TCP-6 ISN and port (Step 6.4; selection itself happens in the driver, §9)**
- **Behaviour:** the core receives `iss` in Begin-active / Begin-passive.
- **Locked:**
  - The driver draws the ISN from `secrets.randbits(32)`, unless `forced_isn` is set (APP-5).
  - **Client port and source address use one UDP helper socket.** Pick a random port in
    `[61000, 65535]` and bind a UDP socket to `("0.0.0.0", port)`; retry with another port on
    EADDRINUSE, up to 32 tries. Then `connect` it to `(server_ip, server_port)` and read `getsockname()`.
    That gives both the kernel's chosen source IP (IP-5) and a port lock against our own concurrent
    clients. Keep the socket open for the life of the connection. It never sends a packet.

**TCP-9 Coordinator and phases (`core/endpoint.py`, Step 6.4)**
- **Phases:** `CLOSED`, `SYN_SENT`, `SYN_RCVD`, `ESTABLISHED`. Close progress isn't a separate phase; it
  is read from the halves (our FIN sent/acked, peer FIN consumed). Phase changes emit `Note`.
- **Per-segment order in synchronized phases:**
  1. **acceptability:** sequence in window per the RFC 9293 table, using window 65535. If not acceptable
     and not a RST: owe an ACK and stop.
  2. **RST** (TCP-10)
  3. **SYN:** a retransmitted SYN-ACK with `seq == irs` gets re-ACKed (TCP-7); any other SYN is ignored.
  4. **ACK:** no ACK flag → stop. Otherwise the outbound half processes it.
  5. **data**, then 6. **FIN**: the inbound half processes both.
- **After any event:** the outbound half emits whatever the window allows. Every Emit gets
  `ack = rcv_nxt` and the ACK flag (once the IRS is known). If an ACK is owed and nothing else was
  emitted, emit a pure ACK. Then compute `next_deadline` as the minimum over the handshake, retransmission,
  stall and close deadlines.
- **Acceptance:** a phase/flag mapping table to the RFC 9293 state names, kept in the report draft.

**TCP-7 Handshake (Step 6.4)**
- **Active (client):**
  - Begin-active emits a SYN (`carries_mss`, ack None) and enters SYN_SENT.
  - Retransmissions follow `handshake_retry_gaps`. At `handshake_give_up` → Failed(HandshakeTimeout).
  - In SYN_SENT:
    - an ACK with `ack ≠ iss + 1` is ignored;
    - a RST with an acceptable ACK → Failed(Refused);
    - a SYN-ACK with `ack == iss + 1`: record the IRS, the peer MSS (default 536), the peer window and
      `wl1`/`wl2`; take an RTT sample if the SYN was sent only once; go to ESTABLISHED; emit **Opened**
      and an ACK.
  - A SYN without ACK (simultaneous open) is ignored.
- **Passive (server):**
  - Begin-passive records the IRS and peer MSS from the SYN, emits a SYN-ACK (`carries_mss`) and enters
    SYN_RCVD. It uses the same retry schedule and give-up → Failed(HandshakeTimeout); the listener then
    resumes.
  - A duplicate SYN with the same IRS → resend the SYN-ACK.
  - An ACK with `ack == iss + 1` → ESTABLISHED and **Opened**. Processing then continues with the same
    segment's data and FIN (curl's first data segment can complete the handshake).
- **Acceptance (harness):** handshakes survive each loss pattern. Give-up happens after more than 6 s of
  virtual time, with gaps of at most 1 s.

**TCP-10 RST (Step 6.4)**
- **Behaviour:**
  - In SYN_SENT: see TCP-7.
  - In SYN_RCVD: a RST with `seq == rcv_nxt` → Failed(Reset).
  - In synchronized phases: `seq == rcv_nxt` → Failed(Reset); any other in-window RST is ignored.
- **Locked:** we never send a RST.

**TCP-11 Teardown (Step 6.4)**
- **Behaviour:**
  - Wind-down sets "FIN wanted" (sent per TCP-13 gating).
  - When our FIN is first transmitted, the close deadline is set to `now + close_limit`.
  - The peer's FIN is acknowledged when consumed (TCP-15).
  - Once our FIN is acked and the peer's FIN is consumed → **Finished(clean=True)**.
  - At the close deadline → **Finished(clean=False)**.
  - Simultaneous close needs no special case.
  - No TIME_WAIT: after Finished, the endpoint is done.
- **Acceptance (harness):** client-first and server-first close, a lost FIN, a lost FIN-ACK, simultaneous
  FINs. Each completes or gives up in ≤ 2 s after our FIN.

**TCP-17 Failures (Step 6.4)**
- **Behaviour:** Failed(kind) is final. After it, the endpoint emits nothing and ignores all events.

**TCP-8 Listener (`core/listener.py`, Step 6.5)**
- **States:** `waiting` and `busy`.
- **Behaviour:**
  - In `waiting`, a record with SYN set and ACK clear is **admitted**: the listener returns an admission
    with the record, and the driver creates the endpoint (Begin-passive), switches the filter to Exact,
    and logs that SYN as RECV (LOG-4). Every other record is ignored and not logged.
  - In `busy`, the listener sees nothing, because the Exact filter drops other clients' SYNs at gate 2.
  - When the endpoint emits Finished or Failed, the listener returns to `waiting` and the driver restores
    `Listening(port)`.

**Phase 6 done when (harness, all with `check_log.py`-valid logs):**
- every scenario in APP-4b passes, with byte-exact delivery;
- under 10% loss with 25% reordering, a 1 MB transfer completes;
- the wrap scenario passes.

This is milestone **M2**.

---

## §8 HTTP client — Phase 7 (against the fake stream, real network in Phase 10)

**HCL-1 Command line (`http_client.py`, Step 7.1)**
- **Behaviour:** `argparse` with a positional URL, `-o OUTFILE` and `--log LOGFILE`. Usage errors exit 2.

**HCL-2 URL (`web/urlparts.py`, Step 7.2)**
- **Locked rules:**
  - The scheme is `http://`, matched case-insensitively; anything else is invalid.
  - The authority runs up to the first `/` or the end of the string. If it contains `@`, `[`, `?`, `#`,
    whitespace, or is empty → invalid.
  - `HOST[:PORT]`: the port must be 1–5 digits in 1..65535; `host:` with an empty port is invalid.
  - The path runs from the first `/` up to `#` (the fragment is discarded and never sent). Default `/`.
    Any whitespace or control character → invalid.
  - The Host header value is the authority exactly as written.
- **Acceptance:** a table-driven test of at least 30 cases.

**HCL-3 Resolution (Step 7.3)**
- **Behaviour:** `inet_pton(AF_INET)` first; if that fails, `getaddrinfo(host, None, AF_INET)` and use the
  first address. Failure → exit 2.

**HCL-4 Request (Step 7.4)**
- **Behaviour:** exactly
  `GET <path> HTTP/1.1\r\nHost: <authority>\r\nConnection: close\r\n\r\n`. No other headers.
- **Acceptance:** a byte-exact test.

**HCL-5 / HCL-6 Response (Step 7.5)**
- **Behaviour:** feed every `take()` result to the ResponseReader (C6).
  - On `StatusLine`, write the raw status line to stderr immediately.
  - On `BodyPiece`, write to the sink (HCL-7).
  - On `Done`, the response is complete.
  - `take()` returning `b""` → `at_eof()`.
  - Malformed or Incomplete → exit 2.
  - Each `take()` uses the deadline `now + idle_limit`; TimedOut → exit 2.

**HCL-7 Output (Step 7.6)**
- **Locked:**
  - Open OUTFILE (`wb`) **before** dialing; failure → exit 2 with no network activity.
  - Without `-o`, write to `sys.stdout.buffer`.
  - Stream pieces as they arrive and flush at the end.
  - On exit 2, whatever was written stays (documented in README.md). On exit 1, the full body is saved.

**HCL-8 Exit codes (Step 7.7)**
- **Locked:** a single top-level handler.
  - Done with a 2xx status → 0.
  - Done with any other status → 1.
  - Every failure (C5 kinds, URL, DNS, Malformed, Incomplete, OS errors) → 2.
- **Acceptance:** each path is tested with the fake stream.

**HCL-9 Close (Step 7.8)**
- **Behaviour:** after Done, call `stream.finish()`. Its result never changes the exit code. On a
  failure, `stream.drop()`.

---

## §9 Driver — Phase 8

**IO-1 Socket (`driver/wire.py`, Step 8.1)**
- **Behaviour:** `socket(AF_INET, SOCK_RAW, IPPROTO_TCP)`; `IP_HDRINCL = 1` set **explicitly**; non-blocking.
- **Locked:** request `socket_rcvbuf` with `SO_RCVBUFFORCE` (Linux value 33, available to root), falling
  back to `SO_RCVBUF`. Read the granted size back into the trace.

**IO-2 Transmit (Step 8.1)**
- **Behaviour:** `sendto(bytes, (dst_ip, 0))`. On `BlockingIOError` or `ENOBUFS`, keep the packet in a
  FIFO and retry at the start of the next pump iteration, before anything new is sent. Other errors →
  LocalError.

**IO-3 Receive (Step 8.1)**
- **Behaviour:** after `select` reports the socket readable, drain it with `recvfrom_into` into one
  preallocated 65535-byte buffer until `BlockingIOError`. Copy each datagram into an immutable bytes
  object before ingress.

**IP-5 / IP-6 Addressing (`driver/addressing.py`, Step 8.2)**
- **Client:** the source IP and port come from the UDP helper socket (TCP-6). Ingress filter
  `Exact(src_ip, src_port, server_ip, server_port)`.
- **Server:** `Listening(port)`. On admission, the endpoint's template uses the **SYN's destination
  address** as its source, then `Exact(...)`.
- Local-address acceptance relies on the kernel delivering only locally addressed datagrams to raw
  sockets; this is stated in the report.

**LOG-1 / LOG-3 / LOG-4 Journal (`driver/journal.py`, Step 8.3)**
- **Behaviour:**
  - `--log FILE` opens the file once (`"w"`, line-buffered, UTF-8); failure → exit 2.
  - **Exactly two call sites:** the transmit chokepoint (format the egress bytes via LOG-2 → write →
    transmit) and the accept chokepoint (for records that pass ingress *and* are routed to the endpoint
    or admitted by the listener).
  - Without `--log`, nothing is written.
  - The server keeps one log file for its whole run.

**APP-3 Trace (`driver/journal.py`, Step 8.4)**
- **Behaviour:** if `A3_TRACE=<path>` is set, write C7 records (drops, Notes) as JSON lines to that path.
  Off by default; never stdout; never the `--log` file.

**TCP-12 Pump (`driver/pump.py`, Step 8.5)**
- **Behaviour:** `run(until, deadline)` loops:
  1. retry the transmit FIFO;
  2. if `until()` holds, return True;
  3. compute `wake` (§1.2); if the caller's deadline has passed, return False;
  4. `select` with timeout `max(0, wake − now)`;
  5. drain the socket and run each datagram through ingress → listener or endpoint;
  6. feed `Clock(now)`;
  7. execute actions:
     - Emit → egress → journal → transmit;
     - Deliver → the stream's inbox;
     - PeerDone → mark EOF;
     - Opened and Finished → set flags;
     - Failed → raise the C5 exception after logging;
     - Note → trace.
- **Locked:** `time.monotonic()` only; a single thread.

**API-1 / API-3 Stream (`driver/stream.py`, Step 8.6)**
- **Behaviour:** C4 on top of the pump.
  - `take` pumps until the inbox is non-empty, EOF, failure or the deadline.
  - `finish` sends Wind-down, then pumps until Finished, Failed or Stalled; it returns True only for a
    clean finish.
  - `dial` and `Rendezvous` build the per-connection header template and the LFSR seed, and draw the ISN.

**ENV-4 / APP-5 Entry hooks (Step 8.6)**
- **Behaviour:**
  - The root check (§4).
  - `A3_FORCE_ISN=<decimal>` → `Settings.forced_isn`, used only by Step 12.2.
  - `A3_TRACE` → `trace_path`.
  - Both hooks are inert when unset.

**Phase 8 acceptance on the VMs (milestone M3):**
- the client dials `python3 -m http.server` on SERVER and finishes cleanly;
- `curl http://10.10.3.10:8080/` completes a handshake and close against `Rendezvous` (with a stub
  server loop);
- 100% loss on r1 for 3 s → SYN retransmits at most 1 s apart, and the connection survives;
- a closed port → Refused at once; the server VM off → HandshakeTimeout after more than 6 s;
- all logs pass `check_log.py`.

---

## §10 HTTP server — Phase 9 (against the fake stream, real network in Phase 10)

**HSV-1 Startup (`http_server.py`, Step 9.1)**
- **Behaviour:** `argparse` with `-p` (int, default 8080), `-d` (default `./www`), and `--log`.
- **Locked:** the docroot is made absolute once. A missing docroot is allowed: warn on stderr, and every
  request gets 404.

**HSV-4 Request line → 400 (`web/serve.py`, Step 9.2)**
- **Behaviour:** the first line of the head, split on single spaces, must give exactly 3 non-empty parts.
  The method must be one or more RFC 9110 token characters, the target must start with `/`, and the
  version must match `HTTP/<digit>.<digit>`. Header lines aren't validated.

**HSV-5 Method → 501 (Step 9.3)**
- **Behaviour:** the dispatch table `{GET: send body, HEAD: no body}`, case-sensitive. A missing entry
  → 501.

**HSV-6 Target → file → 403 / 404 (Step 9.4)**
- **Locked:**
  - Strip from the first `?`. Any `/`-separated segment exactly `..` → 403.
  - `candidate = docroot + path`. If the path ends with `/` or `candidate` is a directory → append
    `index.html`.
  - If it is a regular file that opens for reading → 200; otherwise → 404 (this includes unreadable files
    and directories without `index.html`).
  - Empty and `.` segments get no special treatment; symlinks are followed; no percent-decoding.

**HSV-7 Content-Type (`web/content.py`, Step 9.5)**
- **Locked:** a dict keyed by the lowercased extension from `os.path.splitext` of the final file name
  (Table 5). A dotfile such as `.html` has no extension → `application/octet-stream`.

**HSV-8 Responses (`web/content.py`, Step 9.6)**
- **Behaviour:** one head builder `(code, length, type)` →
  `HTTP/1.1 <code> <reason>\r\nContent-Type: <type>\r\nContent-Length: <n>\r\nConnection: close\r\n\r\n`.
  The 400, 403, 404 and 501 bodies are small HTML pages built once at startup. HEAD uses the GET head
  unchanged.

**HSV-3 Head reading (Step 9.7)**
- **Behaviour:** deadline = time Opened + `head_limit`. Call `take` with that deadline and feed the
  RequestHeadReader.
- **Locked:** TimedOut, EOF before the head, or Oversize → `finish()` with **no response**. Bytes after
  the head are ignored.

**HSV-9 Body (Step 9.8)**
- **Behaviour:** open the file, get its size with `fstat`, `put` the head, then stream 65536-byte reads
  through `put`.

**HSV-2 / HSV-10 Serve loop (Step 9.9)**
- **Behaviour:** forever:
  1. `next_stream()`;
  2. handle the request inside `try/except Exception`;
  3. `finish()` (or `drop()` after a failure);
  4. print a one-line summary to stderr.
- A client failure never escapes the loop. `KeyboardInterrupt` → exit 0.

**Phase 9 acceptance (fake stream):** every Table 4 row and its ordering (for example, `FOO /../x` → 501;
`GET x` → 400), every Table 5 type, HEAD/GET header equality, the slow-drip head timeout, the oversize
head, and a client failure mid-body.

---

## §11 Integration — Phase 10

- **Step 10.1 (M4):** the client against the reference server for `index.html`, `blob.bin`, `1M.bin` and
  `10M.bin`; `tools/test/md5check.sh` → MATCH.
- **Step 10.2:** real-server client cases:
  - 404 → exit 1;
  - chunked bodies via `tools/test/chunked-server.py` (to be written at this step);
  - a hostname through `/etc/hosts`;
  - a bad host and a bad URL → exit 2.

  Then the R4 screenshots.
- **Step 10.3:** our server with curl, wget and our client; `tools/test/server-edge.sh` all PASS. Then the
  R5 screenshots.

---

## §12 Congestion control — Phase 11

**TCP-16 (`core/congestion.py`)**
- **Locked:** NewReno (RFC 6582) with byte counting (RFC 3465).
  - **Initial state:** `cwnd = initial_cwnd_segments × mss`; `ssthresh = 2^30` (effectively infinite).
  - **New ACK outside recovery:**
    - slow start (`cwnd < ssthresh`): `cwnd += min(bytes_acked, abc_limit_segments × mss)`;
    - congestion avoidance: add `bytes_acked` to an accumulator; each time it reaches `cwnd`, subtract
      `cwnd` and add `mss` to `cwnd`.
  - **Third duplicate ACK:** `ssthresh = max(flight/2, 2·mss)`; `cwnd = ssthresh + 3·mss`;
    `recover = snd_max`; enter recovery.
  - **Each extra duplicate ACK in recovery:** `cwnd += mss`.
  - **Partial ACK (`ack < recover`):** `cwnd = max(cwnd − bytes_acked + mss, mss)`, and the outbound half
    retransmits the next segment.
  - **Full ACK (`ack ≥ recover`):** `cwnd = min(ssthresh, flight + mss)`; leave recovery.
  - **Timeout:** `ssthresh = max(flight/2, 2·mss)`; `cwnd = mss`; leave recovery.
  - Every change emits a `Note` of kind `cwnd`.
- **Contingency (only if Step 13.2 fairness is outside 0.6–1.6):** pacing — spread each window over
  `srtt` by limiting emits per pump wake. Record the use in §16.
- **Acceptance:**
  - unit tests per event;
  - in the harness bottleneck scenario, the trace shows the sawtooth;
  - on the VMs, a bottleneck on r2 IF_D (`netem.sh bottleneck 20mbit 10ms`) and a 10 MB download show
    the sawtooth. Keep that trace for R6.

---

## §13 Robustness and Part E acceptance — Phases 12–13

| Step | Test | Pass condition |
|---|---|---|
| 12.1 | netem loss 1/5/10% × reorder 0/25%, on r2 IF_D, on r1 IF_B, and on both | md5 MATCH every run; durations in `docs/test-results.md` |
| 12.2 | `A3_FORCE_ISN=4294962296` client and server | MATCH |
| 12.3 | server killed mid-transfer / closed port / server VM off | exit 2 within ~10 s / immediately / after > 6 s |
| 12.4 | 12.1 at 5% with GRO on and off | matches the ENV-3 decision (M5) |
| 13.1 | our client ↔ our server, every docroot file, clean and at 5% loss with reordering | MATCH |
| 13.2 | `fairness.sh` 1v1 and 3v3 (5v5 optional, instructions.md O5) with a 20 Mbit/10 ms bottleneck | per-flow throughput ratio within about 0.6–1.6 (M6) |
| 13.3 | R6 capture and trace | screenshot + description drafted |

---

## §14 Decision register

**Locked by adopting C-1 (2026-10-10):**
- **Language and runtime:** Python 3.10, stdlib only, no Makefile.
- **Socket:** one raw socket with explicit `IP_HDRINCL`.
- **Concurrency:** the single-threaded pump.
- **Congestion control:** NewReno with byte counting and an initial window of 10.
- **RTO:** RFC 6298 + Karn, clamped to [0.2, 1] s.
- **Every Locked line in §3–§12.**

**Pending items:**
| ID | Waits on | Default if no answer by Phase 10 |
|---|---|---|
| ENV-3 | Step 3.5 probe + TA Q3 | the rule in §4 ENV-3 |
| ENV-2 | TA Q2 | iptables chains as specified |
| NET-4 | Step 2.5 + TA Q4 | per-interface keys |
| Packaging root | TA Q1 | files at zip root |
| Fairness setup | TA Q5 | several server instances on different ports |
| Shared folder / arm64 | TA Q8, Q9 | shared folders; final test on x86-64 |

---

## §15 Traceability (handout → spec)
| Handout | Spec items |
|---|---|
| A1–A8, §1.4 | §3 NET-1…NET-7 |
| §1.5 VMs | instructions.md VII |
| T1 | IP-1, IP-2, IP-3 |
| T2 | TCP-1, IP-3 |
| T3 | TCP-1, TCP-3, TCP-13 |
| T4 | ingress gates 1–7 (IP-4, TCP-2, TCP-3) |
| T5 | TCP-4 filter, TCP-8, IP-6 |
| T6, T13 | TCP-6, HSV-1 |
| T7 | TCP-7, TCP-9 |
| T8 | TCP-10, TCP-7 |
| T9 | TCP-11, TCP-13 (FIN gating), HCL-9, HSV-10 |
| T10 | TCP-13, TCP-14a/b |
| T11, T12 | TCP-15, TCP-5 |
| T14 | TCP-16 |
| §2.6 log | LOG-1…LOG-4 |
| Part C | HCL-1…HCL-9, API-2, C4 |
| Part D | HSV-1…HSV-10, TCP-8, IP-5, API-2, C4 |
| Part E | §11, §13 |
| §6.1–§6.4 | §1.4–§1.5, IO-1, ENV-1…ENV-4 |

---

## §16 Change log and final names
| Date | Change | Agreed by |
|---|---|---|
| 2026-10-10 | v1.0: C-1 adopted; all picks locked as above | — |
| 2026-10-10 | Reference pass (`reference/`) implemented against v1.0. Names used there: ingress entry `screen()` (not `accept`, I4); core `Endpoint.active/passive/arrival/clock/queue/wind_down`; outbound `fill/on_ack/expire`; inbound `absorb`; `Listener.admits/release`; driver `Wire`, `PortClaim`, `Journal`, `Trace`, `Pump`, `Conn`, `Stream`, `dial`, `Rendezvous`, `deadline_in`. Settings `handshake_retry_gaps = (0.25, 0.5, 1.0)`. Trace omits FOREIGN drops (too many during fairness runs). ENV-3 still pending (no GRO step in launchers yet). | Claude (reference only; your pass may rename) |
| 2026-10-10 | Test finding: a receiver sees `bad-tcp-csum` drops when the *sender's* NIC leaves TCP checksums to offload on a virtual link (seen on loopback/veth). Real and emulated NICs between VMs fill them in; if the Step 3.5 probe shows `bad-tcp-csum` drops in `A3_TRACE`, run `ethtool -K <IF> tx off` on the sending VM for testing and ask the TA (Q3). | Claude |
| 2026-10-12 | §1.6 audit of `reference/`: banned identifier `base` (F4) renamed: `OutboundHalf.base` → `head_seq`, `RtoClock.base` → `steady`, IPv4 header template `base` → `template`. No behaviour change (47/47 tests on Python 3.10; 4-namespace e2e MATCH; server-edge 17/17). | Claude |
