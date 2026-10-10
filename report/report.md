# COL334 A3 Report — <Team>
(Write in your own words. Every screenshot: taken on the 4 VMs, readable, showing the command.)

## R1 Network-adapter settings and addressing
- Screenshots: VirtualBox adapter settings x4 (screenshots/R1/)
- `ip -br addr` and `ip route` on client, r1, r2, server

## R2 Traceroutes
- `traceroute -n 10.10.3.10` on client; `traceroute -n 10.10.1.10` on server
- Explain each hop; why the directions differ; why r2 appears as the address it does

## R3 Reverse-path filtering
- Table: machine / interface / value / reason

## R4 Client vs standard web server
- HTML page + binary >=100 KB from python3 -m http.server on server VM; exit codes; md5sum vs curl

## R5 Our server vs curl, wget, our client
- md5sums of all three match the original

## R6 Capture + design description
- tcpdump -nn of one complete connection of our client
- Retransmission, out-of-order buffering, congestion control (short)
