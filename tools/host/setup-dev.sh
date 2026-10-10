#!/usr/bin/env bash
# usage: bash tools/host/setup-dev.sh
. "$(dirname "$0")/gnu-path.sh"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
PY=$(command -v python3.10 || true)
if [ -z "$PY" ]; then PY=$(command -v python3); echo "WARN: python3.10 not found, using $($PY --version); install 3.10 to match the grader"; fi
want=$("$PY" -c 'import sys; print("%d.%d" % sys.version_info[:2])')
have=$([ -x .venv/bin/python ] && .venv/bin/python -c 'import sys; print("%d.%d" % sys.version_info[:2])' || echo none)
if [ "$have" != "$want" ]; then
  [ "$have" = none ] || echo "rebuilding .venv: it has Python $have, wanted $want"
  rm -rf .venv
  "$PY" -m venv .venv
fi
.venv/bin/python -m pip install -q --upgrade pip
.venv/bin/python -m pip install -q -r tools/host/requirements-dev.txt
mkdir -p refcorpus scratch audit-out captures dist
find netcfg client server tools -type f \( -name '*.sh' -o -name 'run-*' -o -name 'pre-commit' \) -exec chmod +x {} +
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git config core.hooksPath tools/git-hooks
  git config core.autocrlf input
  echo "git: hooks path set to tools/git-hooks, autocrlf=input"
else
  echo "NOTE: not a git repo yet; run 'git init' (private remote!) and re-run this script"
fi
echo "venv: $(.venv/bin/python --version), $(.venv/bin/ruff --version)"
bash tools/host/check-host.sh || true
