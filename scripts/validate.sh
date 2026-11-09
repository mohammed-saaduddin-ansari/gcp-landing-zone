#!/usr/bin/env bash
# terraform init (no backend, no credentials) + validate for every module and stage.
set -euo pipefail
cd "$(dirname "$0")/.."
status=0
for d in $(scripts/tf-dirs.sh); do
  printf '==> validate %s\n' "$d"
  if ! terraform -chdir="$d" init -backend=false -input=false -no-color >/dev/null; then
    terraform -chdir="$d" init -backend=false -input=false -no-color | tail -20
    status=1
    continue
  fi
  terraform -chdir="$d" validate -no-color || status=1
done
exit $status
