#!/usr/bin/env bash
# Regenerates the inputs/outputs section of every module and stage README with terraform-docs.
# With --check, fails if any README is out of date (used in CI and pre-commit).
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-}"
for d in $(scripts/tf-dirs.sh); do
  if [ "$mode" = "--check" ]; then
    terraform-docs --config .terraform-docs.yml --output-check "$d" >/dev/null || {
      echo "README out of date in $d; run: make docs" >&2
      exit 1
    }
  else
    terraform-docs --config .terraform-docs.yml "$d" >/dev/null
    echo "docs: $d/README.md"
  fi
done
