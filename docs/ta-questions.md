# Questions for TAs (send early; record answers here)

| # | Question | Answer | Date |
|---|---|---|---|
| 1 | ZIP root: files directly at zip root, or inside an `A3_<E1>_<E2>/` folder? | | |
| 2 | Is an iptables rule in the launchers the intended way to suppress kernel RSTs for our ports? | | |
| 3 | Are GRO/NIC offloads disabled on the grading VMs? Which NIC type is used? | | |
| 4 | Is global `net.ipv4.ip_forward` acceptable given "do not touch any other interface", or should we use per-interface forwarding? | | |
| 5 | "Several connections of each kind": should we run several server instances on different ports? | | |
| 6 | Is using an AI assistant for explanations/review and for non-submitted test scripts acceptable under §10? | | |
| 7 | Are stdlib modules like argparse, select, ctypes acceptable? | | |
| 8 | We use hypervisor shared folders (not a network link) to move code into the VMs. Is that compatible with "no connection to the host computer"? | | |
| 9 | We develop on arm64 (Apple Silicon) Ubuntu 22.04 VMs; the grader is x86-64. Is that acceptable, and is a hypervisor shared folder (no network link) into the VMs acceptable? | | |
| 10 | Can the assignment be submitted by one person (solo)? If so, is the ZIP named `A3_<entry>.zip`, and does grading or the viva change? | | |
