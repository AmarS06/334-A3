# Interface map (setup.md S7; verified 2026-10-12 with check-fresh.sh in all four VMs — redo if a clone is rebuilt)

## Hypervisor networks
VirtualBox internal networks (created by `tools/vm/vbox-clone-topology.sh create`): LAN_A, LAN_B, LAN_C,
LINK_D. Adapter type used: 82540EM (Intel PRO/1000 MT Desktop, e1000) (from `vbox-clone-topology.sh map`).


| VM | Interface | MAC | Network | Address |
|---|---|---|---|---|
| client | enp0s8 | 08:00:27:7c:3b:f6 | LAN_A | 10.10.1.10/24 |
| client | enp0s9 | 08:00:27:25:14:f6 | LINK_D | 10.10.4.2/30 |
| r1 | enp0s8 | 08:00:27:aa:36:9e | LAN_A | 10.10.1.1/24 |
| r1 | enp0s9 | 08:00:27:b7:15:e1 | LAN_B | 10.10.2.1/24 |
| r2 | enp0s8 | 08:00:27:cf:1d:c3 | LAN_B | 10.10.2.2/24 |
| r2 | enp0s9 | 08:00:27:fd:8f:5a | LAN_C | 10.10.3.1/24 |
| r2 | enp0s10 | 08:00:27:00:aa:35 | LINK_D | 10.10.4.1/30 |
| server | enp0s8 | 08:00:27:85:52:07 | LAN_C | 10.10.3.10/24 |

Script invocations:
- client: `sudo ./netcfg/client.sh enp0s8 enp0s9`
- r1:     `sudo ./netcfg/r1.sh enp0s8 enp0s9`
- r2:     `sudo ./netcfg/r2.sh enp0s8 enp0s9 enp0s10`
- server: `sudo ./netcfg/server.sh enp0s8`
