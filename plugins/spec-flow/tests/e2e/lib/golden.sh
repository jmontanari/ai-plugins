# spec-flow e2e — golden snapshot + integrity validation
# Sourced by run-e2e.sh after assert.sh, contract.sh, live.sh.
# Functions defined: record_golden, golden_validate

# ---------------------------------------------------------------------------
# _golden_footprint_path
#   Returns the canonical path to the golden footprint file.
# ---------------------------------------------------------------------------
_golden_footprint_path() {
  printf '%s/golden/footprint.txt' "${E2E_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
}

# ---------------------------------------------------------------------------
# _golden_body_lines <footprint>
#   Print lines of the footprint that belong to the body
#   (everything BEFORE the "## cksum" heading line, inclusive of it... actually
#   the body is everything before the ## cksum line — cksum covers those lines).
# ---------------------------------------------------------------------------
_golden_body_lines() {
  local fp="$1"
  # Body = all lines strictly before "## cksum"
  awk '/^## cksum/ { exit } { print }' "$fp"
}

# ---------------------------------------------------------------------------
# record_golden <target> <transcript>
#   Refuses unless verify_live "$target" "$transcript" reports 0 FAIL.
#   Writes golden/footprint.txt per the C-3 schema.
# ---------------------------------------------------------------------------
record_golden() {
  local target="${1:-}"
  local transcript="${2:-}"

  if [ -z "$target" ] || [ -z "$transcript" ]; then
    err "record_golden: <target> and <transcript> required"
    return 1
  fi

  local e2e="${E2E_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  local footprint="$e2e/golden/footprint.txt"

  # S1: Refuse if target has no commit history reachable via git
  local _git_log_out
  _git_log_out=$(git -C "$target" log --oneline -1 2>/dev/null || true)
  if [ -z "$_git_log_out" ]; then
    err "record_golden: target has no commit history — ordering would be unvalidated; record from a setup-live tree"
    return 1
  fi

  # S2: Refuse if target is missing any required artifact the validator demands
  local _req_art
  for _req_art in spec.md plan.md .discovery-log.md learnings.md; do
    if [ ! -f "$target/$_req_art" ]; then
      err "record_golden: target missing required artifact $_req_art; record from a complete live tree"
      return 1
    fi
  done

  # AC-9 precondition: verify_live must report 0 FAIL in a subshell
  local vl_out vl_fails
  vl_out=$(
    PASSES=0; FAILS=0; SKIPS=0; ERRORS=0
    # shellcheck source=lib/assert.sh
    . "$e2e/lib/assert.sh"
    # shellcheck source=lib/contract.sh
    . "$e2e/lib/contract.sh"
    # shellcheck source=lib/live.sh
    . "$e2e/lib/live.sh"
    verify_live "$target" "$transcript"
  )
  vl_fails=$(printf '%s\n' "$vl_out" | grep -c '^FAIL' || true)
  if [ "$vl_fails" -ne 0 ]; then
    err "record_golden: verify_live reported $vl_fails FAIL(s) — refusing to record golden"
    printf '%s\n' "$vl_out" | grep '^FAIL' | sed 's/^/  /' >&2
    return 1
  fi

  # ---------------------------------------------------------------------------
  # Build the footprint body (sections 1–3 of schema)
  # ---------------------------------------------------------------------------

  # ## commit-subjects — ordered git log (oldest-first), empty if no .git
  local commit_subjects=""
  if [ -d "$target/.git" ]; then
    commit_subjects=$(git -C "$target" log --reverse --format="%s" 2>/dev/null || true)
  fi

  # ## dispatch-sequence — ordered subagent_type extracts from transcript (ADR-5)
  local dispatch_sequence=""
  if [ -s "$transcript" ]; then
    dispatch_sequence=$(sed -nE 's/.*"subagent_type"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$transcript" 2>/dev/null || true)
  fi

  # ## files — sorted piece-relative paths of contract artifacts present
  # Artifacts: spec.md, plan.md, spikes/*.md, .discovery-log.md, learnings.md
  local files_list=""
  local piece="$target"
  files_list=$(
    {
      # spec.md
      [ -f "$piece/spec.md" ]            && printf 'spec.md\n'
      # plan.md
      [ -f "$piece/plan.md" ]            && printf 'plan.md\n'
      # spikes/*.md (sorted)
      if ls "$piece/spikes/"*.md >/dev/null 2>&1; then
        for f in "$piece/spikes/"*.md; do
          printf 'spikes/%s\n' "$(basename "$f")"
        done
      fi
      # .discovery-log.md
      [ -f "$piece/.discovery-log.md" ]  && printf '.discovery-log.md\n'
      # learnings.md
      [ -f "$piece/learnings.md" ]       && printf 'learnings.md\n'
    } | sort
  )

  # ---------------------------------------------------------------------------
  # Build the body text
  # ---------------------------------------------------------------------------
  local body
  body=$(printf '%s\n' \
    "# spec-flow e2e golden footprint v1" \
    "## commit-subjects" \
  )
  if [ -n "$commit_subjects" ]; then
    body=$(printf '%s\n%s' "$body" "$commit_subjects")
  fi
  body=$(printf '%s\n%s' "$body" "## dispatch-sequence")
  if [ -n "$dispatch_sequence" ]; then
    body=$(printf '%s\n%s' "$body" "$dispatch_sequence")
  fi
  body=$(printf '%s\n%s' "$body" "## files")
  if [ -n "$files_list" ]; then
    body=$(printf '%s\n%s' "$body" "$files_list")
  fi

  # ---------------------------------------------------------------------------
  # Compute cksum over body lines
  # ---------------------------------------------------------------------------
  local cksum_val
  cksum_val=$(printf '%s\n' "$body" | cksum)

  # ---------------------------------------------------------------------------
  # Write footprint
  # ---------------------------------------------------------------------------
  mkdir -p "$(dirname "$footprint")"
  printf '%s\n## cksum\n%s\n' "$body" "$cksum_val" > "$footprint"

  printf 'RECORDED: golden/footprint.txt — commit it (see README re-record policy)\n'
}

# ---------------------------------------------------------------------------
# golden_validate()
#   Validates the recorded golden footprint.
#   Gated by have_golden — run-e2e.sh calls this only when have_golden is true.
#
#   ① Recompute cksum over body; mismatch → fail
#   ② SF-3 relative-order rules on ## commit-subjects lines
#   ③ Dispatch-sequence order: tdd-red < qa-tdd-red < implementer < verify
#      AND contains a review-board- entry
#   ④ ## files contains each required artifact name
# ---------------------------------------------------------------------------
golden_validate() {
  local e2e="${E2E_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  local footprint="$e2e/golden/footprint.txt"

  if [ ! -s "$footprint" ]; then
    fail "golden_validate: footprint.txt missing or empty"
    return
  fi

  # ---------------------------------------------------------------------------
  # ① Integrity: recompute cksum over body
  # ---------------------------------------------------------------------------
  local body_lines recorded_cksum recomputed_cksum
  body_lines=$(awk '/^## cksum/ { exit } { print }' "$footprint")
  recorded_cksum=$(awk '/^## cksum/ { found=1; next } found { print; exit }' "$footprint")
  recomputed_cksum=$(printf '%s\n' "$body_lines" | cksum)

  if [ "$recomputed_cksum" != "$recorded_cksum" ]; then
    fail "golden integrity: cksum mismatch (footprint edited or corrupted)"
    return
  fi
  pass "golden integrity: cksum matches"

  # ---------------------------------------------------------------------------
  # Extract section contents from footprint
  # ---------------------------------------------------------------------------
  # ## commit-subjects section
  local commit_subjects
  commit_subjects=$(awk '
    /^## commit-subjects/ { in_sec=1; next }
    in_sec && /^## /     { in_sec=0 }
    in_sec               { print }
  ' "$footprint")

  # ## dispatch-sequence section
  local dispatch_sequence
  dispatch_sequence=$(awk '
    /^## dispatch-sequence/ { in_sec=1; next }
    in_sec && /^## /        { in_sec=0 }
    in_sec                  { print }
  ' "$footprint")

  # ## files section
  local files_section
  files_section=$(awk '
    /^## files/ { in_sec=1; next }
    in_sec && /^## / { in_sec=0 }
    in_sec           { print }
  ' "$footprint")

  # ---------------------------------------------------------------------------
  # ② SF-3 relative-order rules on ## commit-subjects
  #   Same prefix pairs as check_commit_order / check_transitions
  # ---------------------------------------------------------------------------
  # Helper: find first line number of prefix in commit_subjects text
  _cs_line() {
    printf '%s\n' "$commit_subjects" | awk -v t="$1" 'index($0, t) == 1 { print NR; exit }'
  }

  # Only run ordering checks when commit-subjects is non-empty
  if [ -n "$commit_subjects" ]; then
    local pairs_ok=1

    _check_cs_order() {
      local prefA="$1" prefB="$2" label="$3"
      local la lb
      la=$(_cs_line "$prefA")
      lb=$(_cs_line "$prefB")
      if [ -z "$la" ]; then
        fail "golden order: prefix not found in commit-subjects: $prefA ($label)"
        pairs_ok=0
      elif [ -z "$lb" ]; then
        fail "golden order: prefix not found in commit-subjects: $prefB ($label)"
        pairs_ok=0
      elif [ "$la" -lt "$lb" ]; then
        pass "golden order: $label"
      else
        fail "golden order: misordered — '$prefA'(line $la) not before '$prefB'(line $lb) ($label)"
        pairs_ok=0
      fi
    }

    _check_cs_order "research: "   "spec: add"                                   "research before spec"
    _check_cs_order "spec: add"    "plan: add"                                   "spec before plan"
    _check_cs_order "plan: add"    "manifest: mark demo/hello as in-progress"    "plan before in-progress"
    _check_cs_order "manifest: mark demo/hello as in-progress" "feat(demo): phase 1" "in-progress before phase-1"
    _check_cs_order "learnings: "  "manifest: mark demo/hello as merged"         "learnings before merged"
  else
    pass "golden order: commit-subjects empty (no git history — ordering skipped)"
  fi

  # ---------------------------------------------------------------------------
  # ③ Dispatch-sequence order + review-board
  # ---------------------------------------------------------------------------
  # Find first-occurrence line numbers for each dispatch type
  _ds_line() {
    printf '%s\n' "$dispatch_sequence" | awk -v t="$1" 'index($0, t) > 0 { print NR; exit }'
  }

  local ln_tdd ln_qa ln_impl ln_verify
  ln_tdd=$(_ds_line "spec-flow:tdd-red")
  ln_qa=$(_ds_line "spec-flow:qa-tdd-red")
  ln_impl=$(_ds_line "spec-flow:implementer")
  ln_verify=$(_ds_line "spec-flow:verify")

  if [ -z "$ln_tdd" ] || [ -z "$ln_qa" ] || [ -z "$ln_impl" ] || [ -z "$ln_verify" ]; then
    fail "golden dispatch-sequence: one or more required tokens missing (tdd-red=$ln_tdd qa-tdd-red=$ln_qa implementer=$ln_impl verify=$ln_verify)"
  elif [ "$ln_tdd" -lt "$ln_qa" ] && [ "$ln_qa" -lt "$ln_impl" ] && [ "$ln_impl" -lt "$ln_verify" ]; then
    pass "golden dispatch-sequence: order tdd-red < qa-tdd-red < implementer < verify"
  else
    fail "golden dispatch-sequence: order misordered (tdd-red=$ln_tdd qa-tdd-red=$ln_qa implementer=$ln_impl verify=$ln_verify)"
  fi

  # review-board entry must be present
  if printf '%s\n' "$dispatch_sequence" | grep -q 'review-board-'; then
    pass "golden dispatch-sequence: review-board entry present"
  else
    fail "golden dispatch-sequence: no review-board- entry found"
  fi

  # ---------------------------------------------------------------------------
  # ④ Required artifact names in ## files
  # ---------------------------------------------------------------------------
  local required_artifacts="spec.md plan.md .discovery-log.md learnings.md"
  local art
  for art in $required_artifacts; do
    if printf '%s\n' "$files_section" | grep -qF "$art"; then
      pass "golden files: required artifact present — $art"
    else
      fail "golden files: required artifact missing — $art"
    fi
  done
}
