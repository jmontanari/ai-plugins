# spec-flow e2e — L1 static contract checks
# Sourced by run-e2e.sh after assert.sh.
# l1_static_checks [skill-file]
#   $1 = path to SKILL.md (default: $PLUGIN_ROOT/skills/execute/SKILL.md)

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
  assert_grep '"version": "5\.17\.0"' "$pluginjson" \
    "AC-11: plugin.json version is 5.17.0"
  assert_grep '"version": "5\.17\.0"' "$marketplace" \
    "AC-11: marketplace.json spec-flow entry is 5.17.0"

  # AC-11: CHANGELOG has 5.16.1 and (c) continue removal under ### Changed
  local changelog="${PLUGIN_ROOT}/CHANGELOG.md"
  assert_grep "\[5\.16\.1\]" "$changelog" \
    "AC-11: CHANGELOG.md has 5.16.1 section"
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

  # --- All-27 co-ship twin symlink guard (drift structurally impossible) ---
  local _agent_md _twin _nonlink=0 _mismatch=0
  for _agent_md in "${_agents_dir}"/*.agent.md; do
    _twin="${_agent_md%.agent.md}.md"
    if [ ! -L "$_agent_md" ]; then _nonlink=$((_nonlink+1)); fi
    if ! cmp -s "$_agent_md" "$_twin"; then _mismatch=$((_mismatch+1)); fi
  done
  if [ "$_nonlink" -eq 0 ] && [ "$_mismatch" -eq 0 ]; then
    pass "all agents/*.agent.md are symlinks byte-identical to their .md source (27-pair drift guard)"
  else
    fail "agent co-ship twin drift: $_nonlink non-symlink, $_mismatch content-mismatch .agent.md files"
  fi
}
