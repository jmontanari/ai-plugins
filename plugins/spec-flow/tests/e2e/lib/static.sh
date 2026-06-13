# spec-flow e2e — L1 static contract checks
# Sourced by run-e2e.sh after assert.sh.
# l1_static_checks [skill-file]
#   $1 = path to SKILL.md (default: $PLUGIN_ROOT/skills/execute/SKILL.md)

assert_file_exists() { [ -f "$1" ] && pass "$2" || fail "$2 (file not found: $1)"; }

l1_static_checks() {
  local skill="${1:-${PLUGIN_ROOT}/skills/execute/SKILL.md}"

  # --- ordered dispatch-sequence tokens (must appear at LINE START, strictly increasing) ---
  local -a L1_SEQUENCE
  L1_SEQUENCE=(
    '### Step 2: TDD-Red'
    '### Step 2.5: QA-TDD-Red'
    '### Step 3: Implement'
    '### Step 4: Verify'
    '### Step 6: Phase QA'
    '## Final Review'
  )

  local prev_line=0 prev_tok="" all_present=1
  local -a linenos
  linenos=()

  local tok line_no
  for tok in "${L1_SEQUENCE[@]}"; do
    line_no=$(awk -v t="$tok" 'index($0, t) == 1 { print NR; exit }' "$skill")
    if [ -z "$line_no" ]; then
      fail "L1 sequence token missing: $tok"
      all_present=0
      linenos+=("0")
    else
      linenos+=("$line_no")
    fi
  done

  # Check ordering for tokens that were found
  local i
  for i in $(seq 0 $((${#L1_SEQUENCE[@]} - 1))); do
    tok="${L1_SEQUENCE[$i]}"
    line_no="${linenos[$i]}"

    if [ "$line_no" = "0" ]; then
      # already failed above for missing token — skip ordering pass/fail
      continue
    fi

    if [ "$i" -eq 0 ]; then
      # first token — just record
      prev_line="$line_no"
      prev_tok="$tok"
      pass "L1 sequence token present+ordered: $tok"
    else
      if [ "$line_no" -gt "$prev_line" ]; then
        pass "L1 sequence token present+ordered: $tok"
      else
        fail "L1 sequence misordered: $tok(>$prev_tok)"
      fi
      prev_line="$line_no"
      prev_tok="$tok"
    fi
  done

  # --- artifact-contract anchors (7 checks) ---

  # Heading anchors — must match at line start (same awk idiom)
  local -a HEADING_ANCHORS
  HEADING_ANCHORS=(
    '### Step 1c: [SPIKE]-phase resolution'
    '### Step 6c: Discovery Triage'
    '### Step G9b: Barrier work-commit'
  )
  local ha
  for ha in "${HEADING_ANCHORS[@]}"; do
    if awk -v t="$ha" 'index($0, t) == 1 { found=1; exit } END { exit !found }' "$skill"; then
      pass "L1 anchor present: $ha"
    else
      fail "L1 anchor missing: $ha"
    fi
  done

  # Prose anchors — presence anywhere in file (grep -F -q)
  local -a PROSE_ANCHORS
  PROSE_ANCHORS=(
    'manifest: mark <prd-slug>/<piece-slug> as in-progress'
    'learnings.md'
    '.discovery-log.md'
    'unified commit'
  )
  local pa
  for pa in "${PROSE_ANCHORS[@]}"; do
    if grep -F -q "$pa" "$skill" 2>/dev/null; then
      pass "L1 anchor present: $pa"
    else
      fail "L1 anchor missing: $pa"
    fi
  done

  # --- template contract checks (AC-5: Authored-tests declaration surface) ---
  local tmpl="${PLUGIN_ROOT}/templates/plan.md"
  assert_count "\*\*Authored-tests:\*\*" "$tmpl" 3 \
    "AC-5: **Authored-tests:** appears at all 3 header sites in plan.md template"
  assert_grep "hard reject" "$tmpl" \
    "AC-5: plan.md template smuggling note ('hard reject') present"
  assert_grep "Omit if none" "$tmpl" \
    "AC-5: plan.md template conditional-absence note ('Omit if none') present"

  # --- tdd-red enrichment checks (AC-4 manifest half) ---
  local tdd_red="${PLUGIN_ROOT}/agents/tdd-red.md"
  local tdd_red_agent="${PLUGIN_ROOT}/agents/tdd-red.agent.md"
  assert_grep "conftest" "$tdd_red" \
    "AC-4: tdd-red.md contains conftest enrichment rule"
  assert_grep "directly import" "$tdd_red" \
    "AC-4: tdd-red.md contains direct-import resolution rule"
  assert_grep "transitive" "$tdd_red" \
    "AC-4: tdd-red.md states transitive-closure bound (NOT a transitive closure)"
  assert_grep "skip.*non-resolving|non-resolving.*skip" "$tdd_red" \
    "AC-4: tdd-red.md states skip-non-resolving-imports rule"
  assert_grep "conftest" "$tdd_red_agent" \
    "AC-4: tdd-red.agent.md mirrors conftest enrichment rule"
  assert_grep "directly import" "$tdd_red_agent" \
    "AC-4: tdd-red.agent.md mirrors direct-import resolution rule"
  assert_grep "transitive" "$tdd_red_agent" \
    "AC-4: tdd-red.agent.md mirrors transitive-closure bound"
  assert_grep "skip.*non-resolving|non-resolving.*skip" "$tdd_red_agent" \
    "AC-4: tdd-red.agent.md mirrors skip-non-resolving-imports rule"

  # --- immutability gate checks (AC-1, AC-2, AC-4 trip, AC-5, AC-6) ---
  # $skill is already bound to the execute/SKILL.md path via the function parameter (line 7).

  # AC-1: gate (a) — hard-stop (no warn branch), names violating paths, references exempt_authored
  assert_grep "Do NOT add any warn-and-proceed" "$skill" \
    "AC-1: gate (a) explicitly prohibits warn-and-proceed branch"
  assert_grep "integrity failures are hard stops" "$skill" \
    "AC-1: gate (a) confirms integrity failures are hard stops"
  assert_no_grep "integrity.*proceed anyway|proceed anyway.*integrity" "$skill" \
    "AC-1: no 'proceed anyway' instruction in integrity gate context"
  assert_grep "name each violating path explicitly|Collect all violating paths" "$skill" \
    "AC-1: gate (a) names violating paths on reject"
  assert_grep "exempt_authored" "$skill" \
    "AC-1/AC-5/AC-6: execute/SKILL.md references exempt_authored set"

  # AC-1: gate (a) smuggling guard
  assert_grep "HARD REJECT.*smuggling|smuggling.*HARD REJECT" "$skill" \
    "AC-6: gate (a) defines HARD REJECT for smuggling (path in both manifest and exempt_authored)"

  # AC-2: G9b — barrier reject names violating paths + preserves ≤5.1.0 fallback
  assert_grep "name each.*violating|violating.*re-dispatch|Collect all violating" "$skill" \
    "AC-2: G9b barrier names violating paths in re-dispatch"
  assert_grep "anchor.*blob.*5\.1|5\.1.*sha256sum|sha256sum.*fallback" "$skill" \
    "AC-2: G9b preserves ≤5.1.0 sha256sum fallback"

  # AC-4 (trip half): fixture/conftest rejection noted in implementer contract
  local impl="${PLUGIN_ROOT}/agents/implementer.md"
  local impl_agent="${PLUGIN_ROOT}/agents/implementer.agent.md"
  assert_grep "conftest|fixture.*rejected|rejected.*fixture" "$impl" \
    "AC-4: implementer.md notes fixture/conftest equally rejected"
  assert_grep "conftest|fixture" "$impl_agent" \
    "AC-4: implementer.agent.md mirrors fixture/conftest rejection"
  assert_grep "violating" "$impl" \
    "AC-1: implementer.md mentions named violating paths in re-dispatch"

  # --- phase-exit re-verification check (AC-3) ---
  assert_grep "blocking finding attributed to the phase" "$skill" \
    "AC-3: Step 4 item 5 describes mismatch as a blocking finding attributed to the phase"
  assert_grep "unconditional phase-exit check" "$skill" \
    "AC-3: Step 4 item 5 describes the re-hash as unconditional"
  assert_no_grep "already passed — so no additional diff is needed here" "$skill" \
    "AC-3: Step 4 item 5 no longer leads with the old no-op framing"

  # --- repeated-rejection → Step 6c routing check (AC-9) ---
  assert_grep "Repeated immutability rejection" "$skill" \
    "AC-9: Step 6c has Repeated immutability rejection source"
  assert_grep "source_agent.*orchestrator|orchestrator.*source_agent" "$skill" \
    "AC-9: source 4 uses source_agent: orchestrator"
  assert_grep "default_triage.*amend.*source 4|source 4.*default_triage.*amend|default_triage.*amend.*repeated|repeated.*default_triage.*amend" "$skill" \
    "AC-9: source 4 uses default_triage: amend"
  assert_grep "NEVER auto-exempt|never.*auto-exempt|never via a silent auto-exemption" "$skill" \
    "AC-9: source 4 states repeated rejection never auto-exempts the touched test"

  # --- amendment hard-cap checks (AC-7, AC-8, AC-10) ---

  # AC-7: no (c) continue affordance; hard-cap escalation present; amendment_budget read
  assert_no_grep "\(c\) continue|continue amending" "$skill" \
    "AC-7: no (c) continue affordance in execute/SKILL.md amendment section"
  assert_grep "Amendment hard-cap escalation" "$skill" \
    "AC-7: execute/SKILL.md has Amendment hard-cap escalation block"
  assert_grep "amendment_budget" "$skill" \
    "AC-7/AC-8: execute/SKILL.md reads amendment_budget config key"

  # AC-8: no off/unlimited sentinel documented; raise-and-resume option present
  local cfg="${PLUGIN_ROOT}/templates/pipeline-config.yaml"
  assert_grep "NO off/unlimited" "$cfg" \
    "AC-8: pipeline-config.yaml documents NO off/unlimited sentinel"
  assert_grep "raise.*amendment_budget.*resume|raise.*and resume" "$skill" \
    "AC-8: execute/SKILL.md offers raise-and-resume option (not per-event continue)"

  # AC-10: single piece_amendment_count recovery definition; qualified never-hard-blocks
  local spike_ref="${PLUGIN_ROOT}/reference/spike-agent.md"
  assert_count "^- .*piece_amendment_count.* = .*git log" "$skill" 1 \
    "AC-10: exactly one piece_amendment_count recovery definition in execute/SKILL.md"
  assert_no_grep "never resets within a piece; never hard-blocks" "$spike_ref" \
    "AC-10: spike-agent.md old unqualified amendment never-hard-blocks sentence removed"

  # --- version sync + CHANGELOG + cross-file mirror sweep (AC-11) ---

  # AC-11: version sync
  local pluginjson="${PLUGIN_ROOT}/plugin.json"
  local marketplace="${REPO_ROOT}/.claude-plugin/marketplace.json"
  assert_grep '"version": "5\.21\.0"' "$pluginjson" \
    "AC-11: plugin.json version is 5.21.0"
  assert_grep '"version": "5\.21\.0"' "$marketplace" \
    "AC-11: marketplace.json spec-flow entry is 5.21.0"
  assert_grep '"version": "5\.21\.0"' "${PLUGIN_ROOT}/.claude-plugin/plugin.json" \
    "AC-11: .claude-plugin/plugin.json version is 5.21.0"

  # AC-11: CHANGELOG has 5.16.1 and (c) continue removal under ### Changed
  local changelog="${PLUGIN_ROOT}/CHANGELOG.md"
  assert_grep "\[5\.16\.1\]" "$changelog" \
    "AC-11: CHANGELOG.md has 5.16.1 section"
  assert_grep "\[5\.21\.0\]" "$changelog" \
    "AC-8: CHANGELOG carries the 5.21.0 section"
  assert_grep "\(c\) continue" "$changelog" \
    "AC-11: CHANGELOG.md documents (c) continue removal"

  # AC-11: cross-file mirror sweep (dual-mirror parity)
  local tdd_red="${PLUGIN_ROOT}/agents/tdd-red.md"
  local tdd_red_agent="${PLUGIN_ROOT}/agents/tdd-red.agent.md"
  assert_grep "conftest" "$tdd_red" \
    "AC-11: tdd-red.md carries conftest enrichment"
  assert_grep "conftest" "$tdd_red_agent" \
    "AC-11: tdd-red.agent.md mirrors conftest enrichment"
  local impl_agent="${PLUGIN_ROOT}/agents/implementer.agent.md"
  assert_grep "equally rejected" "${PLUGIN_ROOT}/agents/implementer.md" \
    "AC-11: implementer.md carries new guardrail 'equally rejected' token"
  assert_grep "equally rejected" "$impl_agent" \
    "AC-11: implementer.agent.md mirrors 'equally rejected' guardrail token"
  assert_grep "Authored-tests declaration" "${PLUGIN_ROOT}/agents/qa-plan.md" \
    "AC-11: qa-plan.md has Authored-tests declaration criterion"
  assert_grep "Authored-tests declaration" "${PLUGIN_ROOT}/agents/qa-plan.agent.md" \
    "AC-11: qa-plan.agent.md mirrors Authored-tests declaration criterion"

  # --- AC-10 (gate-evals): rubric_version on all 13 measured pairs + byte-identity ---
  local _agents_dir="${PLUGIN_ROOT}/agents"
  local -a _measured_pairs
  _measured_pairs=(
    "qa-phase-lite" "qa-phase" "qa-plan" "qa-spec" "qa-tdd-red"
    "review-board-architecture" "review-board-blind" "review-board-edge-case"
    "review-board-ground-truth" "review-board-integration" "review-board-prd-alignment"
    "review-board-security" "review-board-spec-compliance"
  )
  local _pair _diff_out
  for _pair in "${_measured_pairs[@]}"; do
    assert_grep "rubric_version:" "${_agents_dir}/${_pair}.md" \
      "AC-10 (gate-evals): ${_pair}.md has rubric_version"
    assert_grep "rubric_version:" "${_agents_dir}/${_pair}.agent.md" \
      "AC-10 (gate-evals): ${_pair}.agent.md has rubric_version"
    if [ -L "${_agents_dir}/${_pair}.agent.md" ]; then
      pass "AC-10 (gate-evals): ${_pair}.agent.md is a symlink to its .md source"
    else
      fail "AC-10 (gate-evals): ${_pair}.agent.md is a regular file — co-ship twin must be a symlink to ${_pair}.md (drift risk)"
    fi
    _diff_out=$(diff "${_agents_dir}/${_pair}.md" "${_agents_dir}/${_pair}.agent.md" 2>&1)
    if [ -z "$_diff_out" ]; then
      pass "AC-10 (gate-evals): ${_pair} .md/.agent.md are byte-identical"
    else
      fail "AC-10 (gate-evals): ${_pair} .md/.agent.md differ (unexpected non-rubric_version change)"
    fi
  done

  # --- All-31 co-ship twin symlink guard (drift structurally impossible) ---
  local _agent_md _twin _nonlink=0 _mismatch=0
  for _agent_md in "${_agents_dir}"/*.agent.md; do
    _twin="${_agent_md%.agent.md}.md"
    if [ ! -L "$_agent_md" ]; then _nonlink=$((_nonlink+1)); fi
    if ! cmp -s "$_agent_md" "$_twin"; then _mismatch=$((_mismatch+1)); fi
  done
  if [ "$_nonlink" -eq 0 ] && [ "$_mismatch" -eq 0 ]; then
    pass "all agents/*.agent.md are symlinks byte-identical to their .md source (31-pair drift guard)"
  else
    fail "agent co-ship twin drift: $_nonlink non-symlink, $_mismatch content-mismatch .agent.md files"
  fi

  # --- discovery-triage unified-path contract (FR-019/FR-023) ---

  assert_grep "Dispositions" "${PLUGIN_ROOT}/reference/triage-contract.md" \
    "FR-019: triage-contract.md has disposition map"
  assert_grep "triage-contract.md" "${PLUGIN_ROOT}/skills/triage/SKILL.md" \
    "FR-019: triage skill cites the shared contract"
  assert_grep "triage-contract.md" "${PLUGIN_ROOT}/skills/execute/SKILL.md" \
    "FR-023: execute Step 6c cites the shared contract"
  assert_grep "FR-008 mid-execution change-signal phrasing set" "${PLUGIN_ROOT}/reference/triage-contract.md" \
    "FR-023: hardened change-signal phrasing set documented in the contract"
  assert_grep "SUPPRESSED per the suppression rule" "${PLUGIN_ROOT}/skills/execute/SKILL.md" \
    "FR-023: execute cites suppression rule from contract (not restated inline)"
  assert_grep "spec-flow:triage" "${PLUGIN_ROOT}/skills/intake/SKILL.md" \
    "FR-019: intake Q4 routes to spec-flow:triage"
  assert_grep "red-first" "${PLUGIN_ROOT}/reference/triage-contract.md" \
    "FR-019: contract documents the NN-P-006 red-first forward-record"
  assert_grep "source:" "${PLUGIN_ROOT}/reference/triage-contract.md" \
    "FR-019: triage-contract.md notes: schema has source field"
  assert_grep "source:" "${PLUGIN_ROOT}/skills/triage/SKILL.md" \
    "FR-019: triage/SKILL.md notes: schema has source field"

  # --- bugfix-redfirst: phase1 ---
  assert_grep "Bug-fix and regression work is always red-first" "${PLUGIN_ROOT}/reference/spec-flow-doctrine.md" "NN-P-006: doctrine carries the bug-fix red-first governance statement"
  assert_grep "runs RED regardless of the piece" "${PLUGIN_ROOT}/reference/spec-flow-doctrine.md" "NN-P-006 RED carve-out: RED section carve-out present"
  # --- end phase1 ---

  # --- bugfix-redfirst: phase2 ---
  assert_grep "Phase type:" "${PLUGIN_ROOT}/templates/plan.md" "AC-1: plan template carries the Phase type field"
  assert_grep "### Phase 1 \(TDD track example\):" "${PLUGIN_ROOT}/templates/plan.md" "CR-009: counted phase heading unchanged"
  # --- end phase2 ---

  # --- bugfix-redfirst: phase3 ---
  assert_grep "Bug-fix/regression precedence" "${PLUGIN_ROOT}/skills/plan/SKILL.md" "AC-2: plan skill forces tdd:true for bug-fix work"
  assert_grep "does NOT apply to bug-fix" "${PLUGIN_ROOT}/skills/plan/SKILL.md" "AC-7: FR-021 carve-out documented in plan/SKILL.md"
  # --- end phase3 ---

  # --- bugfix-redfirst: phase4 ---
  assert_grep "Bug-signal red-first routing" "${PLUGIN_ROOT}/skills/small-change/SKILL.md" "AC-5: small-change routes bug-signal work to red-first"
  assert_grep "write \`tdd: true\` into the inline" "${PLUGIN_ROOT}/skills/small-change/SKILL.md" "AC-2: small-change writes tdd:true front-matter"
  assert_grep "Red-first obligation" "${PLUGIN_ROOT}/skills/small-change/SKILL.md" "NN-C-008: cites the triage-contract keyword set"
  # --- end phase4 ---

  # --- bugfix-redfirst: phase5 ---
  assert_grep "Bug-fix / regression work is \*\*red-first\*\*" "${PLUGIN_ROOT}/skills/intake/SKILL.md" "AC-5: intake hotfix path carries the red-first obligation"
  # --- end phase5 ---

  # --- bugfix-redfirst: phase6 ---
  assert_grep "34\. \*\*Bug-fix/regression red-first" "${PLUGIN_ROOT}/agents/qa-plan.md" "AC-3: qa-plan criterion 34 present"
  assert_grep "18\. \*\*Bug-fix/regression red-first" "${PLUGIN_ROOT}/agents/qa-spec.md" "AC-3: qa-spec criterion 18 present"
  assert_grep "Consumers HONOR the stamp" "${PLUGIN_ROOT}/reference/triage-contract.md" "AC-6: triage consumers honor the red-first stamp"
  assert_exit 0 "qa-plan.agent.md is symlink-identical to qa-plan.md" -- diff "${PLUGIN_ROOT}/agents/qa-plan.md" "${PLUGIN_ROOT}/agents/qa-plan.agent.md"
  # --- end phase6 ---

  # --- bugfix-redfirst: phase7 ---
  for f in plan-bugfix-tests-after plan-bugfix-redfirst-clean spec-bugfix-tests-after spec-bugfix-redfirst-clean; do
    assert_grep "Phase type:|red-first|regression" "${PLUGIN_ROOT}/tests/e2e/fixtures/replay/$f.md" "AC-9: fixture $f present"
  done
  # --- end phase7 ---

  # --- bugfix-redfirst: phase8 cross-surface sweep (AC-4) ---
  assert_grep "always red-first" "${PLUGIN_ROOT}/reference/spec-flow-doctrine.md" "AC-4: doctrine carries red-first obligation"
  assert_grep "Bug-fix/regression precedence" "${PLUGIN_ROOT}/skills/plan/SKILL.md" "AC-4: plan/SKILL.md carries red-first precedence"
  assert_grep "Bug-signal red-first routing" "${PLUGIN_ROOT}/skills/small-change/SKILL.md" "AC-4: small-change carries red-first routing"
  assert_grep "red-first" "${PLUGIN_ROOT}/skills/intake/SKILL.md" "AC-4: intake carries red-first obligation"
  assert_grep "34\. \*\*Bug-fix/regression red-first" "${PLUGIN_ROOT}/agents/qa-plan.md" "AC-4: qa-plan criterion 34 present"
  assert_grep "18\. \*\*Bug-fix/regression red-first" "${PLUGIN_ROOT}/agents/qa-spec.md" "AC-4: qa-spec criterion 18 present"
  assert_grep "Consumers HONOR the stamp" "${PLUGIN_ROOT}/reference/triage-contract.md" "AC-4: triage-contract consumers honor the stamp"
  # --- end phase8 ---

  # --- outcome-campaign: phase1 reference-doc contracts (AC-10, AC-11) ---
  assert_no_grep "does not exist" "${PLUGIN_ROOT}/reference/triage-contract.md" "AC-11: campaign placeholder removed"
  assert_grep "bug_classified" "${PLUGIN_ROOT}/reference/triage-contract.md" "AC-11: bug_classified Form B/C field"
  assert_grep "findings_by_source" "${PLUGIN_ROOT}/reference/metrics-artifact.md" "AC-10: findings_by_source block"
  assert_grep "routed_to_triage" "${PLUGIN_ROOT}/reference/metrics-artifact.md" "AC-10: campaign metrics sub-block"
  assert_grep "campaign" "${PLUGIN_ROOT}/reference/flywheel.md" "AC-10: campaign source_type"
  assert_grep "metric | campaign" "${PLUGIN_ROOT}/reference/flywheel.md" "AC-10: campaign in flywheel inline enum"
  # --- end outcome-campaign phase1 ---

  # --- outcome-campaign: phase2 campaign agents (AC-5, AC-6, AC-7, AC-12) ---
  for agent in campaign-ground-truth campaign-seam campaign-edge-case campaign-verify; do
    assert_grep "^name: ${agent}" "${PLUGIN_ROOT}/agents/${agent}.md" "AC-6/AC-7: ${agent} agent bare name"
    assert_grep "model: opus" "${PLUGIN_ROOT}/agents/${agent}.md" "AC-5: ${agent} model opus"
    assert_no_grep "^name:.*spec-flow-" "${PLUGIN_ROOT}/agents/${agent}.md" "AC-12: ${agent} no plugin prefix"
  done
  # --- end outcome-campaign phase2 ---

  # --- outcome-campaign: phase3 campaign SKILL.md (AC-1..AC-10) ---
  assert_grep "name: campaign" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-1: skill frontmatter"
  assert_grep "SKIPPED: no-oracle" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-2/AC-3: no-oracle skip"
  assert_grep "run_mode" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-4: run_mode gate"
  assert_grep "before first execution" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-4: pre-run confirm"
  assert_grep "live" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-4: live opt-in"
  assert_grep 'model: "opus"' "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-5: Opus lens dispatch"
  assert_grep "campaign-verify" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-7: theater-guard verify"
  assert_grep "CONFIRMED" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-7: confirmed-only routing"
  assert_grep "conditional-activation: not-yet-available" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-9: seat omission reported"
  assert_grep "findings_by_source" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-10: metrics recording"
  assert_grep "METRICS-DEGRADED" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-10: metrics degraded path"
  assert_grep "FLYWHEEL-DEGRADED" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-10: flywheel degraded path"
  assert_grep "spec-flow:triage" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-8: campaign->triage Form C wiring"
  assert_grep "Form C" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-8: Form C batch"
  # --- end outcome-campaign phase3 ---

  # --- outcome-campaign: phase4 campaign config template (AC-4) ---
  assert_grep "run_mode" "${PLUGIN_ROOT}/templates/pipeline-config.yaml" "AC-4: campaign config documented"
  # --- end outcome-campaign phase4 ---

  # --- outcome-campaign: phase6 judgment fixtures (AC-3, AC-8, AC-11) ---
  assert_grep "bug_classified" "${PLUGIN_ROOT}/tests/fixtures/outcome-campaign/brf3-bug-vs-nonbug.md" "AC-11: BRF-3 fixture"
  assert_file_exists "${PLUGIN_ROOT}/tests/fixtures/outcome-campaign/campaign-triage-seam.md" "AC-8: campaign-triage-seam fixture"
  assert_file_exists "${PLUGIN_ROOT}/tests/fixtures/outcome-campaign/brf3-bug-vs-nonbug.md" "AC-11: brf3-bug-vs-nonbug fixture"
  assert_file_exists "${PLUGIN_ROOT}/tests/fixtures/outcome-campaign/skipped-no-false-green.md" "AC-3: skipped-no-false-green fixture"
  # --- end outcome-campaign phase6 ---
}
