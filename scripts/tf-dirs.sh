#!/usr/bin/env bash
# Prints every Terraform root this repository checks: each module and each environment stage.
set -euo pipefail
cd "$(dirname "$0")/.."
for d in modules/*/ envs/*/; do
  d="${d%/}"
  if ls "$d"/*.tf >/dev/null 2>&1; then echo "$d"; fi
done
