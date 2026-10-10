# Exclusion list (read at Step 0.4; extended in Phase 15). Built from shapes and vocabulary only, never corpus code.

Header field order and RFC arithmetic are forced. Everything below covers what is **not** forced:
names, module boundaries, statement order, data structures, helper decomposition, and idioms.

## Architecture families (start from instructions.md Part VI.1; confirm/extend from the survey)
| Family | Shape we will not reproduce | Our chosen shape (SPEC §1) |
|---|---|---|
| F1 flat tutorial script | | packets/ split into pure gate stages; checksum is a modular computation, not a word loop |
| F2 raw-socket HTTP-GET course projects | | no socket wrapper class; one raw socket in driver/wire.py; core never sees sockets |
| F3 CS144-style layered classes | | outbound/inbound halves + coordinator; no tick(); time arrives as events; ring+ranges, no reassembler class |
| F4 textbook RDT | | single RTO timer, go-back on timeout, unwrapped offsets; no base/nextseqnum vocabulary |
| F5 thread-per-concern | | single thread; synchronous pump driven by Stream calls |
| F6 generated "TCPConnection god class" | | event-in/action-out core; no send_syn/handshake/receive methods |
| F15 previous COL334 repos | | (fill after survey) |

## Packet layer (surveyed by B)
| Seen in public code | Our choice instead |
|---|---|

## Connection / reliability / CC (surveyed by B)
| Seen in public code | Our choice instead |
|---|---|

## HTTP client (surveyed by A)
| Seen in public code | Our choice instead |
|---|---|

## HTTP server (surveyed by A)
| Seen in public code | Our choice instead |
|---|---|
