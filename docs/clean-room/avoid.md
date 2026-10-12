# Exclusion list (read at Step 0.4; extended in Phase 15). Built from shapes and vocabulary only, never corpus code.

Header field order and RFC arithmetic are forced. Everything below covers what is **not** forced:
names, module boundaries, statement order, data structures, helper decomposition, and idioms.

## Architecture families (start from instructions.md Part VI.1; confirm/extend from the survey)
| Family | Shape we will not reproduce | Our chosen shape (SPEC §1) |
|---|---|---|
| F1 flat tutorial script | one file; `checksum(msg)` looping over byte pairs with `ord()`; `struct.pack('!BBHHHBBH4s4s', …)` for IP then TCP; `tcp_header`/`ip_header` locals; `while True: recvfrom(65535)` |  packets/ split into pure gate stages; checksum is a modular computation, not a word loop |
| F2 raw-socket HTTP-GET course projects (CS4700 `rawhttpget` lineage, many GitHub copies) | **two sockets**: send `SOCK_RAW/IPPROTO_RAW` + receive `SOCK_RAW/IPPROTO_TCP` or `IPPROTO_IP`; a `RawSocket`/`TCPSocket` class with `connect()/send()/recv()/close()`; `cwnd` starting at 1, +1 per ACK, cap 1000, reset to 1 on loss; fixed 60 s retransmit, 180 s abort; HTTP/1.0 to avoid chunked; a global iptables rule for all RSTs |  no socket wrapper class; one raw socket in driver/wire.py; core never sees sockets |
| F3 CS144-style layered classes | | outbound/inbound halves + coordinator; no tick(); time arrives as events; ring+ranges, no reassembler class |
| F4 textbook RDT | | single RTO timer, go-back on timeout, unwrapped offsets; no base/nextseqnum vocabulary |
| F5 thread-per-concern | | single thread; synchronous pump driven by Stream calls |
| F6 generated "TCPConnection god class" | | event-in/action-out core; no send_syn/handshake/receive methods |
| F15 previous COL334 repos | none found publicly for this assignment version (2026-10-12 search); re-search before submission | n/a |

## Packet layer (surveyed by B)
| Seen in public code | Our choice instead |
|---|---|
| `checksum(msg)` summing 16-bit words in a loop, then `~s & 0xffff` | one-pass modular sum over the whole buffer (`internet_checksum`), verify by summing to zero |
| `struct.pack` / `struct.unpack` with one long format string per header | slice assignment into a template `bytearray` with `to_bytes`/`from_bytes` |
| header classes with `pack()`/`unpack()` methods mirroring field order | immutable records (`SegmentIntent`, `InboundRecord`) + pure codec functions |
| filtering received packets with a chain of `if` checks inside the recv loop | ordered gate stages in `packets/ingress.py` returning a drop reason |
| IP ID from `random.randint` or a fixed `54321` | LFSR-style id source injected by the driver |
| two raw sockets (IPPROTO_RAW out, IPPROTO_TCP/IP in) | one `IPPROTO_TCP` socket with `IP_HDRINCL` for both directions |

## Connection / reliability / CC (surveyed by B)
| Seen in public code | Our choice instead |
|---|---|
| methods `handshake()`, `send_syn()`, `send_ack()`, `send_fin()` on one connection class | event-in / action-out `Endpoint` (`arrival`, `clock`, `queue`, `wind_down`) emitting `Emit`/`Deliver` actions |
| `cwnd` +1 per ACK, reset to 1, cap 1000 (CS4700 rule) | NewReno with byte counting, IW10, ssthresh, fast retransmit/recovery |
| fixed 60 s / 1 s retransmission timer | RFC 6298 estimator + Karn, clamped [0.2, 1] s |
| dict `{seq: data}` reassembly buffer | receive ring with merged ranges in `InboundHalf` |
| raw 32-bit sequence comparisons with ad-hoc wrap checks | unwrapped integers in the core, wrap only at the codec boundary |
| `threading` for a receive loop + timer thread | single-threaded synchronous pump with deadline fields |

## HTTP client (surveyed by A)
| Seen in public code | Our choice instead |
|---|---|
| HTTP/1.0 request to dodge chunked encoding | HTTP/1.1 with Content-Length, chunked and close-delimited bodies |
| `response.split(b"\r\n\r\n", 1)` on the whole buffered reply | incremental head reader; body streamed to the sink as it arrives |
| `urlparse` from `urllib` | own `split_url` in `web/urlparts.py` (urllib is forbidden anyway) |

## HTTP server (surveyed by A)
| Seen in public code | Our choice instead |
|---|---|
| `BaseHTTPRequestHandler` / `do_GET` shape (CPython `http.server`) | `RequestHeadReader` + `judge` returning a status, rule order 400 → 501 → 403 → 404 |
| `mimetypes.guess_type` | fixed extension table in `web/content.py` |
| `os.path.join(root, path)` without normalisation | segment-wise path check rejecting `..` before any file access |

## Survey sources (2026-10-12; shapes and names only, no code copied)
- CS4700/5700 Project 4 `rawhttpget` specification — https://cbw.sh/5700/project4.html
- aj04/raw_sockets — https://github.com/aj04/raw_sockets
- DennisPing/TCP-IP-Raw-Sockets (Go) — https://beta.pkg.go.dev/github.com/DennisPing/TCP-IP-Raw-Sockets
- PyTCP (Python user-space stack) — https://pypi.org/project/PyTCP
- To do in full Phase 15: clone the above plus BinaryTides tutorials, CS144 solutions, level-ip, lwIP into
  `refcorpus/` and run Dolos/JPlag **on your `src/`**.
