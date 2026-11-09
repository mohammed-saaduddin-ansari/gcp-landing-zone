#!/usr/bin/env bash
# Runs native `terraform test` suites. Every suite uses mock_provider, so no cloud credentials are needed.
# Usage: scripts/test.sh [dir ...]   (defaults to every module and stage that has a tests/ directory)
set -euo pipefail
cd "$(dirname "$0")/.."
dirs=("$@")
if [ ${#dirs[@]} -eq 0 ]; then
  for d in $(scripts/tf-dirs.sh); do
    [ -d "$d/tests" ] && dirs+=("$d")
  done
fi
status=0
for d in "${dirs[@]}"; do
  printf '==> test %s\n' "$d"
  terraform -chdir="$d" init -backend=false -input=false -no-color >/dev/null
  terraform -chdir="$d" test -no-color || status=1
done
exit $status
