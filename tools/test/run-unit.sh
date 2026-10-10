#!/usr/bin/env bash
# usage: bash tools/test/run-unit.sh
. "$(dirname "$0")/../host/gnu-path.sh"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
PY=.venv/bin/python; [ -x "$PY" ] || PY=python3
if ! ls tests/unit/test_*.py >/dev/null 2>&1; then echo "no unit tests yet"; exit 0; fi
PYTHONPATH="${A3_SRC:-src}:tests:tests/unit" "$PY" -B -m unittest discover -s tests/unit -t tests/unit "$@"
