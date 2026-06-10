# spec-flow e2e — L2 assertion core + audit mode
# Sourced by run-e2e.sh after assert.sh.
# Functions defined: check_commit_order, check_transitions, check_test_data,
#   check_spike, check_discovery_log, check_learnings, check_no_journal,
#   l2_replay_checks, audit_checks.

# ---------------------------------------------------------------------------
# (a) check_commit_order <repo>
#   Assert the SF-3 commit ordering invariant via assert_subject_order pairs.
# ---------------------------------------------------------------------------
check_commit_order() {
  local repo="$1"
  assert_subject_order "$repo" "research: " "spec: add" \
    "L2(a) research before spec"
  assert_subject_order "$repo" "spec: add" "plan: add" \
    "L2(a) spec before plan"
  assert_subject_order "$repo" "plan: add" "manifest: mark demo/hello as in-progress" \
    "L2(a) plan before in-progress"
  assert_subject_order "$repo" "manifest: mark demo/hello as in-progress" "feat(demo): phase 1" \
    "L2(a) in-progress before phase-1"
  assert_subject_order "$repo" "learnings: " "manifest: mark demo/hello as merged" \
    "L2(a) learnings before merged"
}

# ---------------------------------------------------------------------------
# (b) check_transitions <repo>
#   Assert manifest transition order: specced < planned < in-progress < merged.
#   Uses first occurrence in reverse-chronological git log (--reverse = oldest first).
# ---------------------------------------------------------------------------
check_transitions() {
  local repo="$1"
  local log
  log=$(git -C "$repo" log --reverse --format="%s" 2>/dev/null)

  local _find_line
  _find_line() {
    printf '%s\n' "$log" | awk -v t="$1" 'index($0, t) > 0 { print NR; exit }'
  }

  local line_specced line_planned line_inprog line_merged
  line_specced=$(_find_line "as specced")
  line_planned=$(_find_line "as planned")
  line_inprog=$(_find_line "as in-progress")
  line_merged=$(_find_line "as merged")

  # Each transition must be present
  if [ -z "$line_specced" ]; then
    fail "L2(b) transition 'as specced' missing from git log"
    return
  fi
  if [ -z "$line_planned" ]; then
    fail "L2(b) transition 'as planned' missing from git log"
    return
  fi
  if [ -z "$line_inprog" ]; then
    fail "L2(b) transition 'as in-progress' missing from git log"
    return
  fi
  if [ -z "$line_merged" ]; then
    fail "L2(b) transition 'as merged' missing from git log"
    return
  fi

  # Check ordering
  if [ "$line_specced" -lt "$line_planned" ] && \
     [ "$line_planned" -lt "$line_inprog" ] && \
     [ "$line_inprog"  -lt "$line_merged" ]; then
    pass "L2(b) manifest transitions in order: specced < planned < in-progress < merged"
  else
    fail "L2(b) manifest transitions misordered (specced=$line_specced planned=$line_planned in-progress=$line_inprog merged=$line_merged)"
  fi
}

# ---------------------------------------------------------------------------
# (c) check_test_data <plan-file>
#   Every '### Phase' section containing '[TDD-Red]' or '[Write-Tests]' must
#   contain '**Test Data:**' before the next '### ' heading.
#   FAIL names the offending phase heading.
# ---------------------------------------------------------------------------
check_test_data() {
  local plan="$1"
  if [ ! -f "$plan" ]; then
    fail "L2(c) plan file missing: $plan"
    return
  fi

  local result
  result=$(awk '
    /^### / {
      # If we were in a TDD section without Test Data, report failure
      if (in_phase && in_tdd && !has_test_data) {
        print "FAIL:" heading
      }
      # Start tracking a new ### Phase section
      heading = $0
      in_phase = 1
      in_tdd = 0
      has_test_data = 0
    }
    in_phase && /\*\*Test Data:\*\*/ { has_test_data = 1 }
    in_phase && /\[TDD-Red\]|\[Write-Tests\]/ { in_tdd = 1 }
    END {
      if (in_phase && in_tdd && !has_test_data) {
        print "FAIL:" heading
      }
    }
  ' "$plan")

  if [ -z "$result" ]; then
    pass "L2(c) all TDD/Write-Tests phases have Test Data"
  else
    while IFS= read -r line; do
      local heading="${line#FAIL:}"
      fail "L2(c) missing Test Data in: $heading"
    done <<< "$result"
  fi
}

# ---------------------------------------------------------------------------
# (d) check_spike <piece-dir>
#   If plan.md contains '[SPIKE:' (live marker), spikes/*.md must exist AND
#   each must contain '**Mode:**', '**Trigger:**', '**Resolution:**'.
#   Also: any spikes/*.md present must conform to those three fields.
# ---------------------------------------------------------------------------
check_spike() {
  local piece="$1"
  local plan="$piece/plan.md"

  if [ ! -f "$plan" ]; then
    fail "L2(d) plan.md missing: $plan"
    return
  fi

  # Check for any spikes/*.md present — must conform regardless of marker
  local any_spike_fails=0
  if ls "$piece/spikes/"*.md >/dev/null 2>&1; then
    local spike_file
    for spike_file in "$piece/spikes/"*.md; do
      local missing_fields=""
      grep -F -q '**Mode:**' "$spike_file"        2>/dev/null || missing_fields="$missing_fields **Mode:**"
      grep -F -q '**Trigger:**' "$spike_file"     2>/dev/null || missing_fields="$missing_fields **Trigger:**"
      grep -F -q '**Resolution:**' "$spike_file"  2>/dev/null || missing_fields="$missing_fields **Resolution:**"
      grep -F -q '**Test Data:**' "$spike_file"   2>/dev/null || missing_fields="$missing_fields **Test Data:**"
      if [ -n "$missing_fields" ]; then
        fail "L2(d) spike artifact $(basename "$spike_file") missing fields:$missing_fields"
        any_spike_fails=1
      fi
    done
  fi

  # If plan has a live SPIKE marker, require spikes/*.md exist
  if grep -F -q '[SPIKE:' "$plan" 2>/dev/null; then
    if ls "$piece/spikes/"*.md >/dev/null 2>&1; then
      if [ "$any_spike_fails" -eq 0 ]; then
        pass "L2(d) spike artifact present and conforms"
      fi
      # else individual failures already emitted above
    else
      fail "L2(d) plan has [SPIKE: marker but spikes/ has no .md artifacts"
    fi
  else
    # No live spike marker
    if [ "$any_spike_fails" -eq 0 ]; then
      pass "L2(d) spike check: no live marker, no malformed artifacts"
    fi
  fi
}

# ---------------------------------------------------------------------------
# (e) check_discovery_log <piece-dir>
#   .discovery-log.md must exist and its first table row must match the
#   6-column header exactly.
# ---------------------------------------------------------------------------
check_discovery_log() {
  local piece="$1"
  local log_file="$piece/.discovery-log.md"
  local header="| Phase | Discovery type | Source agent | Finding (1-line) | Triage choice | Resolution commit |"

  if [ ! -f "$log_file" ]; then
    fail "L2(e) .discovery-log.md missing: $log_file"
    return
  fi

  if grep -F -q "$header" "$log_file" 2>/dev/null; then
    pass "L2(e) .discovery-log.md header present"
  else
    fail "L2(e) .discovery-log.md missing 6-column header row"
  fi
}

# ---------------------------------------------------------------------------
# (f) check_learnings <piece-dir>
#   learnings.md must exist and be non-empty.
# ---------------------------------------------------------------------------
check_learnings() {
  local piece="$1"
  assert_file "$piece/learnings.md" "L2(f) learnings.md present and non-empty"
}

# ---------------------------------------------------------------------------
# (g) check_no_journal <repo>
#   .phase-group-journal.json must NOT exist at the repo root.
# ---------------------------------------------------------------------------
check_no_journal() {
  local repo="$1"
  local journal="$repo/.phase-group-journal.json"
  if [ ! -e "$journal" ]; then
    pass "L2(g) no stale .phase-group-journal.json at repo root"
  else
    fail "L2(g) stale .phase-group-journal.json found at repo root: $journal"
  fi
}

# ---------------------------------------------------------------------------
# l2_replay_checks()
#   ① Build clean fixture, run all checks (a)–(g), clean up.
#   ② For each of 6 break cases: build fixture, assert targeted check FAILS,
#      report as pass "break:<case> fires <check>".
#      Also: isolation spot-check on journal-survives — other six checks pass.
# ---------------------------------------------------------------------------
l2_replay_checks() {
  local builder="$E2E_DIR/build-fixture.sh"

  # ① Clean fixture — all checks must PASS
  local t
  t=$(e2e_mktemp)
  bash "$builder" "$t"
  local piece="$t/docs/prds/demo/specs/hello"
  check_commit_order "$t"
  check_transitions "$t"
  check_test_data "$piece/plan.md"
  check_spike "$piece"
  check_discovery_log "$piece"
  check_learnings "$piece"
  check_no_journal "$t"
  e2e_cleanup "$t"

  # ② Break loop — targeted check must FAIL (expected-fail wrapper)
  # Map: break-case → targeted check function + args + friendly name
  local cases="research-after-spec no-test-data no-spike-artifact skip-transition journal-survives missing-learnings"

  local c
  for c in $cases; do
    local bt
    bt=$(e2e_mktemp)
    if ! bash "$builder" "$bt" "--break=$c"; then
      fail "build-fixture failed for break:$c"
      e2e_cleanup "$bt"
      continue
    fi
    local bp="$bt/docs/prds/demo/specs/hello"

    # Determine which check to run for this break case
    local check_output=""
    case "$c" in
      research-after-spec)
        check_output=$(check_commit_order "$bt" 2>&1)
        _assert_break_fires "$c" "check_commit_order" "$check_output" "research: "
        ;;
      no-test-data)
        check_output=$(check_test_data "$bp/plan.md" 2>&1)
        _assert_break_fires "$c" "check_test_data" "$check_output" "Phase 1"
        ;;
      no-spike-artifact)
        check_output=$(check_spike "$bp" 2>&1)
        _assert_break_fires "$c" "check_spike" "$check_output" "spikes/"
        ;;
      skip-transition)
        check_output=$(check_transitions "$bt" 2>&1)
        _assert_break_fires "$c" "check_transitions" "$check_output" "planned"
        ;;
      journal-survives)
        check_output=$(check_no_journal "$bt" 2>&1)
        _assert_break_fires "$c" "check_no_journal" "$check_output" '.phase-group-journal.json'
        # Isolation spot-check: the OTHER six checks must still pass on this variant
        _run_isolation_checks "$bt" "$bp"
        ;;
      missing-learnings)
        check_output=$(check_learnings "$bp" 2>&1)
        _assert_break_fires "$c" "check_learnings" "$check_output" "learnings.md"
        ;;
    esac

    e2e_cleanup "$bt"
  done
}

# _assert_break_fires <case> <check-name> <output> <pattern>
#   Inspects captured output for a FAIL line that starts with "FAIL" and
#   contains <pattern> as a fixed substring.
_assert_break_fires() {
  local case_id="$1" check_name="$2" output="$3" pattern="$4"
  # Filter to lines beginning with "FAIL" then look for the expected substring
  if printf '%s\n' "$output" | grep '^FAIL' | grep -qF "$pattern"; then
    pass "break:$case_id fires $check_name"
  else
    fail "break:$case_id did NOT fire $check_name (no ^FAIL.*$pattern in output)"
  fi
}

# _run_isolation_checks <repo> <piece>
#   Run the six checks OTHER than check_no_journal on the journal-survives fixture.
#   All should pass (single-defect isolation).
_run_isolation_checks() {
  local repo="$1" piece="$2"
  check_commit_order "$repo"
  check_transitions "$repo"
  check_test_data "$piece/plan.md"
  check_spike "$piece"
  check_discovery_log "$piece"
  check_learnings "$piece"
}

# ---------------------------------------------------------------------------
# audit_checks <piece-dir>
#   Shape checks only: (c)–(g) with $repo = $REPO_ROOT.
#   Ordering checks excluded (commit history unverifiable post squash-merge).
#   <piece-dir> may be relative (resolved against REPO_ROOT) or absolute.
# ---------------------------------------------------------------------------
audit_checks() {
  local piece_arg="$1"
  # Resolve piece dir: absolute passes through; relative resolved against REPO_ROOT
  local piece
  case "$piece_arg" in
    /*) piece="$piece_arg" ;;
    *)  piece="${REPO_ROOT}/${piece_arg}" ;;
  esac

  excluded "ordering checks (a)-(b): commit ordering unverifiable post squash-merge"
  check_test_data "$piece/plan.md"
  check_spike "$piece"
  check_discovery_log "$piece"
  check_learnings "$piece"
  check_no_journal "$REPO_ROOT"
}
