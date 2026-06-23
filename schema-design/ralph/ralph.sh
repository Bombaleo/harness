#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."   # harness/schema-design
MAX="${1:-50}"
for i in $(seq 1 "$MAX"); do
  echo "=== Ralph iteration $i ==="
  out="$(claude -p "$(cat ralph/CLAUDE.md)" --dangerously-skip-permissions 2>&1)" || true
  echo "$out"
  if echo "$out" | grep -q "<promise>COMPLETE</promise>"; then
    echo "All stories passed. Done."; exit 0
  fi
done
echo "Reached MAX=$MAX iterations without COMPLETE."; exit 1
