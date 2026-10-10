# Interface map (fill in setup.md S7)

## Hypervisor networks
| Network | Fusion custom network (Apple Silicon) | VirtualBox internal network (x86) |
|---|---|---|
| LAN_A | vmnet2 | LAN_A |
| LAN_B | vmnet3 | LAN_B |
| LAN_C | vmnet4 | LAN_C |
| LINK_D | vmnet5 | LINK_D |


| VM | Interface | MAC | Network | Address |
|---|---|---|---|---|
| client | | | LAN_A | 10.10.1.10/24 |
| client | | | LINK_D | 10.10.4.2/30 |
| r1 | | | LAN_A | 10.10.1.1/24 |
| r1 | | | LAN_B | 10.10.2.1/24 |
| r2 | | | LAN_B | 10.10.2.2/24 |
| r2 | | | LAN_C | 10.10.3.1/24 |
| r2 | | | LINK_D | 10.10.4.1/30 |
| server | | | LAN_C | 10.10.3.10/24 |

Script invocations (fill in names):
- client: `sudo ./netcfg/client.sh <IF_A> <IF_D>`
- r1:     `sudo ./netcfg/r1.sh <IF_A> <IF_B>`
- r2:     `sudo ./netcfg/r2.sh <IF_B> <IF_C> <IF_D>`
- server: `sudo ./netcfg/server.sh <IF_C>`
