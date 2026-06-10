#!/usr/bin/env bash
# test-manifest-query.sh — golden-output test harness for manifest-query (awk path)
#
# All assertions run with MANIFEST_QUERY_NO_PY=1 to force the awk/bash path.
# Exit 0 only if every assertion passes.

set -euo pipefail

export MANIFEST_QUERY_NO_PY=1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="${SCRIPT_DIR}/fixtures"
SCRIPT="${SCRIPT_DIR}/../manifest-query"
EXEC_READY="${FIXTURE_DIR}/exec-ready.yaml"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$(( PASS + 1 )); }
fail() { echo "  FAIL: $1"; FAIL=$(( FAIL + 1 )); }

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$label"
  else
    fail "$label"
    printf '    expected:\n'
    echo "$expected" | head -5 | sed 's/^/      /'
    printf '    actual:\n'
    echo "$actual"   | head -5 | sed 's/^/      /'
  fi
}

assert_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    pass "$label"
  else
    fail "$label"
    echo "    expected to contain: '$needle'"
    echo "$haystack" | head -5 | sed 's/^/      actual: /'
  fi
}

assert_nonzero_exit() {
  local label="$1"
  local exit_code="$2"
  if [ "$exit_code" -ne 0 ]; then
    pass "$label"
  else
    fail "$label (expected non-zero exit, got 0)"
  fi
}

# portable mktemp: create a temp file without path/extension constraints
make_tmpfile() {
  mktemp
}

# safe diff: returns the diff output without triggering set -e on differences
safe_diff() {
  diff "$1" "$2" || true
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
echo "=== manifest-query golden tests (awk path, MANIFEST_QUERY_NO_PY=1) ==="
echo ""

if [ ! -f "$SCRIPT" ]; then
  echo "FATAL: script not found: $SCRIPT" >&2
  exit 1
fi
if [ ! -f "$EXEC_READY" ]; then
  echo "FATAL: fixture not found: $EXEC_READY" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# T-4: open
# ---------------------------------------------------------------------------
echo "--- T-4: open ---"

OPEN_OUT="$(bash "$SCRIPT" open --file "$EXEC_READY")"
OPEN_EXPECTED="$(printf 'spec-preresearch\nflywheel-repo\nflywheel-global')"

assert_eq "open: exactly spec-preresearch, flywheel-repo, flywheel-global (in order)" \
  "$OPEN_EXPECTED" "$OPEN_OUT"

# Verify merged pieces are NOT in open output
for merged_slug in research-unify plan-concrete test-data-up sonnet-coord spike-agent; do
  if echo "$OPEN_OUT" | grep -qx "$merged_slug"; then
    fail "open: merged slug '$merged_slug' should not appear in open output"
  else
    pass "open: merged slug '$merged_slug' correctly excluded"
  fi
done

echo ""

# ---------------------------------------------------------------------------
# T-4: deps (forward)
# ---------------------------------------------------------------------------
echo "--- T-4: deps spike-agent ---"

DEPS_OUT="$(bash "$SCRIPT" deps spike-agent --file "$EXEC_READY")"
DEPS_EXPECTED="$(printf 'plan-concrete\nsonnet-coord')"
assert_eq "deps spike-agent: plan-concrete, sonnet-coord" "$DEPS_EXPECTED" "$DEPS_OUT"

echo ""

# ---------------------------------------------------------------------------
# F2: deps on a piece with dependencies: [] must produce empty output
# ---------------------------------------------------------------------------
echo "--- F2: deps research-unify (empty deps: []) ---"

EMPTY_DEPS_OUT="$(bash "$SCRIPT" deps research-unify --file "$EXEC_READY")"
assert_eq "deps research-unify: must be empty (dependencies: [])" "" "$EMPTY_DEPS_OUT"

echo ""

# ---------------------------------------------------------------------------
# T-4: deps --reverse
# ---------------------------------------------------------------------------
echo "--- T-4: deps research-unify --reverse ---"

RDEPS_OUT="$(bash "$SCRIPT" deps research-unify --reverse --file "$EXEC_READY")"

# Exact-set check: exactly plan-concrete and spec-preresearch, nothing else
RDEPS_EXPECTED="$(printf 'plan-concrete\nspec-preresearch')"
assert_eq "deps research-unify --reverse: exactly plan-concrete and spec-preresearch" \
  "$RDEPS_EXPECTED" "$RDEPS_OUT"

# Phantom check: research-unify itself must NOT appear (it has prd_sections containing tokens
# that could match if prd_sections were confused with deps — this verifies no phantom)
if echo "$RDEPS_OUT" | grep -qx "research-unify"; then
  fail "deps --reverse: research-unify must not list itself as a reverse-dep (phantom)"
else
  pass "deps --reverse: research-unify absent from its own reverse-deps (no phantom)"
fi

# Phantom check: pieces whose prd_sections mention FR-001 (same token as research-unify's
# prd_sections) must NOT appear in deps research-unify --reverse unless they actually depend on it.
# spike-agent has prd_sections: [FR-005, FR-008, G-2, G-3] — no overlap; it also does NOT depend
# on research-unify. Confirm it is absent.
if echo "$RDEPS_OUT" | grep -qx "spike-agent"; then
  fail "deps --reverse: spike-agent must not appear (it does not depend on research-unify)"
else
  pass "deps --reverse: spike-agent correctly absent (prd_sections match ≠ dependency)"
fi

echo ""

# ---------------------------------------------------------------------------
# T-4: ready
# ---------------------------------------------------------------------------
echo "--- T-4: ready ---"

READY_OUT="$(bash "$SCRIPT" ready --file "$EXEC_READY")"
READY_EXPECTED="flywheel-repo"
assert_eq "ready: exactly flywheel-repo" "$READY_EXPECTED" "$READY_OUT"

# Confirm flywheel-global is excluded (its dep flywheel-repo is not merged)
if echo "$READY_OUT" | grep -qx "flywheel-global"; then
  fail "ready: flywheel-global should be excluded (dep flywheel-repo not merged)"
else
  pass "ready: flywheel-global correctly excluded"
fi

# Confirm spec-preresearch is excluded (status is specced, not open)
if echo "$READY_OUT" | grep -qx "spec-preresearch"; then
  fail "ready: spec-preresearch should be excluded (status=specced, not open)"
else
  pass "ready: spec-preresearch correctly excluded (not open)"
fi

echo ""

# ---------------------------------------------------------------------------
# T-4: table
# ---------------------------------------------------------------------------
echo "--- T-4: table ---"

TABLE_OUT="$(bash "$SCRIPT" table --file "$EXEC_READY")"

# Header row must be present
assert_contains "table: header 'slug' column" "slug" "$TABLE_OUT"
assert_contains "table: header 'status' column" "status" "$TABLE_OUT"
assert_contains "table: header 'deps' column" "deps" "$TABLE_OUT"
assert_contains "table: header 'prd_sections' column" "prd_sections" "$TABLE_OUT"

# Count data rows (total rows minus header row minus separator row)
TOTAL_LINES="$(echo "$TABLE_OUT" | wc -l | tr -d ' ')"
# 2 header lines (header + separator) + 8 data rows = 10
DATA_ROWS=$(( TOTAL_LINES - 2 ))
if [ "$DATA_ROWS" -eq 8 ]; then
  pass "table: 8 data rows"
else
  fail "table: expected 8 data rows, got $DATA_ROWS (total lines: $TOTAL_LINES)"
  echo "$TABLE_OUT"
fi

# Check that all slugs appear in the table
for chk_slug in research-unify plan-concrete sonnet-coord spike-agent spec-preresearch flywheel-repo flywheel-global; do
  assert_contains "table: contains slug '$chk_slug'" "$chk_slug" "$TABLE_OUT"
done

echo ""

# ---------------------------------------------------------------------------
# T-5: set-status mutation
# ---------------------------------------------------------------------------
echo "--- T-5: set-status mutation ---"

# Create a temp copy of the fixture
TMPFILE="$(make_tmpfile)"
cp "$EXEC_READY" "$TMPFILE"

# Set flywheel-repo to specced
bash "$SCRIPT" set-status flywheel-repo specced --file "$TMPFILE"

# Verify the new status via re-parse: flywheel-repo should now be specced (non-merged, in open)
OPEN_AFTER="$(bash "$SCRIPT" open --file "$TMPFILE")"
if echo "$OPEN_AFTER" | grep -qx "flywheel-repo"; then
  pass "set-status: flywheel-repo appears in open (specced is non-merged)"
else
  fail "set-status: flywheel-repo missing from non-merged list after set-status specced"
fi

# flywheel-repo should NOT be in ready (status is now specced, not open)
READY_AFTER="$(bash "$SCRIPT" ready --file "$TMPFILE")"
if echo "$READY_AFTER" | grep -qx "flywheel-repo"; then
  fail "set-status: flywheel-repo should NOT be in ready (status is now specced, not open)"
else
  pass "set-status: flywheel-repo correctly absent from ready (status=specced)"
fi

# Diff should show exactly one changed line
DIFF_OUT="$(safe_diff "$EXEC_READY" "$TMPFILE")"
DIFF_LINES="$(echo "$DIFF_OUT" | grep '^[<>]' | wc -l | tr -d ' ')"
if [ "$DIFF_LINES" -eq 2 ]; then
  # diff shows < old and > new, so 2 lines for 1 changed line
  pass "set-status: diff shows exactly one changed line (< old + > new)"
elif [ "$DIFF_LINES" -eq 1 ]; then
  pass "set-status: diff shows exactly one changed line"
else
  fail "set-status: diff shows $DIFF_LINES lines changed (expected 2: one < and one >)"
  echo "$DIFF_OUT" | head -10 | sed 's/^/    /'
fi

# Verify the changed line is the status line for flywheel-repo
if echo "$DIFF_OUT" | grep -q 'status: specced'; then
  pass "set-status: changed line contains 'status: specced'"
else
  fail "set-status: changed line does not contain 'status: specced'"
  echo "$DIFF_OUT" | sed 's/^/    /'
fi

rm -f "$TMPFILE"

echo ""

# ---------------------------------------------------------------------------
# T-5: bogus-slug leaves file byte-identical
# ---------------------------------------------------------------------------
echo "--- T-5: bogus-slug error handling ---"

TMPFILE2="$(make_tmpfile)"
cp "$EXEC_READY" "$TMPFILE2"

# md5: macOS uses `md5 -q`, Linux uses `md5sum`
ORIG_CHECKSUM="$(md5 -q "$TMPFILE2" 2>/dev/null || md5sum "$TMPFILE2" | awk '{print $1}')"

# bogus-slug should exit non-zero and write nothing
BOGUS_EXIT=0
bash "$SCRIPT" set-status bogus-slug specced --file "$TMPFILE2" 2>/dev/null || BOGUS_EXIT=$?
assert_nonzero_exit "bogus-slug: exits non-zero" "$BOGUS_EXIT"

NEW_CHECKSUM="$(md5 -q "$TMPFILE2" 2>/dev/null || md5sum "$TMPFILE2" | awk '{print $1}')"
if [ "$ORIG_CHECKSUM" = "$NEW_CHECKSUM" ]; then
  pass "bogus-slug: file is byte-identical after failed set-status"
else
  fail "bogus-slug: file was modified despite bogus slug"
fi

rm -f "$TMPFILE2"

echo ""

# ---------------------------------------------------------------------------
# T-5: unknown status validation
# ---------------------------------------------------------------------------
echo "--- T-5: invalid status value error handling ---"

TMPFILE3="$(make_tmpfile)"
cp "$EXEC_READY" "$TMPFILE3"

ORIG_CHECKSUM3="$(md5 -q "$TMPFILE3" 2>/dev/null || md5sum "$TMPFILE3" | awk '{print $1}')"

INVALID_EXIT=0
bash "$SCRIPT" set-status flywheel-repo not-a-real-status --file "$TMPFILE3" 2>/dev/null || INVALID_EXIT=$?
assert_nonzero_exit "invalid-status: exits non-zero" "$INVALID_EXIT"

NEW_CHECKSUM3="$(md5 -q "$TMPFILE3" 2>/dev/null || md5sum "$TMPFILE3" | awk '{print $1}')"
if [ "$ORIG_CHECKSUM3" = "$NEW_CHECKSUM3" ]; then
  pass "invalid-status: file is byte-identical after failed set-status"
else
  fail "invalid-status: file was modified despite invalid status"
fi

rm -f "$TMPFILE3"

echo ""

# ---------------------------------------------------------------------------
# Fixtures smoke-test: shared and prop-firm parse without crashing
# ---------------------------------------------------------------------------
echo "--- Fixture smoke tests ---"

for fixture_name in shared prop-firm; do
  fixture="${FIXTURE_DIR}/${fixture_name}.yaml"
  if [ ! -f "$fixture" ]; then
    fail "fixture exists: ${fixture_name}.yaml"
    continue
  fi
  # open and table should both succeed (exit 0)
  if bash "$SCRIPT" open --file "$fixture" > /dev/null 2>&1; then
    pass "smoke: ${fixture_name} open exits 0"
  else
    fail "smoke: ${fixture_name} open exits non-zero"
  fi
  if bash "$SCRIPT" table --file "$fixture" > /dev/null 2>&1; then
    pass "smoke: ${fixture_name} table exits 0"
  else
    fail "smoke: ${fixture_name} table exits non-zero"
  fi
done

echo ""

# ---------------------------------------------------------------------------
# F3+F4: prop-firm correctness — depends_on: alias + block-style lists
# ---------------------------------------------------------------------------
echo "--- F3+F4: prop-firm deps correctness ---"

PROP_FIRM="${FIXTURE_DIR}/prop-firm.yaml"

if [ -f "$PROP_FIRM" ]; then
  # phase-0b has depends_on: [] — must produce empty output
  PROP_EMPTY_OUT="$(bash "$SCRIPT" deps phase-0b --file "$PROP_FIRM")"
  assert_eq "prop-firm deps phase-0b (depends_on: []): must be empty" "" "$PROP_EMPTY_OUT"

  # phase-0c has block-style depends_on: with one item (phase-0b-historical-adapters)
  PROP_0C_OUT="$(bash "$SCRIPT" deps phase-0c --file "$PROP_FIRM")"
  assert_eq "prop-firm deps phase-0c (block-style depends_on): phase-0b-historical-adapters" \
    "phase-0b-historical-adapters" "$PROP_0C_OUT"

  # reverse: phase-0b-historical-adapters (the dep value, not the slug) should list phase-0c
  # as a dependent — but only if that value is used; test via forward direction only (the
  # dep strings are name references in prop-firm, not slugs, so --reverse is not applicable
  # here without a matching piece slug). Confirm phase-0c forward deps correct is sufficient.

  # phase-2-6 has block-style depends_on: [phase-2-live-ingester]
  PROP_26_OUT="$(bash "$SCRIPT" deps phase-2-6 --file "$PROP_FIRM")"
  assert_eq "prop-firm deps phase-2-6 (block-style single dep): phase-2-live-ingester" \
    "phase-2-live-ingester" "$PROP_26_OUT"

  # ready on prop-firm: must exit 0 and produce consistent output (already tested by smoke;
  # here we check that pieces with block-style depends_on are correctly evaluated)
  PROP_READY_OUT="$(bash "$SCRIPT" ready --file "$PROP_FIRM")"
  # news-no-lookahead-enforcement is known open with all deps merged — it must appear
  if echo "$PROP_READY_OUT" | grep -qx "news-no-lookahead-enforcement"; then
    pass "prop-firm ready: news-no-lookahead-enforcement correctly listed (all deps merged)"
  else
    fail "prop-firm ready: news-no-lookahead-enforcement missing (dep resolution may be broken)"
  fi
else
  fail "prop-firm fixture missing: $PROP_FIRM"
fi

echo ""

# ---------------------------------------------------------------------------
# Error cases
# ---------------------------------------------------------------------------
echo "--- Error handling ---"

# Missing --file
NOFLAG_EXIT=0
bash "$SCRIPT" open 2>/dev/null || NOFLAG_EXIT=$?
if [ "$NOFLAG_EXIT" -eq 64 ]; then
  pass "missing --file: exits 64"
else
  fail "missing --file: expected exit 64, got $NOFLAG_EXIT"
fi

# Unknown subcommand
UNK_EXIT=0
bash "$SCRIPT" foobar --file "$EXEC_READY" 2>/dev/null || UNK_EXIT=$?
if [ "$UNK_EXIT" -eq 64 ]; then
  pass "unknown subcommand: exits 64"
else
  fail "unknown subcommand: expected exit 64, got $UNK_EXIT"
fi

# Unknown slug for deps
UNKSLUG_EXIT=0
bash "$SCRIPT" deps totally-unknown-slug --file "$EXEC_READY" 2>/dev/null || UNKSLUG_EXIT=$?
assert_nonzero_exit "unknown slug (deps): exits non-zero" "$UNKSLUG_EXIT"

echo ""

# ---------------------------------------------------------------------------
# T-2 (Phase 2): Python fast-path parity — py output == awk output, byte-for-byte
# ---------------------------------------------------------------------------
echo "--- T-2: Python fast-path parity (py vs awk, all subcommands × all fixtures) ---"

SCRIPT_PY="${SCRIPT_DIR}/../manifest-query.py"

if [ ! -f "$SCRIPT_PY" ]; then
  fail "parity: manifest-query.py not found at $SCRIPT_PY"
else

  # assert_parity <label> <fixture_path> <subcmd_and_args...>
  # Runs the awk path (MANIFEST_QUERY_NO_PY=1) and the python path, diffs stdout.
  # For set-status: copies the fixture to a temp file for each path and diffs
  # the resulting files instead of stdout.
  assert_parity() {
    local label="$1"
    local fixture="$2"
    shift 2
    # remaining args are the subcommand + its arguments (no --file)
    local py_out awk_out
    py_out="$(python3 "$SCRIPT_PY" "$@" --file "$fixture" 2>&1)"
    awk_out="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" "$@" --file "$fixture" 2>&1)"
    if [ "$py_out" = "$awk_out" ]; then
      pass "$label"
    else
      fail "$label"
      diff <(printf '%s\n' "$awk_out") <(printf '%s\n' "$py_out") | head -10 | sed 's/^/    /'
    fi
  }

  assert_setstatus_parity() {
    local label="$1"
    local fixture="$2"
    shift 2
    local tmp_awk tmp_py
    tmp_awk="$(mktemp)"
    tmp_py="$(mktemp)"
    cp "$fixture" "$tmp_awk"
    cp "$fixture" "$tmp_py"
    MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" set-status "$@" --file "$tmp_awk" 2>/dev/null || true
    python3 "$SCRIPT_PY" set-status "$@" --file "$tmp_py" 2>/dev/null || true
    if diff "$tmp_awk" "$tmp_py" > /dev/null 2>&1; then
      pass "$label"
    else
      fail "$label"
      diff "$tmp_awk" "$tmp_py" | head -10 | sed 's/^/    /'
    fi
    rm -f "$tmp_awk" "$tmp_py"
  }

  SHARED="${FIXTURE_DIR}/shared.yaml"
  PROP_FIRM="${FIXTURE_DIR}/prop-firm.yaml"

  # --- exec-ready fixture ---
  assert_parity "parity exec-ready: open" "$EXEC_READY" open
  assert_parity "parity exec-ready: deps spike-agent" "$EXEC_READY" deps spike-agent
  assert_parity "parity exec-ready: deps research-unify (empty)" "$EXEC_READY" deps research-unify
  assert_parity "parity exec-ready: deps research-unify --reverse" "$EXEC_READY" deps research-unify --reverse
  assert_parity "parity exec-ready: ready" "$EXEC_READY" ready
  assert_parity "parity exec-ready: table" "$EXEC_READY" table
  assert_setstatus_parity "parity exec-ready: set-status flywheel-repo specced" "$EXEC_READY" flywheel-repo specced
  assert_setstatus_parity "parity exec-ready: set-status bogus-slug (error path)" "$EXEC_READY" bogus-slug specced

  # --- set-status parity: no-trailing-newline manifest ---
  # Generate a temp fixture with the final newline stripped (printf '%s' strips it).
  # Both awk and python must produce byte-identical output.
  _notail_fixture="$(mktemp)"
  printf '%s' "$(cat "$EXEC_READY")" > "$_notail_fixture"
  assert_setstatus_parity "parity set-status no-trailing-newline: flywheel-repo specced" \
    "$_notail_fixture" flywheel-repo specced
  rm -f "$_notail_fixture"

  # --- set-status parity: CRLF manifest ---
  # Generate a temp CRLF fixture (sed appends \r before each \n).
  # awk keeps \r\n on untouched lines, strips \r only on the rewritten status line.
  # Python must replicate that exactly.
  _crlf_fixture="$(mktemp)"
  sed 's/$/\r/' "$EXEC_READY" > "$_crlf_fixture"
  assert_setstatus_parity "parity set-status CRLF: flywheel-repo specced" \
    "$_crlf_fixture" flywheel-repo specced
  rm -f "$_crlf_fixture"

  # --- shared fixture ---
  if [ -f "$SHARED" ]; then
    assert_parity "parity shared: open" "$SHARED" open
    assert_parity "parity shared: ready" "$SHARED" ready
    assert_parity "parity shared: table" "$SHARED" table
    # deps on a piece with empty deps (inline [])
    assert_parity "parity shared: deps spec-flow-v2.0.0 (empty [])" "$SHARED" deps spec-flow-v2.0.0
  else
    fail "parity shared: fixture missing"
  fi

  # --- prop-firm fixture (block-style depends_on:) ---
  if [ -f "$PROP_FIRM" ]; then
    assert_parity "parity prop-firm: open" "$PROP_FIRM" open
    assert_parity "parity prop-firm: deps phase-0b (depends_on: [])" "$PROP_FIRM" deps phase-0b
    assert_parity "parity prop-firm: deps phase-0c (block-style single dep)" "$PROP_FIRM" deps phase-0c
    assert_parity "parity prop-firm: deps phase-2-6 (block-style single dep)" "$PROP_FIRM" deps phase-2-6
    assert_parity "parity prop-firm: ready" "$PROP_FIRM" ready
    assert_parity "parity prop-firm: table" "$PROP_FIRM" table
  else
    fail "parity prop-firm: fixture missing"
  fi

fi

echo ""

# ---------------------------------------------------------------------------
# T-3 (Phase 3): Dispatch-parity — auto-dispatched (guard) vs awk forced
#
# Asserts that the dispatch guard in manifest-query correctly exec-s the python
# path when python3 is present, and that the output is byte-identical to the
# awk path forced with MANIFEST_QUERY_NO_PY=1.
#
# The outer block still has MANIFEST_QUERY_NO_PY=1 exported globally, so we
# must explicitly unset it for the python-dispatched calls and restore it.
# ---------------------------------------------------------------------------
echo "--- T-3: dispatch-parity (guard auto-dispatch vs awk forced, all subcommands × fixtures) ---"

# Unset the global MANIFEST_QUERY_NO_PY so the guard fires for the "python path" side.
# We restore it at the end of this block.
unset MANIFEST_QUERY_NO_PY

assert_dispatch_parity() {
  local label="$1"
  local fixture="$2"
  shift 2
  # remaining args: subcommand + its arguments (no --file)
  local py_dispatch_out awk_out
  # python auto-dispatch (guard fires): no MANIFEST_QUERY_NO_PY
  py_dispatch_out="$(bash "$SCRIPT" "$@" --file "$fixture" 2>&1)"
  # awk forced
  awk_out="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" "$@" --file "$fixture" 2>&1)"
  if [ "$py_dispatch_out" = "$awk_out" ]; then
    pass "$label"
  else
    fail "$label"
    diff <(printf '%s\n' "$awk_out") <(printf '%s\n' "$py_dispatch_out") | head -10 | sed 's/^/    /'
  fi
}

assert_dispatch_setstatus_parity() {
  local label="$1"
  local fixture="$2"
  shift 2
  local tmp_dispatch tmp_awk
  tmp_dispatch="$(mktemp)"
  tmp_awk="$(mktemp)"
  cp "$fixture" "$tmp_dispatch"
  cp "$fixture" "$tmp_awk"
  bash "$SCRIPT" set-status "$@" --file "$tmp_dispatch" 2>/dev/null || true
  MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" set-status "$@" --file "$tmp_awk" 2>/dev/null || true
  if diff "$tmp_dispatch" "$tmp_awk" > /dev/null 2>&1; then
    pass "$label"
  else
    fail "$label"
    diff "$tmp_dispatch" "$tmp_awk" | head -10 | sed 's/^/    /'
  fi
  rm -f "$tmp_dispatch" "$tmp_awk"
}

# --- exec-ready fixture: all subcommands ---
assert_dispatch_parity "dispatch-parity exec-ready: open" "$EXEC_READY" open
assert_dispatch_parity "dispatch-parity exec-ready: deps spike-agent" "$EXEC_READY" deps spike-agent
assert_dispatch_parity "dispatch-parity exec-ready: deps research-unify (empty)" "$EXEC_READY" deps research-unify
assert_dispatch_parity "dispatch-parity exec-ready: deps research-unify --reverse" "$EXEC_READY" deps research-unify --reverse
assert_dispatch_parity "dispatch-parity exec-ready: ready" "$EXEC_READY" ready
assert_dispatch_parity "dispatch-parity exec-ready: table" "$EXEC_READY" table
assert_dispatch_setstatus_parity "dispatch-parity exec-ready: set-status flywheel-repo specced" "$EXEC_READY" flywheel-repo specced

# --- shared fixture ---
SHARED_D="${FIXTURE_DIR}/shared.yaml"
if [ -f "$SHARED_D" ]; then
  assert_dispatch_parity "dispatch-parity shared: open" "$SHARED_D" open
  assert_dispatch_parity "dispatch-parity shared: ready" "$SHARED_D" ready
  assert_dispatch_parity "dispatch-parity shared: table" "$SHARED_D" table
else
  fail "dispatch-parity shared: fixture missing"
fi

# --- prop-firm fixture ---
PROP_FIRM_D="${FIXTURE_DIR}/prop-firm.yaml"
if [ -f "$PROP_FIRM_D" ]; then
  assert_dispatch_parity "dispatch-parity prop-firm: open" "$PROP_FIRM_D" open
  assert_dispatch_parity "dispatch-parity prop-firm: deps phase-0b (depends_on: [])" "$PROP_FIRM_D" deps phase-0b
  assert_dispatch_parity "dispatch-parity prop-firm: deps phase-0c (block-style single dep)" "$PROP_FIRM_D" deps phase-0c
  assert_dispatch_parity "dispatch-parity prop-firm: ready" "$PROP_FIRM_D" ready
  assert_dispatch_parity "dispatch-parity prop-firm: table" "$PROP_FIRM_D" table
else
  fail "dispatch-parity prop-firm: fixture missing"
fi

# --- Assert awk fallback (MANIFEST_QUERY_NO_PY=1) still exits 0 and produces correct output ---
# This simulates "python3 absent" and confirms the bash fallback is intact.
FALLBACK_OPEN="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" open --file "$EXEC_READY")"
FALLBACK_EXPECTED="$(printf 'spec-preresearch\nflywheel-repo\nflywheel-global')"
assert_eq "dispatch: awk fallback (MANIFEST_QUERY_NO_PY=1) exits 0 and produces correct open output" \
  "$FALLBACK_EXPECTED" "$FALLBACK_OPEN"

FALLBACK_READY="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" ready --file "$EXEC_READY")"
assert_eq "dispatch: awk fallback ready produces flywheel-repo" "flywheel-repo" "$FALLBACK_READY"

# Restore global env var so remaining code (if any) behaves as before.
export MANIFEST_QUERY_NO_PY=1

echo ""

# ---------------------------------------------------------------------------
# M1: set-status against a manifest OUTSIDE $TMPDIR (cross-device temp safety)
# Create the manifest under the repo/cwd, not in $TMPDIR.
# ---------------------------------------------------------------------------
echo "--- M1: set-status cross-device temp (manifest in repo subdir) ---"

M1_WORKDIR="$(CDPATH= cd -- "$SCRIPT_DIR" && pwd)/../../../.."
M1_TMPDIR="$(mktemp -d "${M1_WORKDIR}/.mq-test-XXXXXX")"
M1_MANIFEST="${M1_TMPDIR}/manifest.yaml"
cp "$EXEC_READY" "$M1_MANIFEST"

M1_EXIT=0
bash "$SCRIPT" set-status flywheel-repo specced --file "$M1_MANIFEST" || M1_EXIT=$?
if [ "$M1_EXIT" -eq 0 ]; then
  pass "M1: set-status on out-of-TMPDIR manifest exits 0"
else
  fail "M1: set-status on out-of-TMPDIR manifest exited $M1_EXIT (cross-device?)"
fi

M1_STATUS_OUT="$(bash "$SCRIPT" open --file "$M1_MANIFEST" 2>/dev/null)"
if echo "$M1_STATUS_OUT" | grep -qx "flywheel-repo"; then
  pass "M1: flywheel-repo appears in open after set-status specced (out-of-TMPDIR)"
else
  fail "M1: flywheel-repo missing from open after set-status on out-of-TMPDIR manifest"
fi

# Python path parity for M1
M1_PY_MANIFEST="${M1_TMPDIR}/manifest-py.yaml"
cp "$EXEC_READY" "$M1_PY_MANIFEST"
M1_PY_EXIT=0
python3 "$SCRIPT_PY" set-status flywheel-repo specced --file "$M1_PY_MANIFEST" || M1_PY_EXIT=$?
if [ "$M1_PY_EXIT" -eq 0 ]; then
  pass "M1 (py): set-status on out-of-TMPDIR manifest exits 0"
else
  fail "M1 (py): set-status on out-of-TMPDIR manifest exited $M1_PY_EXIT"
fi
if diff "$M1_MANIFEST" "$M1_PY_MANIFEST" > /dev/null 2>&1; then
  pass "M1: bash and python produce identical file after out-of-TMPDIR set-status"
else
  fail "M1: bash and python differ after out-of-TMPDIR set-status"
  diff "$M1_MANIFEST" "$M1_PY_MANIFEST" | head -5 | sed 's/^/    /'
fi

rm -rf "$M1_TMPDIR"

echo ""

# ---------------------------------------------------------------------------
# M2: PATH-symlink dispatch test
# Symlink the tool into a temp dir on PATH and invoke by basename.
# Must work and produce identical output to direct invocation.
# ---------------------------------------------------------------------------
echo "--- M2: PATH-symlink dispatch ---"

M2_TMPDIR="$(mktemp -d)"
ln -s "$SCRIPT" "${M2_TMPDIR}/manifest-query"

M2_OPEN="$(PATH="${M2_TMPDIR}:$PATH" manifest-query open --file "$EXEC_READY" 2>&1)"
M2_EXPECTED="$(printf 'spec-preresearch\nflywheel-repo\nflywheel-global')"
assert_eq "M2: PATH-symlink dispatch: open produces correct output" "$M2_EXPECTED" "$M2_OPEN"

M2_READY="$(PATH="${M2_TMPDIR}:$PATH" manifest-query ready --file "$EXEC_READY" 2>&1)"
assert_eq "M2: PATH-symlink dispatch: ready produces flywheel-repo" "flywheel-repo" "$M2_READY"

# Also confirm awk fallback works via symlink (MANIFEST_QUERY_NO_PY=1)
M2_AWK_OPEN="$(PATH="${M2_TMPDIR}:$PATH" MANIFEST_QUERY_NO_PY=1 manifest-query open --file "$EXEC_READY" 2>&1)"
assert_eq "M2: PATH-symlink awk fallback: open produces correct output" "$M2_EXPECTED" "$M2_AWK_OPEN"

rm -rf "$M2_TMPDIR"

echo ""

# ---------------------------------------------------------------------------
# M3: ready(shared) exact-set content assertion
# Independently determine the expected ready set from shared.yaml and assert
# by exact value. Expected: pieces with status open whose every dep is
# merged or done.
# Result (verified by reading shared.yaml): PI-004-second-plugin-pilot and
# pi-022-vsync-ci. PI-004 has no deps and is open. pi-022 depends on
# PI-001-marketplace-version-sync which has status done.
# ---------------------------------------------------------------------------
echo "--- M3: ready(shared) exact-set content assertion ---"

SHARED="${FIXTURE_DIR}/shared.yaml"

if [ -f "$SHARED" ]; then
  SHARED_READY_AWK="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" ready --file "$SHARED")"
  SHARED_READY_PY="$(python3 "$SCRIPT_PY" ready --file "$SHARED")"

  # The expected set (independently verified from shared.yaml):
  #   PI-004-second-plugin-pilot: status=open, deps=[] (no deps → ready)
  #   pi-022-vsync-ci: status=open, deps=[PI-001-marketplace-version-sync] (status=done → ready)
  SHARED_READY_EXPECTED="$(printf 'PI-004-second-plugin-pilot\npi-022-vsync-ci')"

  assert_eq "M3 ready(shared) awk: exact set matches expected" \
    "$SHARED_READY_EXPECTED" "$SHARED_READY_AWK"
  assert_eq "M3 ready(shared) python: exact set matches expected" \
    "$SHARED_READY_EXPECTED" "$SHARED_READY_PY"

  # Confirm PI-004 is present (no-dep open piece)
  if echo "$SHARED_READY_AWK" | grep -qx "PI-004-second-plugin-pilot"; then
    pass "M3: PI-004-second-plugin-pilot in ready (no deps, status=open)"
  else
    fail "M3: PI-004-second-plugin-pilot missing from ready"
  fi

  # Confirm pi-022-vsync-ci is present (dep=done alias satisfied)
  if echo "$SHARED_READY_AWK" | grep -qx "pi-022-vsync-ci"; then
    pass "M3: pi-022-vsync-ci in ready (dep PI-001 has status=done, done alias satisfied)"
  else
    fail "M3: pi-022-vsync-ci missing from ready (done alias may not be honored)"
  fi
else
  fail "M3: shared.yaml fixture missing"
fi

echo ""

# ---------------------------------------------------------------------------
# M5: inline trailing comments on deps and status fields
# ---------------------------------------------------------------------------
echo "--- M5: inline comment stripping on deps/status ---"

M5_FIXTURE="$(mktemp)"
cat > "$M5_FIXTURE" <<'YAML'
schema_version: 1
pieces:
  - name: alpha
    slug: alpha
    status: open  # comment on status
    dependencies: [beta]  # comment corrupts bracket
    prd_sections: [FR-1]  # comment

  - name: beta
    slug: beta
    status: merged  # terminal
    dependencies: []
    prd_sections: []

  - name: gamma
    slug: gamma
    status: open
    dependencies: [beta]
    prd_sections: [FR-2]
YAML

# awk path
M5_AWK_OPEN="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" open --file "$M5_FIXTURE")"
M5_PY_OPEN="$(python3 "$SCRIPT_PY" open --file "$M5_FIXTURE")"
M5_EXPECTED_OPEN="$(printf 'alpha\ngamma')"
assert_eq "M5 awk: open with inline comments on status" "$M5_EXPECTED_OPEN" "$M5_AWK_OPEN"
assert_eq "M5 py: open with inline comments on status" "$M5_EXPECTED_OPEN" "$M5_PY_OPEN"

# beta should NOT appear in open (status=merged)
if echo "$M5_AWK_OPEN" | grep -qx "beta"; then
  fail "M5 awk: beta (merged) should not appear in open"
else
  pass "M5 awk: beta correctly excluded from open"
fi

# deps alpha should yield exactly "beta" (comment stripped)
M5_AWK_DEPS="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" deps alpha --file "$M5_FIXTURE")"
M5_PY_DEPS="$(python3 "$SCRIPT_PY" deps alpha --file "$M5_FIXTURE")"
assert_eq "M5 awk: deps alpha (inline comment stripped)" "beta" "$M5_AWK_DEPS"
assert_eq "M5 py: deps alpha (inline comment stripped)" "beta" "$M5_PY_DEPS"

# ready: alpha and gamma should both be ready (dep beta is merged)
M5_AWK_READY="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" ready --file "$M5_FIXTURE")"
M5_PY_READY="$(python3 "$SCRIPT_PY" ready --file "$M5_FIXTURE")"
M5_EXPECTED_READY="$(printf 'alpha\ngamma')"
assert_eq "M5 awk: ready with inline comment deps" "$M5_EXPECTED_READY" "$M5_AWK_READY"
assert_eq "M5 py: ready with inline comment deps" "$M5_EXPECTED_READY" "$M5_PY_READY"

# parity between awk and python
if [ "$M5_AWK_OPEN" = "$M5_PY_OPEN" ]; then
  pass "M5: awk/python parity on inline-comment fixture (open)"
else
  fail "M5: awk/python differ on inline-comment fixture (open)"
fi
if [ "$M5_AWK_DEPS" = "$M5_PY_DEPS" ]; then
  pass "M5: awk/python parity on inline-comment fixture (deps)"
else
  fail "M5: awk/python differ on inline-comment fixture (deps)"
fi

rm -f "$M5_FIXTURE"

echo ""

# ---------------------------------------------------------------------------
# M6: status-first piece (piece whose first key is status:, before slug:/name:)
# ---------------------------------------------------------------------------
echo "--- M6: status-first piece ---"

M6_FIXTURE="$(mktemp)"
cat > "$M6_FIXTURE" <<'YAML'
schema_version: 1
pieces:
  - status: merged
    slug: prereq
    name: prereq
    dependencies: []
    prd_sections: []

  - status: open
    slug: status-first
    name: status-first
    dependencies: [prereq]
    prd_sections: [FR-X]

  - name: normal-piece
    slug: normal-piece
    status: open
    dependencies: [prereq]
    prd_sections: [FR-Y]
YAML

# open: status-first and normal-piece (open), not prereq (merged)
M6_AWK_OPEN="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" open --file "$M6_FIXTURE")"
M6_PY_OPEN="$(python3 "$SCRIPT_PY" open --file "$M6_FIXTURE")"
M6_EXPECTED_OPEN="$(printf 'status-first\nnormal-piece')"
assert_eq "M6 awk: open includes status-first piece" "$M6_EXPECTED_OPEN" "$M6_AWK_OPEN"
assert_eq "M6 py: open includes status-first piece" "$M6_EXPECTED_OPEN" "$M6_PY_OPEN"

# prereq should not appear in open
if echo "$M6_AWK_OPEN" | grep -qx "prereq"; then
  fail "M6 awk: prereq (merged) should not appear in open"
else
  pass "M6 awk: prereq correctly excluded from open (status-first piece parsed)"
fi

# table: all three pieces should appear
M6_AWK_TABLE="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" table --file "$M6_FIXTURE")"
M6_PY_TABLE="$(python3 "$SCRIPT_PY" table --file "$M6_FIXTURE")"
for chk in prereq status-first normal-piece; do
  if echo "$M6_AWK_TABLE" | grep -qF "$chk"; then
    pass "M6 awk: table contains '$chk'"
  else
    fail "M6 awk: table missing '$chk'"
    echo "$M6_AWK_TABLE" | head -8 | sed 's/^/    /'
  fi
  if echo "$M6_PY_TABLE" | grep -qF "$chk"; then
    pass "M6 py: table contains '$chk'"
  else
    fail "M6 py: table missing '$chk'"
  fi
done

# ready: both status-first and normal-piece should be ready (dep prereq is merged)
M6_AWK_READY="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" ready --file "$M6_FIXTURE")"
M6_PY_READY="$(python3 "$SCRIPT_PY" ready --file "$M6_FIXTURE")"
M6_EXPECTED_READY="$(printf 'status-first\nnormal-piece')"
assert_eq "M6 awk: ready includes status-first piece" "$M6_EXPECTED_READY" "$M6_AWK_READY"
assert_eq "M6 py: ready includes status-first piece" "$M6_EXPECTED_READY" "$M6_PY_READY"

# set-status on a status-first piece (must be settable)
M6_SETSTATUS_COPY="$(mktemp)"
cp "$M6_FIXTURE" "$M6_SETSTATUS_COPY"
M6_SS_EXIT=0
bash "$SCRIPT" set-status status-first specced --file "$M6_SETSTATUS_COPY" || M6_SS_EXIT=$?
if [ "$M6_SS_EXIT" -eq 0 ]; then
  pass "M6 awk: set-status on status-first piece exits 0"
else
  fail "M6 awk: set-status on status-first piece exited $M6_SS_EXIT"
fi
M6_AFTER_OPEN="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" open --file "$M6_SETSTATUS_COPY")"
if echo "$M6_AFTER_OPEN" | grep -qx "status-first"; then
  pass "M6 awk: status-first piece appears in open after set-status specced"
else
  fail "M6 awk: status-first piece missing from open after set-status specced"
fi
M6_AFTER_READY="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" ready --file "$M6_SETSTATUS_COPY")"
if echo "$M6_AFTER_READY" | grep -qx "status-first"; then
  fail "M6 awk: status-first should NOT be ready after set-status specced"
else
  pass "M6 awk: status-first correctly excluded from ready after set-status specced"
fi
rm -f "$M6_SETSTATUS_COPY"

# parity on set-status for status-first piece
M6_AWK_SS="$(mktemp)"
M6_PY_SS="$(mktemp)"
cp "$M6_FIXTURE" "$M6_AWK_SS"
cp "$M6_FIXTURE" "$M6_PY_SS"
MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" set-status status-first specced --file "$M6_AWK_SS" 2>/dev/null || true
python3 "$SCRIPT_PY" set-status status-first specced --file "$M6_PY_SS" 2>/dev/null || true
if diff "$M6_AWK_SS" "$M6_PY_SS" > /dev/null 2>&1; then
  pass "M6: awk/python parity on set-status for status-first piece"
else
  fail "M6: awk/python differ on set-status for status-first piece"
  diff "$M6_AWK_SS" "$M6_PY_SS" | head -10 | sed 's/^/    /'
fi
rm -f "$M6_AWK_SS" "$M6_PY_SS" "$M6_FIXTURE"

echo ""

# ---------------------------------------------------------------------------
# GT-1: block-style dep with inline comment — strip comment, correct ready
#
# Independently derived expected values:
#   - backfill-continuity has depends_on: [live-ingester-ops # L-1 ...]
#     The bare dep name is "live-ingester-ops".
#   - live-ingester-ops has status: merged in prop-firm.yaml
#   - Therefore backfill-continuity (status: open) must appear in ready.
# ---------------------------------------------------------------------------
echo "--- GT-1: block-style dep inline comment stripping + ready correctness ---"

PROP_FIRM_GT1="${FIXTURE_DIR}/prop-firm.yaml"

if [ -f "$PROP_FIRM_GT1" ]; then

  # 1. Bare dep name — both engines must return "live-ingester-ops" (no comment)
  GT1_AWK_DEPS="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" deps backfill-continuity --file "$PROP_FIRM_GT1")"
  GT1_PY_DEPS="$(python3 "$SCRIPT_PY" deps backfill-continuity --file "$PROP_FIRM_GT1")"
  assert_eq "GT-1 awk: deps backfill-continuity bare dep name (no comment)" \
    "live-ingester-ops" "$GT1_AWK_DEPS"
  assert_eq "GT-1 py: deps backfill-continuity bare dep name (no comment)" \
    "live-ingester-ops" "$GT1_PY_DEPS"

  # 2. The dep name must NOT contain '#' (comment must be stripped)
  if echo "$GT1_AWK_DEPS" | grep -qF '#'; then
    fail "GT-1 awk: dep name contains '#' — inline comment not stripped"
  else
    pass "GT-1 awk: dep name contains no '#' (comment fully stripped)"
  fi
  if echo "$GT1_PY_DEPS" | grep -qF '#'; then
    fail "GT-1 py: dep name contains '#' — inline comment not stripped"
  else
    pass "GT-1 py: dep name contains no '#' (comment fully stripped)"
  fi

  # 3. ready must INCLUDE backfill-continuity (sole dep live-ingester-ops is merged)
  GT1_AWK_READY="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" ready --file "$PROP_FIRM_GT1")"
  GT1_PY_READY="$(python3 "$SCRIPT_PY" ready --file "$PROP_FIRM_GT1")"
  if echo "$GT1_AWK_READY" | grep -qx "backfill-continuity"; then
    pass "GT-1 awk: ready includes backfill-continuity (dep live-ingester-ops is merged)"
  else
    fail "GT-1 awk: ready MISSING backfill-continuity (dep resolution broken — comment not stripped)"
  fi
  if echo "$GT1_PY_READY" | grep -qx "backfill-continuity"; then
    pass "GT-1 py: ready includes backfill-continuity (dep live-ingester-ops is merged)"
  else
    fail "GT-1 py: ready MISSING backfill-continuity (dep resolution broken — comment not stripped)"
  fi

  # 4. parity: awk and python must agree on deps for backfill-continuity
  if [ "$GT1_AWK_DEPS" = "$GT1_PY_DEPS" ]; then
    pass "GT-1: awk/python parity on deps backfill-continuity"
  else
    fail "GT-1: awk/python differ on deps backfill-continuity"
    diff <(printf '%s\n' "$GT1_AWK_DEPS") <(printf '%s\n' "$GT1_PY_DEPS") | head -5 | sed 's/^/    /'
  fi

  # 5. Inline fixture: block-style dep with trailing comment — verify comment stripped
  GT1_INLINE="$(mktemp)"
  cat > "$GT1_INLINE" <<'YAML'
schema_version: 1
pieces:
  - name: depended-on
    slug: depended-on
    status: merged
    dependencies: []
    prd_sections: []

  - name: needs-dep
    slug: needs-dep
    status: open
    depends_on:
      - depended-on              # trailing comment that should be stripped
    prd_sections: []
YAML

  GT1_INLINE_AWK_DEPS="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" deps needs-dep --file "$GT1_INLINE")"
  GT1_INLINE_PY_DEPS="$(python3 "$SCRIPT_PY" deps needs-dep --file "$GT1_INLINE")"
  assert_eq "GT-1 awk inline: block dep with comment yields bare dep name" \
    "depended-on" "$GT1_INLINE_AWK_DEPS"
  assert_eq "GT-1 py inline: block dep with comment yields bare dep name" \
    "depended-on" "$GT1_INLINE_PY_DEPS"

  GT1_INLINE_AWK_READY="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" ready --file "$GT1_INLINE")"
  GT1_INLINE_PY_READY="$(python3 "$SCRIPT_PY" ready --file "$GT1_INLINE")"
  if echo "$GT1_INLINE_AWK_READY" | grep -qx "needs-dep"; then
    pass "GT-1 awk inline: ready includes needs-dep (block dep comment stripped)"
  else
    fail "GT-1 awk inline: ready MISSING needs-dep (block dep comment not stripped)"
  fi
  if echo "$GT1_INLINE_PY_READY" | grep -qx "needs-dep"; then
    pass "GT-1 py inline: ready includes needs-dep (block dep comment stripped)"
  else
    fail "GT-1 py inline: ready MISSING needs-dep (block dep comment not stripped)"
  fi

  rm -f "$GT1_INLINE"

else
  fail "GT-1: prop-firm fixture missing"
fi

echo ""

# ---------------------------------------------------------------------------
# GT-2: comment-strip requires whitespace before '#'
#
# A literal '#' with NO preceding whitespace (e.g. BACKLOG#119, foo#bar) must
# be PRESERVED.  A ' # comment' (whitespace before #) must still be STRIPPED.
# Tests both engines on a synthetic fixture with:
#   - prd_sections inline:  BACKLOG#119
#   - block-style dep:      foo#bar
#   - block-style prd item: REF#42
#   - status inline:        open (plain — no hash)
# ---------------------------------------------------------------------------
echo "--- GT-2: literal '#' in value preserved; ' # comment' still stripped ---"

GT2_FIXTURE="$(mktemp)"
cat > "$GT2_FIXTURE" <<'YAML'
schema_version: 1
pieces:
  - name: anchor
    slug: anchor
    status: merged
    dependencies: []
    prd_sections: []

  - name: hash-in-value
    slug: hash-in-value
    status: open
    depends_on:
      - foo#bar
    prd_sections: [BACKLOG#119]

  - name: hash-comment-stripped
    slug: hash-comment-stripped
    status: open # this comment should be stripped
    depends_on:
      - anchor              # trailing comment stripped
    prd_sections:
      - REF#42
      - SECTION-1 # comment stripped
YAML

# 1. foo#bar (block dep, no whitespace before #) must be preserved
GT2_AWK_DEPS="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" deps hash-in-value --file "$GT2_FIXTURE")"
GT2_PY_DEPS="$(python3 "$SCRIPT_PY" deps hash-in-value --file "$GT2_FIXTURE")"
assert_eq "GT-2 awk: literal foo#bar dep preserved (no space before #)" \
  "foo#bar" "$GT2_AWK_DEPS"
assert_eq "GT-2 py: literal foo#bar dep preserved (no space before #)" \
  "foo#bar" "$GT2_PY_DEPS"

# 2. BACKLOG#119 (inline prd_sections, no whitespace before #) must be preserved
GT2_AWK_TABLE="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" table --file "$GT2_FIXTURE")"
GT2_PY_TABLE="$(python3 "$SCRIPT_PY" table --file "$GT2_FIXTURE")"
assert_contains "GT-2 awk: BACKLOG#119 preserved in table output" \
  "BACKLOG#119" "$GT2_AWK_TABLE"
assert_contains "GT-2 py: BACKLOG#119 preserved in table output" \
  "BACKLOG#119" "$GT2_PY_TABLE"

# 3. anchor dep comment (whitespace before #) must still be stripped
GT2_AWK_DEPS2="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" deps hash-comment-stripped --file "$GT2_FIXTURE")"
GT2_PY_DEPS2="$(python3 "$SCRIPT_PY" deps hash-comment-stripped --file "$GT2_FIXTURE")"
assert_eq "GT-2 awk: block dep with ' # comment' stripped to bare name" \
  "anchor" "$GT2_AWK_DEPS2"
assert_eq "GT-2 py: block dep with ' # comment' stripped to bare name" \
  "anchor" "$GT2_PY_DEPS2"

# 4. inline status with ' # comment' must still be stripped
GT2_AWK_OPEN="$(MANIFEST_QUERY_NO_PY=1 bash "$SCRIPT" open --file "$GT2_FIXTURE")"
GT2_PY_OPEN="$(python3 "$SCRIPT_PY" open --file "$GT2_FIXTURE")"
if echo "$GT2_AWK_OPEN" | grep -qx "hash-comment-stripped"; then
  pass "GT-2 awk: status comment stripped — hash-comment-stripped appears in open"
else
  fail "GT-2 awk: hash-comment-stripped missing from open (status comment not stripped)"
fi
if echo "$GT2_PY_OPEN" | grep -qx "hash-comment-stripped"; then
  pass "GT-2 py: status comment stripped — hash-comment-stripped appears in open"
else
  fail "GT-2 py: hash-comment-stripped missing from open (status comment not stripped)"
fi

# 5. REF#42 (block prd item, no whitespace before #) must be preserved
assert_contains "GT-2 awk: REF#42 prd item preserved in table" \
  "REF#42" "$GT2_AWK_TABLE"
assert_contains "GT-2 py: REF#42 prd item preserved in table" \
  "REF#42" "$GT2_PY_TABLE"

# 6. SECTION-1 (block prd item with trailing ' # comment') must be stripped to bare name
assert_contains "GT-2 awk: SECTION-1 bare name present (prd block comment stripped)" \
  "SECTION-1" "$GT2_AWK_TABLE"
assert_contains "GT-2 py: SECTION-1 bare name present (prd block comment stripped)" \
  "SECTION-1" "$GT2_PY_TABLE"
if echo "$GT2_AWK_TABLE" | grep -qF "SECTION-1 # comment"; then
  fail "GT-2 awk: prd block comment leaked into table (not stripped)"
else
  pass "GT-2 awk: prd block comment not present in table (stripped)"
fi
if echo "$GT2_PY_TABLE" | grep -qF "SECTION-1 # comment"; then
  fail "GT-2 py: prd block comment leaked into table (not stripped)"
else
  pass "GT-2 py: prd block comment not present in table (stripped)"
fi

# 7. awk/python parity on both dep queries
if [ "$GT2_AWK_DEPS" = "$GT2_PY_DEPS" ]; then
  pass "GT-2: awk/python parity on deps hash-in-value"
else
  fail "GT-2: awk/python differ on deps hash-in-value"
  diff <(printf '%s\n' "$GT2_AWK_DEPS") <(printf '%s\n' "$GT2_PY_DEPS") | head -5 | sed 's/^/    /'
fi
if [ "$GT2_AWK_DEPS2" = "$GT2_PY_DEPS2" ]; then
  pass "GT-2: awk/python parity on deps hash-comment-stripped"
else
  fail "GT-2: awk/python differ on deps hash-comment-stripped"
  diff <(printf '%s\n' "$GT2_AWK_DEPS2") <(printf '%s\n' "$GT2_PY_DEPS2") | head -5 | sed 's/^/    /'
fi

rm -f "$GT2_FIXTURE"

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$(( PASS + FAIL ))
echo "=== Results: $PASS/$TOTAL passed ==="

if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: $FAIL assertion(s) failed"
  exit 1
else
  echo "PASS: all assertions green"
  exit 0
fi
