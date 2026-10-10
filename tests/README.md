# Tests (NOT submitted)

Run unit tests (Python 3.10, stdlib unittest):
    bash tools/test/run-unit.sh

Layout (SPEC §6):
- `tests/unit/test_*.py`: per-module unit tests, one file per SPEC item group
  (checksum, seqspace, codecs, ingress gates, logline, inbound, outbound, rto, congestion,
  endpoint, listener, parsing, urlparts, fetch, serve, content).
- `tests/fakes.py` (Step 5.1): fake stream implementing SPEC contract C4 exactly.
- `tests/harness/` (Step 5.2): simulation harness, virtual clock, lossy/reordering/duplicating
  channel with optional bottleneck, scenario library (SPEC APP-4b). Phase 6 is "done" when every
  scenario passes.

Rules:
- HTTP code is tested through `tests/fakes.py`, never kernel sockets.
- Core code is tested through the harness or direct event/action calls, never raw sockets.
- Real-network tests live in `tools/test/` and run on the VMs (instructions.md Part II).
