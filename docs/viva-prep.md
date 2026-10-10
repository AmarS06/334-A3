# Viva preparation (20% of grade) — both members must answer all of these

## Network
- Walk through every route on every machine; why does r2 need a /32?
- Why does r2 appear as 10.10.4.1 in client->server traceroute?
- Why loose rp_filter exactly on client IF_D and r2 IF_B? What does max(all, if) mean?
- What happens if you set the interface rp_filter to 0 instead of 2?
- Why do the client's RECV lines show ttl=63 but the server's show ttl=62?

## Architecture
- Explain C-1 (SPEC §1): why a sans-I/O core, why two halves, why pipelines. How does it differ from F2/F3/F5/F6?
- What does the core do when no event arrives? (Nothing: time only enters through Clock events.)
- Why is our FIN sent only after all data is acknowledged? (T9 2 s limit vs data still in flight.)
- Walk one received segment through every unit, from the socket to HTTP.

## TCP
- Why does the kernel send RSTs, and how did you stop it? Why 61000–65535?
- What does the kernel still change in your IP header with IP_HDRINCL?
- Compute a TCP checksum by hand for a tiny segment. Why the pseudo-header?
- How do you compare sequence numbers across wraparound?
- Draw your state machine. What happens on a lost SYN-ACK? A lost final ACK? A lost FIN?
- Explain your RTO computation, Karn's algorithm, and the 1 s cap.
- Show how the out-of-order buffer is merged when a gap is filled.
- Explain slow start, congestion avoidance, fast retransmit, fast recovery with your code.
- Why can a 65535 window make fairness look wrong? Bandwidth-delay product.
- What is GRO and why could it break your checksum check?

## HTTP
- Chunked decoding with extensions/trailers; close-delimited bodies; how do you detect incomplete?
- Exit code for 404 vs DNS failure vs truncated body.
- Server status-rule ordering: what does `GET /../x HTTP/1.1` vs `FOO /x HTTP/1.1` vs `GET x HTTP/1.1` give?
- What happens if a client connects and sends nothing?
