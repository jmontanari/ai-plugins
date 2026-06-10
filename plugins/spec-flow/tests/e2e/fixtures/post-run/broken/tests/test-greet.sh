#!/usr/bin/env bash
# test-greet.sh — oracle tests for greet utility (post-run broken: missing spike oracle)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../src/greet.sh"

pass=0; fail=0
check() {
  local label="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then
    printf 'PASS — %s\n' "$label"; pass=$((pass+1))
  else
    printf 'FAIL — %s (got=%s want=%s)\n' "$label" "$got" "$want"; fail=$((fail+1))
  fi
}

# NOTE: rt-1 spike oracle NOT transcribed here — round-trip defect
check "g-1 greet world" "$(greet world)" "hello, world"

printf '== %s passed, %s failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
