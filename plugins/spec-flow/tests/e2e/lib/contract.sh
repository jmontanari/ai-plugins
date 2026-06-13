# spec-flow e2e — L2 assertion core + audit mode
# Sourced by run-e2e.sh after assert.sh.
# Functions defined: check_commit_order, check_transitions, check_test_data,
#   check_spike, check_discovery_log, check_learnings, check_no_journal,
#   check_red_manifest_conftest, check_gate_fixtures, check_authored_tests_criterion,
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
# (h) check_red_manifest_conftest
#   The Red-stage manifest fixture must include a conftest.py entry in
#   `- path: sha` format, confirming fixture/conftest enrichment (AC-4 manifest half).
#   Cross-checked by Phase 3's trip test (AC-4 trip half).
# ---------------------------------------------------------------------------
check_red_manifest_conftest() {
  local fixture="${PLUGIN_ROOT}/tests/e2e/fixtures/replay/tdd-red-manifest-with-conftest.md"
  assert_file "$fixture" "L2(h) Red-stage manifest fixture with conftest present"

  if grep -qE '^- [^ ]+/conftest\.py: [0-9a-f]' "$fixture" 2>/dev/null; then
    pass "L2(h) Red-manifest fixture includes conftest.py as a protected path"
  else
    fail "L2(h) Red-manifest fixture missing conftest.py in '- path: sha' format"
  fi

  if grep -qE '^- [^ ]+\.py: [0-9a-f].+\(directly imported' "$fixture" 2>/dev/null; then
    pass "L2(h) Red-manifest fixture includes directly-imported helper as a protected path"
  else
    fail "L2(h) Red-manifest fixture missing directly-imported helper in '- path: sha (directly imported...)' format"
  fi
}

# ---------------------------------------------------------------------------
# (i) check_gate_fixtures
#   Gate scenario fixtures (AC-4 trip / AC-5 exempt / AC-6 smuggling) must:
#   - Exist as fixture files in fixtures/replay/
#   - Contain the expected gate-outcome keywords confirming the scenario narrative
# ---------------------------------------------------------------------------
check_gate_fixtures() {
  local fix_dir="${PLUGIN_ROOT}/tests/e2e/fixtures/replay"

  # AC-4 trip: conftest.py in manifest → integrity fail (conftest is protected)
  local f4="${fix_dir}/gate-ac4-trip.md"
  assert_file "$f4" "L2(i) AC-4 trip gate fixture present"
  if grep -qF "integrity fail" "$f4" 2>/dev/null; then
    pass "L2(i) AC-4 trip fixture asserts 'integrity fail' outcome"
  else
    fail "L2(i) AC-4 trip fixture missing 'integrity fail' outcome"
  fi
  if grep -qF "conftest.py" "$f4" 2>/dev/null; then
    pass "L2(i) AC-4 trip fixture names conftest.py as the violating path"
  else
    fail "L2(i) AC-4 trip fixture does not name conftest.py as the violating path"
  fi

  # AC-5 exempt: Authored-tests declared test passes reconciliation (no stray-file flag)
  local f5="${fix_dir}/gate-ac5-exempt.md"
  assert_file "$f5" "L2(i) AC-5 exempt gate fixture present"
  if grep -qF "pass" "$f5" 2>/dev/null && grep -qF "exempt_authored" "$f5" 2>/dev/null; then
    pass "L2(i) AC-5 exempt fixture asserts pass via exempt_authored"
  else
    fail "L2(i) AC-5 exempt fixture missing 'pass' + 'exempt_authored' outcome"
  fi
  if grep -qF "Authored-tests" "$f5" 2>/dev/null; then
    pass "L2(i) AC-5 exempt fixture references Authored-tests field"
  else
    fail "L2(i) AC-5 exempt fixture missing Authored-tests reference"
  fi

  # AC-6 smuggling: Authored-tests lists Red-manifest path → HARD REJECT
  local f6="${fix_dir}/gate-ac6-smuggling.md"
  assert_file "$f6" "L2(i) AC-6 smuggling gate fixture present"
  if grep -qF "HARD REJECT" "$f6" 2>/dev/null; then
    pass "L2(i) AC-6 smuggling fixture asserts HARD REJECT outcome"
  else
    fail "L2(i) AC-6 smuggling fixture missing 'HARD REJECT' outcome"
  fi
  if grep -qF "exemption ignored" "$f6" 2>/dev/null; then
    pass "L2(i) AC-6 smuggling fixture confirms exemption is ignored"
  else
    fail "L2(i) AC-6 smuggling fixture missing 'exemption ignored' confirmation"
  fi
}

# ---------------------------------------------------------------------------
# (j) check_authored_tests_criterion
#   qa-plan.md criterion 32 must handle all three AC-6 qa-plan scenarios:
#   - collision (must-fix)   — "smuggling" keyword in criterion body
#   - clean (no finding)     — activation guard "absence is never a finding"
#   - no-field (no finding)  — same activation guard
#   The three fixture files confirm the scenario narratives exist on disk.
# ---------------------------------------------------------------------------
check_authored_tests_criterion() {
  local qa_plan="${PLUGIN_ROOT}/agents/qa-plan.md"
  local qa_plan_agent="${PLUGIN_ROOT}/agents/qa-plan.agent.md"
  local fix_dir="${PLUGIN_ROOT}/tests/e2e/fixtures/replay"

  # Criterion text checks
  if grep -qF "Authored-tests declaration" "$qa_plan" 2>/dev/null; then
    pass "L2(j) qa-plan.md has Authored-tests declaration criterion"
  else
    fail "L2(j) qa-plan.md missing Authored-tests declaration criterion"
  fi
  if grep -qF "absence is never a finding" "$qa_plan" 2>/dev/null; then
    pass "L2(j) qa-plan.md criterion states absence-is-never-a-finding (no-field case)"
  else
    fail "L2(j) qa-plan.md criterion missing 'absence is never a finding'"
  fi
  if grep -qF "smuggling" "$qa_plan" 2>/dev/null; then
    pass "L2(j) qa-plan.md criterion flags collision as smuggling (must-fix)"
  else
    fail "L2(j) qa-plan.md criterion missing 'smuggling' keyword for collision case"
  fi
  if grep -qF "Authored-tests declaration" "$qa_plan_agent" 2>/dev/null; then
    pass "L2(j) qa-plan.agent.md mirrors Authored-tests declaration criterion"
  else
    fail "L2(j) qa-plan.agent.md missing Authored-tests declaration criterion"
  fi

  # Fixture files confirm scenario narratives exist
  assert_file "${fix_dir}/plan-authored-tests-collision.md" \
    "L2(j) Authored-tests collision scenario fixture present"
  assert_file "${fix_dir}/plan-authored-tests-clean.md" \
    "L2(j) Authored-tests clean scenario fixture present"
  assert_file "${fix_dir}/plan-no-authored-tests.md" \
    "L2(j) Authored-tests no-field scenario fixture present"
}

# ---------------------------------------------------------------------------
# (k) check_bugfix_redfirst_criterion
#   gate-evals: qa-plan #34 / qa-spec #18 — 2 defective + 2 clean controls; catch-rate slot.
#   Fixtures must exist and carry the structural markers their expected outcomes key on.
# ---------------------------------------------------------------------------
check_bugfix_redfirst_criterion() {
  local fix_dir="${PLUGIN_ROOT}/tests/e2e/fixtures/replay"

  # Plan defective fixture: regression phase with tdd:false + tests-after → must-fix
  local fp_def="${fix_dir}/plan-bugfix-tests-after.md"
  assert_file "$fp_def" "L2(k) qa-plan #34 defective fixture present"
  if grep -qF "Phase type:" "$fp_def" 2>/dev/null && grep -qF "regression" "$fp_def" 2>/dev/null; then
    pass "L2(k) defective fixture carries Phase type: regression"
  else
    fail "L2(k) defective fixture missing Phase type: regression"
  fi
  if grep -qF "tdd: false" "$fp_def" 2>/dev/null; then
    pass "L2(k) defective fixture carries tdd: false"
  else
    fail "L2(k) defective fixture missing tdd: false"
  fi
  if grep -qF "[Write-Tests]" "$fp_def" 2>/dev/null; then
    pass "L2(k) defective fixture carries tests-after [Write-Tests] step"
  else
    fail "L2(k) defective fixture missing [Write-Tests] step"
  fi

  # Plan clean control: regression phase with tdd:true + [TDD-Red] → clean
  local fp_cln="${fix_dir}/plan-bugfix-redfirst-clean.md"
  assert_file "$fp_cln" "L2(k) qa-plan #34 clean control fixture present"
  if grep -qF "[TDD-Red]" "$fp_cln" 2>/dev/null; then
    pass "L2(k) clean control carries [TDD-Red] step"
  else
    fail "L2(k) clean control missing [TDD-Red] step"
  fi
  if grep -qF "tdd: true" "$fp_cln" 2>/dev/null; then
    pass "L2(k) clean control carries tdd: true"
  else
    fail "L2(k) clean control missing tdd: true"
  fi

  # Spec defective fixture: regression spec with tdd:false → must-fix
  local fs_def="${fix_dir}/spec-bugfix-tests-after.md"
  assert_file "$fs_def" "L2(k) qa-spec #18 defective spec fixture present"
  if grep -qF "regression" "$fs_def" 2>/dev/null; then
    pass "L2(k) defective spec fixture carries regression signal"
  else
    fail "L2(k) defective spec fixture missing regression signal"
  fi
  if grep -qF "tdd: false" "$fs_def" 2>/dev/null; then
    pass "L2(k) defective spec fixture carries tdd: false"
  else
    fail "L2(k) defective spec fixture missing tdd: false"
  fi

  # Spec clean control: regression spec with tdd:true → clean
  local fs_cln="${fix_dir}/spec-bugfix-redfirst-clean.md"
  assert_file "$fs_cln" "L2(k) qa-spec #18 clean spec fixture present"
  if grep -qF "regression" "$fs_cln" 2>/dev/null; then
    pass "L2(k) clean spec fixture carries regression signal"
  else
    fail "L2(k) clean spec fixture missing regression signal"
  fi
  if grep -qF "tdd: true" "$fs_cln" 2>/dev/null; then
    pass "L2(k) clean spec fixture carries tdd: true"
  else
    fail "L2(k) clean spec fixture missing tdd: true"
  fi
}

# ---------------------------------------------------------------------------
# l2_replay_checks()
#   ① Build clean fixture, run all checks (a)–(j), clean up.
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
  check_red_manifest_conftest
  check_gate_fixtures
  check_authored_tests_criterion
  check_bugfix_redfirst_criterion
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
#   Run all checks OTHER than check_no_journal on the journal-survives fixture.
#   (h) and (i) are static PLUGIN_ROOT checks — always pass on any fixture variant.
#   All should pass (single-defect isolation).
_run_isolation_checks() {
  local repo="$1" piece="$2"
  check_commit_order "$repo"
  check_transitions "$repo"
  check_test_data "$piece/plan.md"
  check_spike "$piece"
  check_discovery_log "$piece"
  check_learnings "$piece"
  check_red_manifest_conftest
  check_gate_fixtures
  check_authored_tests_criterion
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
