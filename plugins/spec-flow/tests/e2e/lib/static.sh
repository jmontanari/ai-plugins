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
}
