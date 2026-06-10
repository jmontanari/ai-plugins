#!/usr/bin/env bash
# self/test-core.sh — outcome-class self-test for lib/assert.sh (AC-11)
# Does NOT use the library under test for its own verdicts.
# No set -e: subshells deliberately exit non-zero; we capture exit codes manually.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
E2E_DIR="$SCRIPT_DIR/.."
LIB="$E2E_DIR/lib/assert.sh"

# Self-test counters (plain inline logic — not lib/assert.sh)
_PASS=0
_FAIL=0

_pass() { printf 'PASS — %s\n' "$1"; _PASS=$((_PASS + 1)); }
_fail() { printf 'FAIL — %s\n' "$1"; _FAIL=$((_FAIL + 1)); }

# Helper: run a subshell, capture stdout+rc without triggering exit-on-error.
# Usage: _run <var_out> <var_rc> <cmd...>
# Appends EXIT:<code> as last line so we can parse rc even when cmd substitution
# would swallow it.  stderr routing is caller's responsibility via 2>&1 or 2>/dev/null.
_capture() {
  local _var_out="$1" _var_rc="$2"; shift 2
  local _raw
  _raw=$("$@"; echo "EXIT:$?")
  local _code="${_raw##*EXIT:}"
  _code="${_code%$'\n'}"
  local _body="${_raw%EXIT:*}"
  # strip trailing newline added before EXIT:
  _body="${_body%$'\n'}"
  printf -v "$_var_out" '%s' "$_body"
  printf -v "$_var_rc" '%s' "$_code"
}

# ---------------------------------------------------------------------------
# sum-1: pass a; pass b; fail c; skip_cap live-run d; summary
#   → stdout contains == summary: 2 passed, 1 failed, 1 skipped, 0 errors ==
#   → subshell exit 1
# ---------------------------------------------------------------------------
_capture _out _rc bash -c '. "'"$LIB"'"; pass a; pass b; fail c; skip_cap live-run d; summary' 2>/dev/null
_want='== summary: 2 passed, 1 failed, 1 skipped, 0 errors =='
if printf '%s\n' "$_out" | grep -qF "$_want" && [ "$_rc" -eq 1 ]; then
  _pass "sum-1"
else
  _fail "sum-1 (got rc=$_rc, out='$_out')"
fi

# ---------------------------------------------------------------------------
# sum-2: pass a; summary
#   → == summary: 1 passed, 0 failed, 0 skipped, 0 errors ==, exit 0
# ---------------------------------------------------------------------------
_capture _out _rc bash -c '. "'"$LIB"'"; pass a; summary' 2>/dev/null
_want='== summary: 1 passed, 0 failed, 0 skipped, 0 errors =='
if printf '%s\n' "$_out" | grep -qF "$_want" && [ "$_rc" -eq 0 ]; then
  _pass "sum-2"
else
  _fail "sum-2 (got rc=$_rc, out='$_out')"
fi

# ---------------------------------------------------------------------------
# sum-3: pass a; err boom; summary
#   → == summary: 1 passed, 0 failed, 0 skipped, 1 errors ==, exit 1
#   (err writes to stderr; merge stderr+stdout to capture both)
# ---------------------------------------------------------------------------
_capture _out _rc bash -c '. "'"$LIB"'"; pass a; err boom; summary' 2>&1
_want='== summary: 1 passed, 0 failed, 0 skipped, 1 errors =='
if printf '%s\n' "$_out" | grep -qF "$_want" && [ "$_rc" -eq 1 ]; then
  _pass "sum-3"
else
  _fail "sum-3 (got rc=$_rc, out='$_out')"
fi

# ---------------------------------------------------------------------------
# sum-4: skip_cap metrics-artifact x; summary
#   → line "SKIPPED: metrics-artifact — x" present
#   → no line beginning "PASS — x"
#   → exit 0
# ---------------------------------------------------------------------------
_capture _out _rc bash -c '. "'"$LIB"'"; skip_cap metrics-artifact x; summary' 2>/dev/null
_has_skip=0; _has_pass=0
printf '%s\n' "$_out" | grep -qF 'SKIPPED: metrics-artifact — x' && _has_skip=1
printf '%s\n' "$_out" | grep -qE '^PASS — x$'                     && _has_pass=1
if [ "$_has_skip" -eq 1 ] && [ "$_has_pass" -eq 0 ] && [ "$_rc" -eq 0 ]; then
  _pass "sum-4"
else
  _fail "sum-4 (has_skip=$_has_skip, has_pass=$_has_pass, rc=$_rc)"
fi

# ---------------------------------------------------------------------------
# ord-1 / ord-2: build a temp git repo
# ---------------------------------------------------------------------------

# Inline equivalent of e2e_mktemp (library not sourced in parent shell)
_TMPDIR=$(mktemp -d 2>/dev/null) || { _TMPDIR="/tmp/e2e-self-$$-$RANDOM"; mkdir -p "$_TMPDIR"; }

# Build the temp git repo with two commits in order: research: r, then spec: add s
git -C "$_TMPDIR" init -q
git -C "$_TMPDIR" config user.email "test@example.com"
git -C "$_TMPDIR" config user.name "Test"
touch "$_TMPDIR/a.txt"
git -C "$_TMPDIR" add a.txt
git -C "$_TMPDIR" commit -q -m "research: r"
touch "$_TMPDIR/b.txt"
git -C "$_TMPDIR" add b.txt
git -C "$_TMPDIR" commit -q -m "spec: add s"

# ord-1: correct order → expect PASS — lbl
_capture _out _rc bash -c '. "'"$LIB"'"; assert_subject_order "'"$_TMPDIR"'" "research: " "spec: add" lbl' 2>/dev/null
if printf '%s\n' "$_out" | grep -qF 'PASS — lbl'; then
  _pass "ord-1"
else
  _fail "ord-1 (got: '$_out')"
fi

# ord-2: reversed args → expect FAIL — lbl naming the misorder
_capture _out _rc bash -c '. "'"$LIB"'"; assert_subject_order "'"$_TMPDIR"'" "spec: add" "research: " lbl' 2>/dev/null
if printf '%s\n' "$_out" | grep -qF 'FAIL — lbl'; then
  _pass "ord-2"
else
  _fail "ord-2 (got: '$_out')"
fi

# Clean up temp repo (confined to /tmp or /private or /var/folders)
case "$_TMPDIR" in
  /tmp/*|/private/*|/var/folders/*) rm -rf "$_TMPDIR" ;;
  *) printf 'WARNING: skipping cleanup of unexpected path: %s\n' "$_TMPDIR" ;;
esac

# ---------------------------------------------------------------------------
# --- L1 ---
# Tests for l1_static_checks() in lib/static.sh
# ---------------------------------------------------------------------------
STATIC="$E2E_DIR/lib/static.sh"
SKILL="$E2E_DIR/../../skills/execute/SKILL.md"

# l1-1: real SKILL.md → 13 PASS — L1 lines, 0 FAIL lines
_capture _out _rc bash -c '. "'"$LIB"'"; . "'"$STATIC"'"; l1_static_checks "'"$SKILL"'"; summary' 2>/dev/null
_pass_count=$(printf '%s\n' "$_out" | grep -c 'PASS — L1' || true)
_fail_count=$(printf '%s\n' "$_out" | grep -c '^FAIL' || true)
if [ "$_pass_count" -eq 13 ] && [ "$_fail_count" -eq 0 ]; then
  _pass "l1-1"
else
  _fail "l1-1 (PASS—L1 count=$_pass_count, FAIL count=$_fail_count, rc=$_rc)"
fi

# Build temp dir for l1-2 and l1-3 broken copies
_L1TMPDIR=$(mktemp -d 2>/dev/null) || { _L1TMPDIR="/tmp/e2e-l1-$$-$RANDOM"; mkdir -p "$_L1TMPDIR"; }

# l1-2: delete QA-TDD-Red section body (keep Step 3 heading) → 1 FAIL naming the missing token, summary exits 1
_l1_2="$_L1TMPDIR/skill_l1_2.md"
sed '/^### Step 2.5: QA-TDD-Red/,/^### Step 3: Implement/{/^### Step 3: Implement/!d;}' "$SKILL" > "$_l1_2"
_capture _out _rc bash -c '. "'"$LIB"'"; . "'"$STATIC"'"; l1_static_checks "'"$_l1_2"'"; summary' 2>/dev/null
_has_fail_tok=0
printf '%s\n' "$_out" | grep -qF 'FAIL — L1 sequence token missing: ### Step 2.5: QA-TDD-Red' && _has_fail_tok=1
if [ "$_has_fail_tok" -eq 1 ] && [ "$_rc" -eq 1 ]; then
  _pass "l1-2"
else
  _fail "l1-2 (has_fail_tok=$_has_fail_tok, rc=$_rc, out='$_out')"
fi

# l1-3: move ## Final Review above ### Step 2: TDD-Red → FAIL containing 'misordered'
_l1_3="$_L1TMPDIR/skill_l1_3.md"
sed '/^## Final Review$/d; /^### Step 2: TDD-Red/i\
## Final Review' "$SKILL" > "$_l1_3"
_capture _out _rc bash -c '. "'"$LIB"'"; . "'"$STATIC"'"; l1_static_checks "'"$_l1_3"'"; summary' 2>/dev/null
_has_misordered=0
printf '%s\n' "$_out" | grep -qF 'misordered' && _has_misordered=1
if [ "$_has_misordered" -eq 1 ]; then
  _pass "l1-3"
else
  _fail "l1-3 (has_misordered=$_has_misordered, rc=$_rc, out='$_out')"
fi

# Clean up L1 temp dir
case "$_L1TMPDIR" in
  /tmp/*|/private/*|/var/folders/*) rm -rf "$_L1TMPDIR" ;;
  *) printf 'WARNING: skipping cleanup of unexpected path: %s\n' "$_L1TMPDIR" ;;
esac

# ---------------------------------------------------------------------------
# --- L2 ---
# Tests for contract.sh check functions (AC-12)
# ---------------------------------------------------------------------------
CONTRACT="$E2E_DIR/lib/contract.sh"
BUILDER="$E2E_DIR/build-fixture.sh"
WORKTREE_ROOT="$(cd "$E2E_DIR/../../../.." && pwd)"

# Helper: build fixture into a fresh tmp dir, return path in _L2T
_l2_build() {
  local break_arg="${1:-}"
  _L2T=$(mktemp -d 2>/dev/null) || { _L2T="/tmp/e2e-l2-$$-$RANDOM"; mkdir -p "$_L2T"; }
  if [ -n "$break_arg" ]; then
    bash "$BUILDER" "$_L2T" "--break=$break_arg" 2>/dev/null
  else
    bash "$BUILDER" "$_L2T" 2>/dev/null
  fi
}

_l2_cleanup() {
  case "$_L2T" in
    /tmp/*|/private/*|/var/folders/*) rm -rf "$_L2T" ;;
    *) printf 'WARNING: skipping cleanup of unexpected path: %s\n' "$_L2T" ;;
  esac
}

# ---------------------------------------------------------------------------
# l2-1: clean fixture (no --break) → checks (a)–(g) all PASS (≥7 PASS, 0 FAIL)
# ---------------------------------------------------------------------------
_l2_build
_l2_piece="$_L2T/docs/prds/demo/specs/hello"
_capture _out _rc bash -c \
  ". \"$LIB\"; E2E_DIR=\"$E2E_DIR\"; . \"$CONTRACT\"; \
   check_commit_order \"$_L2T\"; \
   check_transitions \"$_L2T\"; \
   check_test_data \"$_l2_piece/plan.md\"; \
   check_spike \"$_l2_piece\"; \
   check_discovery_log \"$_l2_piece\"; \
   check_learnings \"$_l2_piece\"; \
   check_no_journal \"$_L2T\"" 2>/dev/null
_l2_pass_count=$(printf '%s\n' "$_out" | grep -c '^PASS' || true)
_l2_fail_count=$(printf '%s\n' "$_out" | grep -c '^FAIL' || true)
if [ "$_l2_fail_count" -eq 0 ] && [ "$_l2_pass_count" -ge 7 ]; then
  _pass "l2-1 (all checks pass on clean fixture; PASS count=$_l2_pass_count)"
else
  _fail "l2-1 (PASS=$_l2_pass_count FAIL=$_l2_fail_count; out='$_out')"
fi
_l2_cleanup

# ---------------------------------------------------------------------------
# l2-2: --break=research-after-spec → check_commit_order → FAIL containing 'research: '
# ---------------------------------------------------------------------------
_l2_build "research-after-spec"
_capture _out _rc bash -c \
  ". \"$LIB\"; E2E_DIR=\"$E2E_DIR\"; . \"$CONTRACT\"; check_commit_order \"$_L2T\"" 2>/dev/null
if printf '%s\n' "$_out" | grep -qE '^FAIL.*research: '; then
  _pass "l2-2"
else
  _fail "l2-2 (expected FAIL containing 'research: '; got: '$_out')"
fi
_l2_cleanup

# ---------------------------------------------------------------------------
# l2-3: --break=no-test-data → check_test_data → FAIL naming 'Phase 1'
# ---------------------------------------------------------------------------
_l2_build "no-test-data"
_l2_piece="$_L2T/docs/prds/demo/specs/hello"
_capture _out _rc bash -c \
  ". \"$LIB\"; E2E_DIR=\"$E2E_DIR\"; . \"$CONTRACT\"; check_test_data \"$_l2_piece/plan.md\"" 2>/dev/null
if printf '%s\n' "$_out" | grep -qE '^FAIL.*Phase 1'; then
  _pass "l2-3"
else
  _fail "l2-3 (expected FAIL containing 'Phase 1'; got: '$_out')"
fi
_l2_cleanup

# ---------------------------------------------------------------------------
# l2-4: --break=no-spike-artifact → check_spike → FAIL containing 'spikes/'
# ---------------------------------------------------------------------------
_l2_build "no-spike-artifact"
_l2_piece="$_L2T/docs/prds/demo/specs/hello"
_capture _out _rc bash -c \
  ". \"$LIB\"; E2E_DIR=\"$E2E_DIR\"; . \"$CONTRACT\"; check_spike \"$_l2_piece\"" 2>/dev/null
if printf '%s\n' "$_out" | grep -qE '^FAIL.*spikes/'; then
  _pass "l2-4"
else
  _fail "l2-4 (expected FAIL containing 'spikes/'; got: '$_out')"
fi
_l2_cleanup

# ---------------------------------------------------------------------------
# l2-5: --break=skip-transition → check_transitions → FAIL containing 'planned'
# ---------------------------------------------------------------------------
_l2_build "skip-transition"
_capture _out _rc bash -c \
  ". \"$LIB\"; E2E_DIR=\"$E2E_DIR\"; . \"$CONTRACT\"; check_transitions \"$_L2T\"" 2>/dev/null
if printf '%s\n' "$_out" | grep -qE '^FAIL.*planned'; then
  _pass "l2-5"
else
  _fail "l2-5 (expected FAIL containing 'planned'; got: '$_out')"
fi
_l2_cleanup

# ---------------------------------------------------------------------------
# l2-6: --break=journal-survives → check_no_journal → FAIL containing '.phase-group-journal.json'
# ---------------------------------------------------------------------------
_l2_build "journal-survives"
_capture _out _rc bash -c \
  ". \"$LIB\"; E2E_DIR=\"$E2E_DIR\"; . \"$CONTRACT\"; check_no_journal \"$_L2T\"" 2>/dev/null
if printf '%s\n' "$_out" | grep -qE '^FAIL.*\.phase-group-journal\.json'; then
  _pass "l2-6"
else
  _fail "l2-6 (expected FAIL containing '.phase-group-journal.json'; got: '$_out')"
fi
_l2_cleanup

# ---------------------------------------------------------------------------
# l2-7: --break=missing-learnings → check_learnings → FAIL containing 'learnings.md'
# ---------------------------------------------------------------------------
_l2_build "missing-learnings"
_l2_piece="$_L2T/docs/prds/demo/specs/hello"
_capture _out _rc bash -c \
  ". \"$LIB\"; E2E_DIR=\"$E2E_DIR\"; . \"$CONTRACT\"; check_learnings \"$_l2_piece\"" 2>/dev/null
if printf '%s\n' "$_out" | grep -qE '^FAIL.*learnings\.md'; then
  _pass "l2-7"
else
  _fail "l2-7 (expected FAIL containing 'learnings.md'; got: '$_out')"
fi
_l2_cleanup

# ---------------------------------------------------------------------------
# l2-8: real piece dir docs/prds/exec-ready/specs/flywheel-repo via --audit mode
#   Expect: 'EXCLUDED — ordering checks' line + 5 PASS + 0 FAIL + exit 0
# ---------------------------------------------------------------------------
_capture _out _rc bash "$E2E_DIR/run-e2e.sh" --audit \
  "docs/prds/exec-ready/specs/flywheel-repo" 2>/dev/null
_l8_has_excluded=0; _l8_pass_count=0; _l8_fail_count=0
printf '%s\n' "$_out" | grep -qF 'EXCLUDED — ordering checks' && _l8_has_excluded=1
_l8_pass_count=$(printf '%s\n' "$_out" | grep -c '^PASS' || true)
_l8_fail_count=$(printf '%s\n' "$_out" | grep -c '^FAIL' || true)
if [ "$_l8_has_excluded" -eq 1 ] && [ "$_l8_pass_count" -eq 5 ] && [ "$_l8_fail_count" -eq 0 ] && [ "$_rc" -eq 0 ]; then
  _pass "l2-8 (audit: EXCLUDED present, 5 PASS, 0 FAIL, exit 0)"
else
  _fail "l2-8 (has_excluded=$_l8_has_excluded PASS=$_l8_pass_count FAIL=$_l8_fail_count rc=$_rc; out='$_out')"
fi

# ---------------------------------------------------------------------------
# --- spike-conformance ---
# Tests for check_spike() requiring **Test Data:** field (M2)
# ---------------------------------------------------------------------------

# spike-no-td: spike file with Mode/Trigger/Resolution but no **Test Data:**
#   → check_spike must emit ^FAIL.*Test Data
_spktd=$(mktemp -d 2>/dev/null) || { _spktd="/tmp/e2e-spktd-$$-$RANDOM"; mkdir -p "$_spktd"; }
mkdir -p "$_spktd/spikes"
printf '# spike — test\n\n**Mode:** resolve\n**Trigger:** test\n**Resolution:** done\n' \
  > "$_spktd/spikes/test.md"
# plan.md must exist (check_spike reads it for [SPIKE: marker)
printf '# plan\n' > "$_spktd/plan.md"
_capture _spktd_out _spktd_rc bash -c \
  "E2E_DIR=\"$E2E_DIR\"; . \"$LIB\"; . \"$CONTRACT\"; check_spike \"$_spktd\"" 2>/dev/null
if printf '%s\n' "$_spktd_out" | grep -qE '^FAIL.*Test Data'; then
  _pass "spike-no-td (check_spike fires ^FAIL.*Test Data for spike missing **Test Data:**)"
else
  _fail "spike-no-td (expected ^FAIL.*Test Data; got: '$_spktd_out')"
fi
case "$_spktd" in
  /tmp/*|/private/*|/var/folders/*) rm -rf "$_spktd" ;;
  *) printf 'WARNING: skipping cleanup of unexpected path: %s\n' "$_spktd" ;;
esac

# ---------------------------------------------------------------------------
# --- vl ---
# Tests for verify_live() in lib/live.sh (SF-5 deterministic substrate)
# ---------------------------------------------------------------------------
LIVE="$E2E_DIR/lib/live.sh"
CONTRACT="$E2E_DIR/lib/contract.sh"

# ---------------------------------------------------------------------------
# vl-1: clean post-run + clean transcript → 0 FAIL lines; EXCLUDED (a)-(b) present;
#        healthy PASS count (round-trip + dispatch order + counts present)
# ---------------------------------------------------------------------------
_capture _vl1_out _vl1_rc bash -c \
  "E2E_DIR=\"$E2E_DIR\"; . \"$LIB\"; . \"$CONTRACT\"; . \"$LIVE\"; \
   verify_live \"$E2E_DIR/fixtures/post-run/clean\" \"$E2E_DIR/fixtures/transcript/clean.jsonl\"" \
  2>/dev/null
_vl1_fail_count=$(printf '%s\n' "$_vl1_out" | grep -c '^FAIL' || true)
_vl1_has_excluded=0
_vl1_pass_count=$(printf '%s\n' "$_vl1_out" | grep -c '^PASS' || true)
printf '%s\n' "$_vl1_out" | grep -q 'EXCLUDED.*ordering checks' && _vl1_has_excluded=1
if [ "$_vl1_fail_count" -eq 0 ] && [ "$_vl1_has_excluded" -eq 1 ] && [ "$_vl1_pass_count" -ge 5 ]; then
  _pass "vl-1 (clean pair: 0 FAIL, EXCLUDED present, ${_vl1_pass_count} PASS)"
else
  _fail "vl-1 (FAIL_count=$_vl1_fail_count has_excluded=$_vl1_has_excluded PASS=$_vl1_pass_count; out='$_vl1_out')"
fi

# ---------------------------------------------------------------------------
# vl-2: broken post-run (test file lacks oracle) → FAIL line contains test-greet.sh
# ---------------------------------------------------------------------------
_capture _vl2_out _vl2_rc bash -c \
  "E2E_DIR=\"$E2E_DIR\"; . \"$LIB\"; . \"$CONTRACT\"; . \"$LIVE\"; \
   verify_live \"$E2E_DIR/fixtures/post-run/broken\"" \
  2>/dev/null
if printf '%s\n' "$_vl2_out" | grep -qE '^FAIL.*test-greet\.sh'; then
  _pass "vl-2 (broken post-run: ^FAIL line containing test-greet.sh present)"
else
  _fail "vl-2 (expected ^FAIL.*test-greet.sh; got: '$_vl2_out')"
fi

# ---------------------------------------------------------------------------
# vl-3: clean post-run + broken transcript → three expected FAIL lines:
#        dispatch order misordered, tdd-red count != 3, [TEST-DATA-ABSENT missing
# ---------------------------------------------------------------------------
_capture _vl3_out _vl3_rc bash -c \
  "E2E_DIR=\"$E2E_DIR\"; . \"$LIB\"; . \"$CONTRACT\"; . \"$LIVE\"; \
   verify_live \"$E2E_DIR/fixtures/post-run/clean\" \"$E2E_DIR/fixtures/transcript/broken.jsonl\"" \
  2>/dev/null
_vl3_ok=1
printf '%s\n' "$_vl3_out" | grep -qE '^FAIL.*misordered'    || _vl3_ok=0
printf '%s\n' "$_vl3_out" | grep -qE '^FAIL.*count == 3'    || _vl3_ok=0
printf '%s\n' "$_vl3_out" | grep -qE '^FAIL.*TEST-DATA-ABSENT' || _vl3_ok=0
if [ "$_vl3_ok" -eq 1 ]; then
  _pass "vl-3 (broken transcript: ^FAIL misordered + count==3 + TEST-DATA-ABSENT all fire)"
else
  _fail "vl-3 (missing expected ^FAIL lines; out='$(printf '%s\n' "$_vl3_out" | grep '^FAIL' | head -5)')"
fi

# ---------------------------------------------------------------------------
# vl-4: clean post-run + nonexistent transcript → SKIPPED: transcript AND
#        tree/round-trip checks still ran (EXCLUDED (a)-(b) line present) AND 0 FAIL
# ---------------------------------------------------------------------------
_capture _vl4_out _vl4_rc bash -c \
  "E2E_DIR=\"$E2E_DIR\"; . \"$LIB\"; . \"$CONTRACT\"; . \"$LIVE\"; \
   verify_live \"$E2E_DIR/fixtures/post-run/clean\" /nonexistent.jsonl" \
  2>/dev/null
_vl4_has_skipped=0; _vl4_has_excluded=0
_vl4_fail_count=$(printf '%s\n' "$_vl4_out" | grep -c '^FAIL' || true)
printf '%s\n' "$_vl4_out" | grep -qF 'SKIPPED: transcript' && _vl4_has_skipped=1
printf '%s\n' "$_vl4_out" | grep -q 'EXCLUDED.*ordering checks' && _vl4_has_excluded=1
if [ "$_vl4_has_skipped" -eq 1 ] && [ "$_vl4_has_excluded" -eq 1 ] && [ "$_vl4_fail_count" -eq 0 ]; then
  _pass "vl-4 (missing transcript: SKIPPED present, tree-half ran, 0 FAIL)"
else
  _fail "vl-4 (has_skipped=$_vl4_has_skipped has_excluded=$_vl4_has_excluded FAIL=$_vl4_fail_count; out='$_vl4_out')"
fi

# ---------------------------------------------------------------------------
# vl-5: setup-live.sh <tmp> → 5 commits, status: planned, plan shape greps
#        3× [TDD-Red], 1× [SPIKE, 1× **Test Data:**
# ---------------------------------------------------------------------------
_VL5TMP=$(mktemp -d 2>/dev/null) || { _VL5TMP="/tmp/e2e-vl5-$$-$RANDOM"; mkdir -p "$_VL5TMP"; }
_vl5_repo="$_VL5TMP/live"
bash "$E2E_DIR/setup-live.sh" "$_vl5_repo" 2>/dev/null
_vl5_plan="$_vl5_repo/docs/prds/demo/specs/hello/plan.md"
_vl5_commits=$(git -C "$_vl5_repo" log --oneline 2>/dev/null | wc -l | tr -d ' ')
_vl5_status=$(grep 'status:' "$_vl5_repo/docs/prds/demo/manifest.yaml" 2>/dev/null || true)
_vl5_tdd=$(grep -c '\[TDD-Red\]' "$_vl5_plan" 2>/dev/null || true)
_vl5_spike=$(grep -c '\[SPIKE' "$_vl5_plan" 2>/dev/null || true)
_vl5_testdata=$(grep -c '\*\*Test Data:\*\*' "$_vl5_plan" 2>/dev/null || true)
_vl5_ok=1
if [ "$_vl5_commits" -eq 5 ] && \
   printf '%s\n' "$_vl5_status" | grep -q 'status: planned' && \
   [ "$_vl5_tdd" -eq 3 ] && \
   [ "$_vl5_spike" -eq 1 ] && \
   [ "$_vl5_testdata" -eq 1 ]; then
  _pass "vl-5 (setup-live: 5 commits, status:planned, 3×TDD-Red, 1×SPIKE, 1×Test Data)"
else
  _fail "vl-5 (commits=$_vl5_commits status='$_vl5_status' TDD-Red=$_vl5_tdd SPIKE=$_vl5_spike TestData=$_vl5_testdata)"
  _vl5_ok=0
fi
case "$_VL5TMP" in
  /tmp/*|/private/*|/var/folders/*) rm -rf "$_VL5TMP" ;;
  *) printf 'WARNING: skipping cleanup of unexpected path: %s\n' "$_VL5TMP" ;;
esac

# ---------------------------------------------------------------------------
# --- golden/metrics ---
# Tests for record_golden (lib/golden.sh), golden_validate (lib/golden.sh),
# metrics_check (lib/metrics.sh) — Phase 6 [Write-Tests]
# Uses a TEMP E2E_DIR copy so the real golden/ stays untouched.
# ---------------------------------------------------------------------------
GOLDEN="$E2E_DIR/lib/golden.sh"
METRICS="$E2E_DIR/lib/metrics.sh"

# Build fixture + set up temp E2E_DIR copy (shared across gold-1..gold-4)
_g_fix=$(mktemp -d 2>/dev/null) || { _g_fix="/tmp/e2e-gfix-$$-$RANDOM"; mkdir -p "$_g_fix"; }
bash "$BUILDER" "$_g_fix" 2>/dev/null
_g_piece="$_g_fix/docs/prds/demo/specs/hello"

_g_e2e=$(mktemp -d 2>/dev/null) || { _g_e2e="/tmp/e2e-ge2e-$$-$RANDOM"; mkdir -p "$_g_e2e"; }
cp -R "$E2E_DIR"/* "$_g_e2e"/

# ---------------------------------------------------------------------------
# gold-1: record_golden from L2 clean fixture piece dir + clean transcript
#   → footprint.txt written with 4 "## " section headings AND "RECORDED:" line
# ---------------------------------------------------------------------------
_capture _gold1_out _gold1_rc bash -c \
  "E2E_DIR=\"$_g_e2e\"; . \"$_g_e2e/lib/assert.sh\"; . \"$_g_e2e/lib/contract.sh\"; \
   . \"$_g_e2e/lib/live.sh\"; . \"$_g_e2e/lib/golden.sh\"; \
   record_golden \"$_g_piece\" \"$E2E_DIR/fixtures/transcript/clean.jsonl\"" 2>/dev/null
_g1_has_recorded=0; _g1_heading_count=0
printf '%s\n' "$_gold1_out" | grep -qF 'RECORDED:' && _g1_has_recorded=1
[ -f "$_g_e2e/golden/footprint.txt" ] && \
  _g1_heading_count=$(grep -c '^## ' "$_g_e2e/golden/footprint.txt" || true)
if [ "$_g1_has_recorded" -eq 1 ] && [ "$_g1_heading_count" -eq 4 ]; then
  _pass "gold-1 (record_golden: RECORDED: emitted, 4 ## sections in footprint.txt)"
else
  _fail "gold-1 (has_recorded=$_g1_has_recorded heading_count=$_g1_heading_count rc=$_gold1_rc)"
fi

# ---------------------------------------------------------------------------
# gold-2: golden_validate on the footprint recorded by gold-1
#   → PASS lines for cksum + order rules; 0 "^FAIL" lines
# ---------------------------------------------------------------------------
_capture _gold2_out _gold2_rc bash -c \
  "E2E_DIR=\"$_g_e2e\"; . \"$_g_e2e/lib/assert.sh\"; . \"$_g_e2e/lib/contract.sh\"; \
   . \"$_g_e2e/lib/live.sh\"; . \"$_g_e2e/lib/golden.sh\"; \
   golden_validate" 2>/dev/null
_g2_fail_count=$(printf '%s\n' "$_gold2_out" | grep -c '^FAIL' || true)
_g2_has_cksum_pass=0
printf '%s\n' "$_gold2_out" | grep -qF 'PASS — golden integrity: cksum matches' && _g2_has_cksum_pass=1
if [ "$_g2_fail_count" -eq 0 ] && [ "$_g2_has_cksum_pass" -eq 1 ]; then
  _pass "gold-2 (golden_validate: cksum PASS, 0 FAIL lines)"
else
  _fail "gold-2 (cksum_pass=$_g2_has_cksum_pass FAIL_count=$_g2_fail_count; out='$_gold2_out')"
fi

# ---------------------------------------------------------------------------
# gold-3: mutate footprint (delete one ## commit-subjects line — here the
#   heading line itself via line 2 — then run golden_validate)
#   → expect ^FAIL.*cksum mismatch
# ---------------------------------------------------------------------------
_g_e2e3=$(mktemp -d 2>/dev/null) || { _g_e2e3="/tmp/e2e-ge2e3-$$-$RANDOM"; mkdir -p "$_g_e2e3"; }
cp -R "$_g_e2e"/* "$_g_e2e3"/
# Mutate: delete line 2 (the "## commit-subjects" heading line)
sed '2d' "$_g_e2e3/golden/footprint.txt" > "$_g_e2e3/golden/footprint.txt.tmp" && \
  mv "$_g_e2e3/golden/footprint.txt.tmp" "$_g_e2e3/golden/footprint.txt"
_capture _gold3_out _gold3_rc bash -c \
  "E2E_DIR=\"$_g_e2e3\"; . \"$_g_e2e3/lib/assert.sh\"; . \"$_g_e2e3/lib/contract.sh\"; \
   . \"$_g_e2e3/lib/live.sh\"; . \"$_g_e2e3/lib/golden.sh\"; \
   golden_validate" 2>/dev/null
if printf '%s\n' "$_gold3_out" | grep -qE '^FAIL.*cksum mismatch'; then
  _pass "gold-3 (mutated footprint: ^FAIL.*cksum mismatch fires)"
else
  _fail "gold-3 (expected ^FAIL.*cksum mismatch; got: '$_gold3_out')"
fi
case "$_g_e2e3" in
  /tmp/*|/private/*|/var/folders/*) rm -rf "$_g_e2e3" ;;
  *) printf 'WARNING: skipping cleanup of unexpected path: %s\n' "$_g_e2e3" ;;
esac

# ---------------------------------------------------------------------------
# gold-4: remove golden/footprint.txt → have_golden gate emits skip_cap live-run
#   → expect SKIPPED: live-run containing "no golden recorded"
# ---------------------------------------------------------------------------
_g_e2e4=$(mktemp -d 2>/dev/null) || { _g_e2e4="/tmp/e2e-ge2e4-$$-$RANDOM"; mkdir -p "$_g_e2e4"; }
cp -R "$_g_e2e"/* "$_g_e2e4"/
rm -f "$_g_e2e4/golden/footprint.txt"
_capture _gold4_out _gold4_rc bash -c \
  "E2E_DIR=\"$_g_e2e4\"; . \"$_g_e2e4/lib/assert.sh\"; \
   if ! have_golden; then skip_cap live-run 'no golden recorded — run the live procedure (README)'; fi" 2>/dev/null
_g4_has_skipped=0; _g4_has_msg=0
printf '%s\n' "$_gold4_out" | grep -qF 'SKIPPED: live-run' && _g4_has_skipped=1
printf '%s\n' "$_gold4_out" | grep -qF 'no golden recorded' && _g4_has_msg=1
if [ "$_g4_has_skipped" -eq 1 ] && [ "$_g4_has_msg" -eq 1 ]; then
  _pass "gold-4 (no footprint: SKIPPED: live-run — no golden recorded)"
else
  _fail "gold-4 (has_skipped=$_g4_has_skipped has_msg=$_g4_has_msg; out='$_gold4_out')"
fi
case "$_g_e2e4" in
  /tmp/*|/private/*|/var/folders/*) rm -rf "$_g_e2e4" ;;
  *) printf 'WARNING: skipping cleanup of unexpected path: %s\n' "$_g_e2e4" ;;
esac

# Clean up shared golden fixture tmp dirs
case "$_g_e2e" in
  /tmp/*|/private/*|/var/folders/*) rm -rf "$_g_e2e" ;;
  *) printf 'WARNING: skipping cleanup of unexpected path: %s\n' "$_g_e2e" ;;
esac
case "$_g_fix" in
  /tmp/*|/private/*|/var/folders/*) rm -rf "$_g_fix" ;;
  *) printf 'WARNING: skipping cleanup of unexpected path: %s\n' "$_g_fix" ;;
esac

# Sanity-check: real golden/ must still contain ONLY .gitkeep
_real_golden_files=$(ls "$E2E_DIR/golden/" 2>/dev/null | grep -v '^\.' || true)
if [ -z "$_real_golden_files" ] && [ -f "$E2E_DIR/golden/.gitkeep" ]; then
  true  # all good — real golden untouched (no _pass here; this is a guard, not a case)
else
  _fail "GUARD: real golden/ contaminated (found: '$_real_golden_files' / missing .gitkeep)"
fi

# ---------------------------------------------------------------------------
# met-1: piece dir WITHOUT metrics.yaml → metrics_check → SKIPPED: metrics-artifact
#   containing "FR-010 not shipped"
# ---------------------------------------------------------------------------
_met_dir=$(mktemp -d 2>/dev/null) || { _met_dir="/tmp/e2e-met-$$-$RANDOM"; mkdir -p "$_met_dir"; }
_capture _met1_out _met1_rc bash -c \
  "E2E_DIR=\"$E2E_DIR\"; . \"$E2E_DIR/lib/assert.sh\"; . \"$E2E_DIR/lib/metrics.sh\"; \
   metrics_check \"$_met_dir\"" 2>/dev/null
if printf '%s\n' "$_met1_out" | grep -qF 'SKIPPED: metrics-artifact' && \
   printf '%s\n' "$_met1_out" | grep -qF 'FR-010 not shipped'; then
  _pass "met-1 (no metrics.yaml: SKIPPED: metrics-artifact — FR-010 not shipped)"
else
  _fail "met-1 (expected SKIPPED: metrics-artifact / FR-010 not shipped; got: '$_met1_out')"
fi

# ---------------------------------------------------------------------------
# met-2: piece dir AFTER writing placeholder metrics.yaml → metrics_check
#   → PASS — metrics artifact present
# ---------------------------------------------------------------------------
printf 'placeholder: true\n' > "$_met_dir/metrics.yaml"
_capture _met2_out _met2_rc bash -c \
  "E2E_DIR=\"$E2E_DIR\"; . \"$E2E_DIR/lib/assert.sh\"; . \"$E2E_DIR/lib/metrics.sh\"; \
   metrics_check \"$_met_dir\"" 2>/dev/null
if printf '%s\n' "$_met2_out" | grep -qF 'PASS — metrics artifact present'; then
  _pass "met-2 (metrics.yaml present: PASS — metrics artifact present)"
else
  _fail "met-2 (expected PASS — metrics artifact present; got: '$_met2_out')"
fi
case "$_met_dir" in
  /tmp/*|/private/*|/var/folders/*) rm -rf "$_met_dir" ;;
  *) printf 'WARNING: skipping cleanup of unexpected path: %s\n' "$_met_dir" ;;
esac

# ---------------------------------------------------------------------------
# Self-test summary (own format, skipped/errors always 0 at this layer)
# ---------------------------------------------------------------------------
printf '== summary: %s passed, %s failed, 0 skipped, 0 errors ==\n' "$_PASS" "$_FAIL"
[ "$_FAIL" -eq 0 ] && exit 0 || exit 1
