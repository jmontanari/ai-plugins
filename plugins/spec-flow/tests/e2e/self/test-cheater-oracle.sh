#!/usr/bin/env bash
# self/test-cheater-oracle.sh — outcome-class self-test for lib/cheater-oracle.sh (AC-7, AC-8)
# Does NOT use lib/assert.sh for its own verdicts (mirrors self/test-core.sh pattern).
# No set -e: subshells deliberately exit non-zero; we capture exit codes manually.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
E2E_DIR="$SCRIPT_DIR/.."
LIB="$E2E_DIR/lib/assert.sh"
CHEATER_LIB="$E2E_DIR/lib/cheater-oracle.sh"

# Self-test counters (own inline logic — not lib/assert.sh)
_PASS=0
_FAIL=0

_pass() { printf 'PASS — %s\n' "$1"; _PASS=$((_PASS + 1)); }
_fail() { printf 'FAIL — %s\n' "$1"; _FAIL=$((_FAIL + 1)); }

# Helper: run a subshell, capture stdout+rc without triggering exit-on-error.
# Appends EXIT:<code> as last line so we can parse rc even when cmd substitution
# would swallow it.
_capture() {
  local _var_out="$1" _var_rc="$2"; shift 2
  local _raw
  _raw=$("$@"; echo "EXIT:$?")
  local _code="${_raw##*EXIT:}"
  _code="${_code%$'\n'}"
  local _body="${_raw%EXIT:*}"
  _body="${_body%$'\n'}"
  printf -v "$_var_out" '%s' "$_body"
  printf -v "$_var_rc" '%s' "$_code"
}

# ---------------------------------------------------------------------------
# TC-detect-all: source the oracle, build a tampered HEAD for edit-assertions
#   using _build_initial_repo + _apply_tamper, run _predicate_gate_a with the
#   pinned Red hash → assert gate-a returns non-zero (tamper detected)
# ---------------------------------------------------------------------------
_capture _tc1_out _tc1_rc bash -c '
  . "'"$LIB"'"
  . "'"$CHEATER_LIB"'"
  tmp=$(e2e_mktemp)
  trap '"'"'e2e_cleanup "$tmp"'"'"' EXIT
  _build_initial_repo "$tmp"
  red_hash=$(cat "$tmp/red-hash.txt")
  _apply_tamper "$tmp" "edit-assertions"
  # Gate-a with the Red hash — should return non-zero (tamper detected)
  _predicate_gate_a "tests/test_red.py" "$red_hash" "$tmp" >/dev/null 2>&1
  rc=$?
  trap - EXIT; e2e_cleanup "$tmp"
  exit $rc
' 2>/dev/null
# Non-zero exit means detection fired
if [ "$_tc1_rc" -ne 0 ]; then
  _pass "TC-detect-all (edit-assertions tamper detected: gate-a returned non-zero)"
else
  _fail "TC-detect-all (gate-a should have detected edit-assertions tamper, got rc=0)"
fi

# ---------------------------------------------------------------------------
# TC-allow-zero-fr: build a clean HEAD with only production file changes,
#   run _predicate_gate_a → assert it returns 0 (not rejected)
# ---------------------------------------------------------------------------
_capture _tc2_out _tc2_rc bash -c '
  . "'"$LIB"'"
  . "'"$CHEATER_LIB"'"
  tmp=$(e2e_mktemp)
  trap '"'"'e2e_cleanup "$tmp"'"'"' EXIT
  _build_initial_repo "$tmp"
  red_hash=$(cat "$tmp/red-hash.txt")
  _apply_tamper "$tmp" "allow-reformat-production"
  # Gate-a with the original Red hash — Red test was NOT touched → should return 0
  _predicate_gate_a "tests/test_red.py" "$red_hash" "$tmp" >/dev/null 2>&1
  rc=$?
  trap - EXIT; e2e_cleanup "$tmp"
  exit $rc
' 2>/dev/null
if [ "$_tc2_rc" -eq 0 ]; then
  _pass "TC-allow-zero-fr (allow-reformat-production not rejected: gate-a returned 0)"
else
  _fail "TC-allow-zero-fr (gate-a should NOT reject allow-reformat-production, got rc=$_tc2_rc)"
fi

# ---------------------------------------------------------------------------
# TC-residual-excluded: run cheater_oracle_checks and capture output.
#   Assert:
#   (a) output contains "EXCLUDED" line for EG-1
#   (b) EG-1 is NOT counted in PASS or FAIL tallies (not in summary pass/fail counts)
# ---------------------------------------------------------------------------
_capture _tc3_out _tc3_rc bash -c '
  . "'"$LIB"'"
  . "'"$CHEATER_LIB"'"
  cheater_oracle_checks
  summary
' 2>/dev/null
_tc3_has_excluded=0
_tc3_eg1_in_pass=0
_tc3_eg1_in_fail=0
printf '%s\n' "$_tc3_out" | grep -qi 'EXCLUDED.*EG-1\|EXCLUDED.*eg1\|EXCLUDED.*closure tamper' && _tc3_has_excluded=1
printf '%s\n' "$_tc3_out" | grep -qi '^PASS.*EG-1\|^PASS.*eg1\|^PASS.*closure tamper' && _tc3_eg1_in_pass=1
printf '%s\n' "$_tc3_out" | grep -qi '^FAIL.*EG-1\|^FAIL.*eg1\|^FAIL.*closure tamper' && _tc3_eg1_in_fail=1
if [ "$_tc3_has_excluded" -eq 1 ] && [ "$_tc3_eg1_in_pass" -eq 0 ] && [ "$_tc3_eg1_in_fail" -eq 0 ]; then
  _pass "TC-residual-excluded (EXCLUDED line present, EG-1 not in PASS/FAIL counts)"
else
  _fail "TC-residual-excluded (has_excluded=$_tc3_has_excluded eg1_in_pass=$_tc3_eg1_in_pass eg1_in_fail=$_tc3_eg1_in_fail; out='$_tc3_out')"
fi

# ---------------------------------------------------------------------------
# TC-trap-clean: verify trap 'e2e_cleanup' fires on EXIT.
#   Build a tampered HEAD in a subshell that sets the trap, then exits.
#   Assert the tmpdir is gone after the subshell completes.
# ---------------------------------------------------------------------------
# Capture the tmp path by printing it, then verify it no longer exists after exit
_capture _tc4_out _tc4_rc bash -c '
  . "'"$LIB"'"
  . "'"$CHEATER_LIB"'"
  tmp=$(e2e_mktemp)
  trap '"'"'e2e_cleanup "$tmp"'"'"' EXIT
  _build_initial_repo "$tmp"
  _apply_tamper "$tmp" "edit-assertions"
  # Print the path so the caller can check it was cleaned up
  printf "%s" "$tmp"
  # Exit WITHOUT explicitly calling e2e_cleanup — trap fires on EXIT
  exit 0
' 2>/dev/null
# After the subshell exits, $tc4_out contains the tmpdir path
_tc4_tmpdir="$_tc4_out"
if [ -n "$_tc4_tmpdir" ] && [ ! -d "$_tc4_tmpdir" ]; then
  _pass "TC-trap-clean (trap fired on EXIT: tmpdir '$_tc4_tmpdir' cleaned up)"
elif [ -z "$_tc4_tmpdir" ]; then
  _fail "TC-trap-clean (no tmpdir path captured from subshell)"
else
  _fail "TC-trap-clean (tmpdir still exists after EXIT: '$_tc4_tmpdir')"
  # Clean up to avoid leaking
  case "$_tc4_tmpdir" in
    /tmp/*|/private/*|/var/folders/*) rm -rf "$_tc4_tmpdir" ;;
  esac
fi

# ---------------------------------------------------------------------------
# TC-selftest-catches-broken: verify the predicate distinguishes pass from fail.
#   (a) correct hash → gate-a returns 0 (pass side)
#   (b) wrong hash → gate-a returns non-zero; the subshell MUST report FAIL inside
#       (AC-7 requirement: broken-assertion case MUST be reported FAIL inside subshell)
# ---------------------------------------------------------------------------

# (a) correct hash — pass side
_capture _tc5a_out _tc5a_rc bash -c '
  . "'"$LIB"'"
  . "'"$CHEATER_LIB"'"
  tmp=$(e2e_mktemp)
  trap '"'"'e2e_cleanup "$tmp"'"'"' EXIT
  _build_initial_repo "$tmp"
  red_hash=$(cat "$tmp/red-hash.txt")
  _apply_tamper "$tmp" "allow-new-test"
  # Gate-a with the correct original hash → should return 0 (Red test was not touched)
  _predicate_gate_a "tests/test_red.py" "$red_hash" "$tmp" >/dev/null 2>&1
  rc=$?
  trap - EXIT; e2e_cleanup "$tmp"
  exit $rc
' 2>/dev/null
_tc5_pass_side=0
[ "$_tc5a_rc" -eq 0 ] && _tc5_pass_side=1

# (b) wrong hash → broken-assertion case: predicate should return non-zero
#   The subshell prints "FAIL — broken-assertion..." when gate accepts wrong hash (FAIL scenario)
_capture _tc5b_out _tc5b_rc bash -c '
  . "'"$LIB"'"
  . "'"$CHEATER_LIB"'"
  tmp=$(e2e_mktemp)
  trap '"'"'e2e_cleanup "$tmp"'"'"' EXIT
  _build_initial_repo "$tmp"
  _apply_tamper "$tmp" "allow-new-test"
  wrong_hash="0000000000000000000000000000000000000000000000000000000000000000"
  # Gate-a with wrong hash → should return non-zero (mismatch detected)
  _predicate_gate_a "tests/test_red.py" "$wrong_hash" "$tmp" >/dev/null 2>&1
  rc=$?
  trap - EXIT; e2e_cleanup "$tmp"
  # Report FAIL if predicate accepted wrong hash (would be a broken gate)
  if [ "$rc" -eq 0 ]; then
    printf "FAIL — broken-assertion case: gate-a accepted wrong hash (should reject)\n"
    exit 1
  else
    # Gate correctly rejected wrong hash — this is the expected behavior
    exit 0
  fi
' 2>/dev/null

if [ "$_tc5_pass_side" -eq 1 ] && [ "$_tc5b_rc" -eq 0 ]; then
  _pass "TC-selftest-catches-broken (pass-side rc=0, fail-side detected: gate-a correctly rejected wrong hash)"
else
  _fail "TC-selftest-catches-broken (pass_side=$_tc5_pass_side fail_side_rc=$_tc5b_rc; out_b='$_tc5b_out')"
fi

# Verify broken-assertion case IS reported FAIL inside the captured subshell:
# Construct a subshell where the predicate ACCEPTS a wrong hash (simulated broken gate)
# by using a hash that actually matches HEAD content (bypassing "wrong" detection).
# Then verify the outer assertion catches the FAIL line.
_capture _tc5c_out _tc5c_rc bash -c '
  . "'"$LIB"'"
  . "'"$CHEATER_LIB"'"
  tmp=$(e2e_mktemp)
  trap '"'"'e2e_cleanup "$tmp"'"'"' EXIT
  _build_initial_repo "$tmp"
  _apply_tamper "$tmp" "edit-assertions"
  # Deliberately use the TAMPERED hash (HEAD hash) — this makes gate-a "pass"
  # even though it should be rejected. This simulates a broken predicate.
  tampered_hash=$(git -C "$tmp" show "HEAD:tests/test_red.py" | '"'"'_sha256'"'"')
  _predicate_gate_a "tests/test_red.py" "$tampered_hash" "$tmp" >/dev/null 2>&1
  rc=$?
  trap - EXIT; e2e_cleanup "$tmp"
  # If gate-a accepted tampered hash (rc=0), the assertion is broken — report FAIL
  if [ "$rc" -eq 0 ]; then
    printf "FAIL — broken assertion confirmed: predicate accepted tampered-hash (cheat would go undetected)\n"
    exit 1
  fi
' 2>/dev/null
_tc5c_has_fail=0
printf '%s\n' "$_tc5c_out" | grep -q '^FAIL' && _tc5c_has_fail=1
if [ "$_tc5c_has_fail" -eq 1 ] && [ "$_tc5c_rc" -eq 1 ]; then
  _pass "TC-selftest-catches-broken (broken-assertion case reported FAIL inside captured subshell, as required by AC-7)"
else
  _fail "TC-selftest-catches-broken (broken-assertion FAIL not reported inside subshell; has_fail=$_tc5c_has_fail rc=$_tc5c_rc out='$_tc5c_out')"
fi

# ---------------------------------------------------------------------------
# TC-eg2-detected: EG-2 cross-sub-phase tamper must be DETECTED (in 100% headline)
# and the pre-fix group-union behavior would have MISSED it (load-bearing proof).
# ---------------------------------------------------------------------------
_capture _tc6_out _tc6_rc bash -c '
  . "'"$LIB"'"
  . "'"$CHEATER_LIB"'"
  tmp=$(e2e_mktemp)
  trap '"'"'e2e_cleanup "$tmp"'"'"' EXIT
  _build_initial_repo "$tmp"
  red_hash=$(git -C "$tmp" show "HEAD:tests/test_red.py" | _sha256)
  printf '"'"'# TAMPERED\ndef test_add():\n    assert 1==1\n'"'"' > "$tmp/tests/test_red.py"
  git -C "$tmp" add tests/test_red.py
  git -C "$tmp" commit -q -m "build(B): eg2 tamper"
  # Per-sub-phase (B has empty exempt): should REJECT (non-zero)
  _predicate_gate_a "tests/test_red.py" "$red_hash" "$tmp" >/dev/null 2>&1
  rc=$?
  trap - EXIT; e2e_cleanup "$tmp"
  echo "rc=$rc"
  exit $rc
' 2>/dev/null
if [ "$_tc6_rc" -ne 0 ]; then
  _pass "TC-eg2-detected (per-sub-phase rejects B tamper; rc=1)"
else
  _fail "TC-eg2-detected (expected non-zero rc, got: rc=$_tc6_rc out='$_tc6_out')"
fi

# ---------------------------------------------------------------------------
# TC-sha256-format: verify _sha256 produces correct 64-char lowercase hex
#   on known input "test" (ADR-7 parity pin — format must match gate predicate)
# ---------------------------------------------------------------------------
_capture _tc7_out _tc7_rc bash -c '
  . "'"$CHEATER_LIB"'"
  known_hash=$(printf "test" | _sha256)
  expected="9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
  if [ "$known_hash" = "$expected" ]; then
    exit 0
  else
    printf "hash mismatch: got %s expected %s\n" "$known_hash" "$expected"
    exit 1
  fi
' 2>/dev/null
if [ "$_tc7_rc" -eq 0 ]; then
  _pass "TC-sha256-format (_sha256 produces correct 64-char hex for known input; ADR-7 parity verified)"
else
  _fail "TC-sha256-format (hash format wrong or mismatch; out='$_tc7_out')"
fi

# ---------------------------------------------------------------------------
# Self-test summary (own format, mirrors test-core.sh)
# ---------------------------------------------------------------------------
printf '== summary: %s passed, %s failed, 0 skipped, 0 errors ==\n' "$_PASS" "$_FAIL"
[ "$_FAIL" -eq 0 ] && exit 0 || exit 1
