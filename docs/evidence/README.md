# Evidence (screenshots from the VMs)

The VMs have no network and a read-only disc, so **screenshots are the only way results leave them**.
Run `clear` before each command; capture with ⌘⇧4 → Space → click the VM window; rename and move here.
Names: `<vm>-<what>.png` (vm = client, r1, r2, server, host). Commit after each phase.

| Where | What | Submitted? |
|---|---|---|
| `report/screenshots/R1`–`R6/` | the figures that go into report.pdf (handout §7.2) | inside report.pdf only |
| `docs/evidence/<phase>/` | proof each phase passed (test outputs, logs, probes) | no — for you, Claude and the viva |

Each folder's `CHECKLIST.md` lists the exact files expected there; tick them as you go.

| Folder | Phase (instructions.md) | Feeds report item |
|---|---|---|
| `phase2-netcfg/` | 2 Network configuration (M1) | R1, R2, R3 |
| `phase3-launch/` | 3 Launchers, RST suppression, offloads | R6 (background) |
| `phase8-driver/` | 8 Handshake, close, failure paths on VMs (M3) | — |
| `phase10-integration/` | 10 Client/server against real peers (M4) | R4, R5 |
| `phase11-congestion/` | 11 Congestion control on a bottleneck | R6 |
| `phase12-robustness/` | 12 Loss/reorder matrix, ISN wrap, GRO (M5) | R6 |
| `phase13-fairness/` | 13 Interop + fairness (M6) | R6 |
| `phase16-dryrun/` | 16 Packaging and grader dry run (M7) | — |
