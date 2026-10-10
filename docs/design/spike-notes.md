# P3 de-risking spike — record observations here

- [ ] Hand-built SYN reaches server; SYN-ACK received on raw socket (note: arrives on client IF_D!)
- [ ] Kernel RST observed in tcpdump (before suppression) — screenshot for viva
- [ ] RST suppressed; handshake completes
- [ ] IP_HDRINCL: confirm what kernel overwrites (checksum/total length; ID/src if zero)
- [ ] GRO: download 1 MB from python http.server; any RECV len > 1460? checksum failures?
      `ethtool -k <if> | grep generic-receive-offload`
- [ ] Received TTL values on each side
