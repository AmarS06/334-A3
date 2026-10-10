# Public implementations corpus (solo: built in Step 15.1; two-person variant: Step 0.4)

Surveyor records **high-level ideas and recognizable idioms only**. No code in this file.
TCP/raw-socket sources are surveyed by **B**; HTTP sources by **A** (instructions.md I.4).
Clone each source into `refcorpus/<name>/` on HOST only.

## Candidate sources (verify each exists and is relevant; add what the searches turn up)
| Group | Candidates |
|---|---|
| Raw-socket HTTP-over-TCP course projects (closest to this assignment, Python and C) | Student repos for "raw sockets" / "rawhttpget" course projects on GitHub; previous-year **COL334** repos (search "COL334") |
| Tutorial snippets copied widely | BinaryTides raw-socket tutorials (C and Python); popular Stack Overflow answers on IP_HDRINCL SYN packets and TCP checksum functions |
| Teaching / small stacks | Stanford CS144 TCP labs (C++) and student solutions; level-ip (C) + "Let's code a TCP/IP stack" blog series; PyTCP (Python) |
| Embedded / production stacks (structure reference) | lwIP, uIP, picoTCP (C); Linux `net/ipv4/tcp_*.c` |
| HTTP | CPython `http/server.py`, `http/client.py`; tinyhttpd (C); "simple HTTP server with sockets" tutorials; chunked-decoder snippets |

Cross-check every row against the architecture families in instructions.md Part VI.1 (F1–F15) and add a
"Family" column value for each surveyed source.

## Search queries (GitHub, web)
`raw socket tcp handshake python`, `IP_HDRINCL tcp syn python`, `rawhttpget`, `raw socket http get python`,
`tcp checksum pseudo header python`, `tcp reno implementation python udp`, `reliable transfer raw socket`,
`COL334 assignment`, `COL334 raw socket`, `tcp over raw sockets c`, `simple http server socket python 404 content-type`,
`chunked transfer encoding parser python socket`.

## Survey table
| # | Name | Lang | URL | Family (F#) | Scope | High-level structure | Recognizable idioms (names, decomposition, tricks) |
|---|---|---|---|---|---|---|---|
| 1 | | | | | | | |
