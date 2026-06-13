# Learnings: outcome-campaign (spec-flow v5.21.0)

**Piece:** outcome-campaign — `spec-flow:campaign` results-campaign gate (FR-020)
**Track:** Implement (tdd: false), 6 flat sequential phases
**Shipped:** 2026-06-13

---

## What worked

**Inside-out phase ordering (contracts → agents → skill → config → packaging → fixtures)** eliminated every inter-phase dependency risk. Each phase had exactly one deliverable and a testable checkpoint. 18 commits across 6 phases with no mid-phase fix escalations or QA iterations. The `Why serial:` note in Phase 2 preventing static.sh write races was correct.

**4-agent design (ADR-2)** — splitting the theater-guard into a dedicated `campaign-verify` agent rather than inlining the loop in the skill — paid off at review time: the architecture reviewer found zero must-fix items. The verify-in-skill / execute-in-agent boundary (CR-008) held cleanly.

**Form C batch pattern (AC-8)** — single aggregated triage invocation rather than N per-finding calls — correctly preserves NN-P-004. The campaign-triage-seam fixture made this contract explicit and the static.sh guards caught it in both directions.

---

## Must-fix patterns the phase QA cycle missed (all 4 caught only at Final Review)

### 1. Orchestration failure branches need negative-path Write-Tests

**Finding:** the all-lenses-error CAMPAIGN-ABORTED halt was uncaught through 6 phases because no assertion checked the total-failure branch — only the nominal routing path. The Write-Tests pattern was "assert nominal token presence"; no assertion covered the "what if everything errors" path.

**Rule:** When a skill orchestrates a parallel multi-agent dispatch, the `[Write-Tests]` block must include at least one negative-path assertion for the total-failure halt (e.g., `assert_grep "CAMPAIGN-ABORTED\|all.*error"` in the skill).

### 2. Empty-collection guards need explicit Write-Tests coverage

**Finding:** Step 6a's skip guard ("if zero findings survive VERIFY, skip to 6b") was missing from the implementation until the board found it. The plan T-block said "for each CONFIRMED finding" but the companion Write-Tests had no assertion for the zero-case guard.

**Rule:** Whenever a plan T-block contains a "for each item in collection" construct, the Write-Tests block must add an assertion that checks the empty-collection guard path in the produced file.

### 3. Capture → redact → forward security pattern belongs in the T-block

**Finding:** stdout was captured in Step 3 and forwarded verbatim to lens agents in Steps 4–5 before Step 6's "No secrets" note. The plan's T-block for Step 3 described "capture stdout into a run-output buffer" without a redaction gate; the board flagged it as a must-fix.

**Rule:** Any plan T-block that captures external system output and then forwards it to sub-agents must include an explicit "REDACT BEFORE FORWARDING" step between capture and dispatch. Write-Tests should assert a redaction marker (`[REDACTED]`) or guard phrase in the produced skill.

### 4. Numeric semantic claims in example YAML need inline invariants

**Finding:** `metrics-artifact.md`'s `dispatches.verify: 2` comment said "1 per surviving finding" — wrong; it should be "1 per pre-VERIFY finding." The error was authored verbatim from the plan and never caught because the static assertion checked only `findings_by_source` presence, not the comment's semantic correctness.

**Rule:** Example YAML blocks with non-obvious count semantics should annotate the invariant inline in the plan T-block (e.g., "verify = pre-VERIFY dispatch count, not confirmed count; verify ≥ verified always"). This gives phase QA a falsifiable claim to check.

---

## Phase QA gap for Implement-track orchestration files

Six Opus QA invocations fired (one per phase); all 4 must-fix board findings escaped phase QA. The static.sh assertions gave a false confidence signal — all passed — while the prose-level behavioral correctness was not mechanically checked.

For Implement-track phases producing orchestration SKILL.md files, phase QA should explicitly check "failure / empty / error" branches of each Step, not just that named tokens are present. This is a QA instruction gap, not only a test gap.

---

## Follow-on items routed to backlog

### triage/SKILL.md Step 2 ignores pre-seeded `bug_classified` (→ exec-ready backlog)

`triage-contract.md` says the field "pre-seeds the Step-2 bug-signal result so triage applies the NN-P-006 stamp without re-deriving it from keywords." `triage/SKILL.md` Step 2 runs the keyword scan unconditionally — no branch for a pre-seeded value. A campaign finding with `bug_classified: false` whose text contains "fix" or "bug" would be incorrectly stamped red-first. Small-change candidate targeting `triage/SKILL.md` Step 2 + a clean-control fixture.

### triage internal schema missing `source_agent` propagation (→ exec-ready backlog)

Campaign Form B carries `source_agent: <lens>` identifying which campaign lens raised the finding. Triage Step 1 normalizes to `{finding_text, source, ...}` with no `source_agent` slot — silently dropped. The lens identity is lost in `.discovery-log.md` entries and flywheel occurrences. Additive amendment to triage Step 1 + Step 7 schema. Small-change candidate.

### pipeline-economics is now fully unblocked (all 5 gate deps merged)

All five dependency gate pieces (outcome-acs, discovery-triage, metrics, exec-guardrails, gate-evals) are now merged. `pipeline-economics` (FR-016) is the next exec-ready piece to spec.
