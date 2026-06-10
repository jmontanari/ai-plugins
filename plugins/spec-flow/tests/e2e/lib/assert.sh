# spec-flow e2e assertion core — sourced by run-e2e.sh

PASSES=0; FAILS=0; SKIPS=0; ERRORS=0

pass() { printf 'PASS — %s\n' "$1"; PASSES=$((PASSES + 1)); }
fail() { printf 'FAIL — %s\n' "$1"; FAILS=$((FAILS + 1)); }
skip_cap() { printf 'SKIPPED: %s — %s\n' "$1" "$2"; SKIPS=$((SKIPS + 1)); }   # $1 ∈ live-run|transcript|metrics-artifact
err() { printf 'ERROR — %s\n' "$1" >&2; ERRORS=$((ERRORS + 1)); }
excluded() { printf 'EXCLUDED — %s\n' "$1"; }                                  # informational, not counted

summary() {
  printf '== summary: %s passed, %s failed, %s skipped, %s errors ==\n' "$PASSES" "$FAILS" "$SKIPS" "$ERRORS"
  [ "$FAILS" -eq 0 ] && [ "$ERRORS" -eq 0 ] && return 0; return 1
}

# assert_exit <want> <label> -- <command...>
assert_exit() {
  local want="$1" label="$2"; shift 3
  "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" -eq "$want" ]; then pass "${label} (exit ${got})"; else fail "${label} (want ${want}, got ${got})"; fi
}

# assert_grep <pattern> <file> <label>  — ERE, grep -E -q
assert_grep() {
  local pattern="$1" file="$2" label="$3"
  if grep -E -q "$pattern" "$file" 2>/dev/null; then pass "$label"; else fail "$label (pattern not found: $pattern)"; fi
}

# assert_no_grep <pattern> <file> <label>
assert_no_grep() {
  local pattern="$1" file="$2" label="$3"
  if grep -E -q "$pattern" "$file" 2>/dev/null; then fail "$label (unexpected pattern present: $pattern)"; else pass "$label"; fi
}

# assert_file <path> <label>  — exists + non-empty → pass
assert_file() {
  local path="$1" label="$2"
  if [ -s "$path" ]; then pass "$label"; else fail "$label (file missing or empty: $path)"; fi
}

# assert_count <pattern> <file> <want> <label>  — grep -E -c equals want
assert_count() {
  local pattern="$1" file="$2" want="$3" label="$4"
  [ -f "$file" ] || { fail "$label (file missing: $file)"; return; }
  local got
  got=$(grep -E -c "$pattern" "$file" 2>/dev/null || true)
  if [ "$got" -eq "$want" ]; then pass "$label (count ${got})"; else fail "$label (want ${want}, got ${got})"; fi
}

# assert_subject_order <repo> <prefixA> <prefixB> <label>
# Passes iff both prefixes found AND first occurrence of A precedes first occurrence of B.
assert_subject_order() {
  local repo="$1" prefixA="$2" prefixB="$3" label="$4"
  local log lineA lineB
  log=$(git -C "$repo" log --reverse --format=%s 2>/dev/null)
  lineA=$(printf '%s\n' "$log" | awk -v t="$prefixA" 'index($0, t) == 1 { print NR; exit }')
  lineB=$(printf '%s\n' "$log" | awk -v t="$prefixB" 'index($0, t) == 1 { print NR; exit }')
  if [ -z "$lineA" ]; then
    fail "$label (prefix not found: $prefixA)"
  elif [ -z "$lineB" ]; then
    fail "$label (prefix not found: $prefixB)"
  elif [ "$lineA" -lt "$lineB" ]; then
    pass "$label"
  else
    fail "$label (misordered: '$prefixA' (line $lineA) not before '$prefixB' (line $lineB))"
  fi
}

# Capability probes — single flip point per spec Technical Approach
have_golden() { [ -s "${E2E_DIR:-}/golden/footprint.txt" ]; }
have_transcript() { [ -n "${TRANSCRIPT:-}" ] && [ -s "$TRANSCRIPT" ]; }
have_metrics_artifact() { [ -s "${1:-}/metrics.yaml" ]; }   # $1 = piece dir; flips real when FR-010 ships its path

# Temp helper — NN-C-006 confinement: all rm -rf in the suite goes through this pair
e2e_mktemp() { mktemp -d 2>/dev/null || { local d="/tmp/e2e-$$-$RANDOM"; mkdir -p "$d"; echo "$d"; }; }
e2e_cleanup() { case "$1" in /tmp/*|/private/*|/var/folders/*) rm -rf "$1" ;; *) err "refusing cleanup outside tmp: $1" ;; esac; }
