# Test results

## Part A (2.4 / 12.2)
| Check | client | r1 | r2 | server | Date |
|---|---|---|---|---|---|
| netcfg selfcheck (all PASS) | 2/2 | 2/2 | 2/2 | 1/1 | 2026-10-12 |
| verify-routing pings | 7/7 | 6/6 | 7/7 | 6/6 | 2026-10-12 |
| traceroute | 10.10.1.1, 10.10.4.1, 10.10.3.10 | — | — | 10.10.3.1, 10.10.1.10 | 2026-10-12 |
| ping TTL seen | 63 (from server) | — | — | 62 (from client) | 2026-10-12 |
| rp_filter (non-1 values) | enp0s9 (LINK_D) = 2 | none | enp0s8 (LAN_B) = 2 | none | 2026-10-12 |
| forwarding on | none | enp0s8, enp0s9 | enp0s8, enp0s9, enp0s10 | none | 2026-10-12 |

## Transfers (6.6, 8.1, 11.1)
| File | Path impaired | Loss % | Reorder % | Delay | Result (md5) | Duration | Date |
|---|---|---|---|---|---|---|---|

## Failure paths (8.3)
| Scenario | Expected | Observed | Exit code |
|---|---|---|---|

## Fairness (11.2, 11.3)
| Bottleneck | Ours x N | curl x M | Our Mbit/s (each) | curl Mbit/s (each) | Ratio | Date |
|---|---|---|---|---|---|---|

## Server edge cases (10.4)
| server-edge.sh run | PASS | FAIL | Notes |
|---|---|---|---|
