# spec-flow e2e — verify-live + selftest
# Sourced by run-e2e.sh after assert.sh and contract.sh.
# Functions defined: verify_live, verify_live_selftest

# ---------------------------------------------------------------------------
# _vl_first_line <pattern> <file>
#   Return the first line number matching <pattern> (ERE) in <file>, or empty.
# ---------------------------------------------------------------------------
_vl_first_line() {
  grep -n -E "$1" "$2" 2>/dev/null | head -1 | cut -d: -f1
}

# ---------------------------------------------------------------------------
# verify_live <target> [transcript]
#   Run SF-3 contract checks on a post-run piece directory.
#   <target>     = path to the piece directory (may or may not have .git)
#   [transcript] = explicit path to .jsonl transcript (optional)
#
#   Three halves:
#     (1) tree half  — commit ordering (a)-(b) if .git present; (c)-(g) always
#     (2) round-trip — spike oracle propagated through plan + test file
#     (3) transcript — dispatch order, counts, markers in the .jsonl
# ---------------------------------------------------------------------------
verify_live() {
  local target="${1:-}"
  local transcript_arg="${2:-}"

  if [ -z "$target" ]; then
    err "verify_live: target directory required"
    return
  fi

  # Resolve piece dir: the piece is the target itself (plain-dir post-run fragment)
  local piece="$target"

  # -------------------------------------------------------------------------
  # (1) Tree half
  # -------------------------------------------------------------------------
  if [ -d "$target/.git" ]; then
    # Full (a)-(g): git history available
    check_commit_order "$target"
    check_transitions "$target"
    check_test_data "$piece/plan.md"
    check_spike "$piece"
    check_discovery_log "$piece"
    check_learnings "$piece"
    check_no_journal "$target"
  else
    # (c)-(g) only: no git history
    excluded "ordering checks (a)-(b): target has no git history"
    check_test_data "$piece/plan.md"
    check_spike "$piece"
    check_discovery_log "$piece"
    check_learnings "$piece"
    check_no_journal "$target"
  fi

  # -------------------------------------------------------------------------
  # (2) Round-trip half
  #   oracle = spike-resolved value from spikes/*.md
  #   assert it appears in plan.md (splice landed)
  #   assert it appears in tests/test-greet.sh (transcription landed)
  # -------------------------------------------------------------------------
  local oracle=""
  local spikes_dir="$piece/spikes"
  if ls "$spikes_dir"/*.md >/dev/null 2>&1; then
    oracle=$(grep -roh 'resolved-[A-Za-z0-9_-]*' "$spikes_dir" 2>/dev/null | head -1)
  fi

  if [ -z "$oracle" ]; then
    fail "verify-live round-trip: no spike oracle value found in $spikes_dir/*.md"
  else
    # Verify splice landed in plan.md
    assert_grep "$oracle" "$piece/plan.md" \
      "verify-live round-trip: spike oracle '$oracle' present in plan.md (splice landed)"

    # Verify transcription landed in tests/test-greet.sh
    assert_grep "$oracle" "$piece/tests/test-greet.sh" \
      "verify-live round-trip: spike oracle '$oracle' present in tests/test-greet.sh (transcription landed)"
  fi

  # -------------------------------------------------------------------------
  # (3) Transcript half
  #   Resolve transcript path:
  #     a) explicit arg
  #     b) newest *.jsonl under ~/.claude/projects/<target-path-as-dir-name>/
  #     c) unresolvable → skip_cap transcript
  # -------------------------------------------------------------------------
  local transcript=""

  if [ -n "$transcript_arg" ] && [ -s "$transcript_arg" ]; then
    transcript="$transcript_arg"
  elif [ -n "$transcript_arg" ] && [ ! -s "$transcript_arg" ]; then
    # Explicit arg provided but file is absent or empty → skip transcript half
    skip_cap transcript "transcript not found: $transcript_arg (tree+round-trip checks already ran)"
    return
  else
    # Auto-discover: newest *.jsonl under ~/.claude/projects/<encoded-target>/
    local encoded
    encoded=$(printf '%s' "$target" | tr '/' '-')
    local projects_dir="$HOME/.claude/projects/${encoded}"
    if [ -d "$projects_dir" ]; then
      transcript=$(ls -t "$projects_dir"/*.jsonl 2>/dev/null | head -1)
    fi
    if [ -z "$transcript" ] || [ ! -s "$transcript" ]; then
      skip_cap transcript "no transcript found for target: $target (tree+round-trip checks already ran)"
      return
    fi
  fi

  # ADR-5 dispatch patterns
  local pat_tdd='\"subagent_type\"[[:space:]]*:[[:space:]]*\"spec-flow:tdd-red\"'
  local pat_qa='\"subagent_type\"[[:space:]]*:[[:space:]]*\"spec-flow:qa-tdd-red\"'
  local pat_impl='\"subagent_type\"[[:space:]]*:[[:space:]]*\"spec-flow:implementer\"'
  local pat_verify='\"subagent_type\"[[:space:]]*:[[:space:]]*\"spec-flow:verify\"'
  local pat_spike='\"subagent_type\"[[:space:]]*:[[:space:]]*\"spec-flow:spike\"'

  # Get first-occurrence line numbers
  local ln_tdd ln_qa ln_impl ln_verify ln_spike
  ln_tdd=$(_vl_first_line "$pat_tdd" "$transcript")
  ln_qa=$(_vl_first_line "$pat_qa" "$transcript")
  ln_impl=$(_vl_first_line "$pat_impl" "$transcript")
  ln_verify=$(_vl_first_line "$pat_verify" "$transcript")
  ln_spike=$(_vl_first_line "$pat_spike" "$transcript")

  # Order check: tdd-red < qa-tdd-red < implementer < verify (first occurrences)
  local order_ok=1
  if [ -z "$ln_tdd" ] || [ -z "$ln_qa" ] || [ -z "$ln_impl" ] || [ -z "$ln_verify" ]; then
    fail "verify-live transcript: one or more dispatch tokens missing (tdd-red=$ln_tdd qa-tdd-red=$ln_qa implementer=$ln_impl verify=$ln_verify)"
    order_ok=0
  elif [ "$ln_tdd" -lt "$ln_qa" ] && [ "$ln_qa" -lt "$ln_impl" ] && [ "$ln_impl" -lt "$ln_verify" ]; then
    pass "verify-live transcript: dispatch order tdd-red < qa-tdd-red < implementer < verify"
  else
    fail "verify-live transcript: dispatch order misordered (tdd-red=$ln_tdd qa-tdd-red=$ln_qa implementer=$ln_impl verify=$ln_verify)"
    order_ok=0
  fi

  # tdd-red count == 3 (Implement phase dispatched none)
  assert_count "$pat_tdd" "$transcript" 3 \
    "verify-live transcript: tdd-red dispatch count == 3"

  # spike line# < phase-3 evidence (second tdd-red after spike)
  if [ -n "$ln_spike" ]; then
    # Find the first tdd-red line AFTER the spike line
    local ln_tdd_after_spike
    ln_tdd_after_spike=$(grep -n -E "$pat_tdd" "$transcript" 2>/dev/null \
      | awk -F: -v sp="$ln_spike" '$1 > sp { print $1; exit }')
    if [ -n "$ln_tdd_after_spike" ] && [ "$ln_spike" -lt "$ln_tdd_after_spike" ]; then
      pass "verify-live transcript: spike (line $ln_spike) precedes phase-3 tdd-red (line $ln_tdd_after_spike)"
    else
      fail "verify-live transcript: spike not found before a subsequent tdd-red (spike=$ln_spike)"
    fi
  else
    fail "verify-live transcript: no spec-flow:spike dispatch found"
  fi

  # review-board present
  assert_grep 'review-board-' "$transcript" \
    "verify-live transcript: review-board dispatch present"

  # [TEST-DATA-ABSENT marker emitted
  assert_grep '\[TEST-DATA-ABSENT' "$transcript" \
    "verify-live transcript: [TEST-DATA-ABSENT marker present"
}

# ---------------------------------------------------------------------------
# verify_live_selftest()
#   Runs the three canonical substrate pairs and reports expected outcomes.
#   Called in default run mode by run-e2e.sh via run_mode.
# ---------------------------------------------------------------------------
verify_live_selftest() {
  local e2e="${E2E_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  local clean_target="$e2e/fixtures/post-run/clean"
  local broken_target="$e2e/fixtures/post-run/broken"
  local clean_transcript="$e2e/fixtures/transcript/clean.jsonl"
  local broken_transcript="$e2e/fixtures/transcript/broken.jsonl"

  # -----------------------------------------------------------------------
  # Case vl-1: clean pair → all checks PASS (no FAILs expected)
  # -----------------------------------------------------------------------
  local vl1_out
  vl1_out=$(
    PASSES=0; FAILS=0; SKIPS=0; ERRORS=0
    . "$e2e/lib/assert.sh"
    . "$e2e/lib/contract.sh"
    . "$e2e/lib/live.sh"
    verify_live "$clean_target" "$clean_transcript"
  )
  local vl1_fails
  vl1_fails=$(printf '%s\n' "$vl1_out" | grep -c '^FAIL' || true)
  if [ "$vl1_fails" -eq 0 ]; then
    pass "vl-selftest clean pair: 0 FAILs (all checks passed)"
  else
    fail "vl-selftest clean pair: expected 0 FAILs, got $vl1_fails"
    printf '%s\n' "$vl1_out" | grep '^FAIL' | sed 's/^/  /' >&2
  fi

  # Also verify EXCLUDED line for (a)-(b) is present (no .git in plain-dir fixture)
  if printf '%s\n' "$vl1_out" | grep -q 'EXCLUDED.*ordering checks'; then
    pass "vl-selftest clean pair: EXCLUDED line for (a)-(b) present"
  else
    fail "vl-selftest clean pair: EXCLUDED line for (a)-(b) not found"
  fi

  # -----------------------------------------------------------------------
  # Case vl-2: broken post-run (test file lacks oracle) → round-trip FAIL
  #            Use clean transcript (tree/transcript should pass; only rt fails)
  # -----------------------------------------------------------------------
  local vl2_out
  vl2_out=$(
    PASSES=0; FAILS=0; SKIPS=0; ERRORS=0
    . "$e2e/lib/assert.sh"
    . "$e2e/lib/contract.sh"
    . "$e2e/lib/live.sh"
    verify_live "$broken_target" "$clean_transcript"
  )
  local vl2_fail_lines
  vl2_fail_lines=$(printf '%s\n' "$vl2_out" | grep '^FAIL' || true)
  # Must contain at least one FAIL referencing test-greet.sh
  if printf '%s\n' "$vl2_fail_lines" | grep -q 'test-greet.sh'; then
    pass "vl-selftest broken post-run: round-trip test-file FAIL fires (label contains test-greet.sh)"
  else
    fail "vl-selftest broken post-run: expected FAIL containing 'test-greet.sh', got: $(printf '%s\n' "$vl2_fail_lines" | head -3)"
  fi

  # -----------------------------------------------------------------------
  # Case vl-3: broken transcript → ordering FAIL + count FAIL + TEST-DATA-ABSENT FAIL
  #            Use clean post-run target with broken transcript
  # -----------------------------------------------------------------------
  local vl3_out
  vl3_out=$(
    PASSES=0; FAILS=0; SKIPS=0; ERRORS=0
    . "$e2e/lib/assert.sh"
    . "$e2e/lib/contract.sh"
    . "$e2e/lib/live.sh"
    verify_live "$clean_target" "$broken_transcript"
  )
  local vl3_fail_lines
  vl3_fail_lines=$(printf '%s\n' "$vl3_out" | grep '^FAIL' || true)
  local vl3_ok=1

  # Ordering FAIL
  if printf '%s\n' "$vl3_fail_lines" | grep -q 'dispatch order'; then
    pass "vl-selftest broken transcript: dispatch order FAIL fires"
  else
    fail "vl-selftest broken transcript: expected dispatch order FAIL not found"
    vl3_ok=0
  fi

  # Count FAIL (tdd-red count != 3)
  if printf '%s\n' "$vl3_fail_lines" | grep -q 'tdd-red dispatch count'; then
    pass "vl-selftest broken transcript: tdd-red count FAIL fires"
  else
    fail "vl-selftest broken transcript: expected tdd-red count FAIL not found"
    vl3_ok=0
  fi

  # TEST-DATA-ABSENT FAIL
  if printf '%s\n' "$vl3_fail_lines" | grep -q 'TEST-DATA-ABSENT'; then
    pass "vl-selftest broken transcript: [TEST-DATA-ABSENT FAIL fires"
  else
    fail "vl-selftest broken transcript: expected [TEST-DATA-ABSENT FAIL not found"
    vl3_ok=0
  fi

  # -----------------------------------------------------------------------
  # Case vl-4: missing transcript → SKIPPED: transcript; tree-half PASS lines present
  # -----------------------------------------------------------------------
  local vl4_out
  vl4_out=$(
    PASSES=0; FAILS=0; SKIPS=0; ERRORS=0
    . "$e2e/lib/assert.sh"
    . "$e2e/lib/contract.sh"
    . "$e2e/lib/live.sh"
    verify_live "$clean_target" "/nonexistent.jsonl"
  )

  # Must contain SKIPPED: transcript
  if printf '%s\n' "$vl4_out" | grep -q 'SKIPPED: transcript'; then
    pass "vl-selftest missing transcript: SKIPPED: transcript emitted"
  else
    fail "vl-selftest missing transcript: expected 'SKIPPED: transcript' not found"
  fi

  # Tree-half PASS lines must be present (EXCLUDED line confirms tree half ran)
  if printf '%s\n' "$vl4_out" | grep -q 'EXCLUDED.*ordering checks'; then
    pass "vl-selftest missing transcript: tree-half checks ran (EXCLUDED (a)-(b) present)"
  else
    fail "vl-selftest missing transcript: tree-half checks did not run"
  fi

  # Must have no FAILs (tree/round-trip of clean target should all pass)
  local vl4_fails
  vl4_fails=$(printf '%s\n' "$vl4_out" | grep -c '^FAIL' || true)
  if [ "$vl4_fails" -eq 0 ]; then
    pass "vl-selftest missing transcript: tree+round-trip PASS (no FAILs)"
  else
    fail "vl-selftest missing transcript: unexpected FAILs ($vl4_fails): $(printf '%s\n' "$vl4_out" | grep '^FAIL' | head -2)"
  fi
}
