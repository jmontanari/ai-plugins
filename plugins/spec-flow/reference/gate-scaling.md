# Gate scaling

This document is the single source of truth for verifiability-scaled sign-off gates and review-board cost controls. It is cited by anchor from `plugins/spec-flow/skills/spec/SKILL.md`, `plugins/spec-flow/skills/plan/SKILL.md`, `plugins/spec-flow/skills/execute/SKILL.md`, and `plugins/spec-flow/skills/review-board/SKILL.md`. All predicate definitions, evidence rules, digest-payload contracts, and board-swap rules live here; consuming skills cite by anchor and do not restate these definitions.

## clean-gate-predicate

A gate's clean predicate is a three-input conjunction:

(i) QA returned clean — zero must-fix findings from the most recent QA pass.  
(ii) Zero surviving `[PENDING-DECISION]` or `[NEEDS CLARIFICATION]` markers in the artifact — verified by open-bracket scan, mirroring qa-spec criterion #7.  
(iii) Every machine-checkable AC in the piece has evidence assembled per the per-gate evidence rule defined in the gate's own section below.

When all three conjuncts hold, the gate may offer a summary-confirm (a condensed single-key confirmation in place of the full sign-off prompt). When any conjunct fails, the gate renders today's full sign-off prompt unchanged. A keystroke is ALWAYS required on both branches — nothing auto-advances (NN-P-001).

## spec-gate

Predicate = (i) ∧ (ii) ONLY.

Tags are recorded for metrics at spec time and are NOT a gate input; a machine-checkable tag does not unlock summary-confirm at the spec gate (ADR-2). Conjunct (iii) does not apply at the spec gate — no check has run.

When the spec-gate predicate holds (QA-clean and zero surviving markers), the gate renders the evidence digest (`reference/gate-scaling.md#evidence-digest-payload`) and offers a single-key summary-confirm. Otherwise the full sign-off prompt is rendered. A keystroke is always required on both branches.

**Digest at spec time:** the evidence digest carries zero AC rows by design — the per-machine-checkable-AC four-field contract (`#evidence-digest-payload`) applies only to ACs whose checks have been executed, and no checks run at spec time. The spec-gate digest surfaces the two conjunct outcomes directly: the QA iteration count (conjunct i) and the zero-marker scan result (conjunct ii). In addition, if `spec.ac_verifiability` metrics are available (the spec skill computes them at Phase 5 step 3a, which runs after this gate — the value may not exist when the gate renders), the digest MAY include the `machine_checkable_ratio` as a third advisory field — it informs the operator how machine-verifiable the spec is before approving it. This third field is advisory only and does not affect the predicate or whether summary-confirm is offered.

## plan-gate

Predicate = (i) ∧ (ii) ∧ (iii).

For the plan gate, conjunct (iii) evidence for each machine-checkable AC is: an AC-Coverage-Matrix row marked `covered` with a concrete `file:line` pointer. A vague pointer (e.g., a file name without a line number, or a phase reference without a file path) fails the evidence requirement per `reference/ac-matrix-contract.md`. When all covered rows carry concrete `file:line` entries, the gate may offer summary-confirm. When any machine-checkable AC lacks a valid covered row, conjunct (iii) fails and the gate renders the full prompt.

**Digest at plan time:** the evidence digest for the plan gate interprets the four `#evidence-digest-payload` fields for coverage evidence (not executed-check output): (a) check name — the AC ID and its AC-Coverage-Matrix location; (b) run status — `covered` (the matrix row is marked covered) or `not-covered`; (c) pass/fail count — `n/N ACs covered with concrete file:line pointers`; (d) artifact pointer — the path to the plan's AC-Coverage-Matrix table (e.g., `plan.md:line`). No check has run at plan time; the four fields map to static coverage claims. Fields (a) and (b) are enumerated per machine-checkable AC; fields (c) and (d) are stated once as aggregate summary entries for the full AC set. This interpretation applies only to the plan-gate evidence digest; the final-review-gate uses executed-check output as defined above.

## final-review-gate

Predicate = (i) ∧ (ii) ∧ (iii).

For the final-review gate, conjunct (iii) evidence for each machine-checkable AC is: executed `[Verify]` command output or oracle output validated by the verify agent, AND the evidence digest explicitly asserts that this evidence was produced against current HEAD — either the evidence was run against the current HEAD commit, or it has been re-run on the final commit before summary-confirm is offered. Evidence produced against a prior commit and not re-run is stale and fails conjunct (iii). When all machine-checkable ACs carry fresh, HEAD-validated evidence, the gate may offer summary-confirm.

## evidence-digest-payload

When a gate offers summary-confirm, it renders an evidence digest. Per machine-checkable AC, the digest MUST enumerate all four of the following fields:

(a) **check name** — the specific grep, script, test suite, or oracle that was run.  
(b) **run status** — whether the check completed successfully (passed, failed, error).  
(c) **pass/fail count** — the numeric result (e.g., `3/3 passed`, `0 failures`, `grep returned 2 matches`).  
(d) **artifact pointer** — a clickable or navigable reference to the run output (log file path, test report URL, or inline output block).

No bare "all clean ✓" is acceptable for the conjunct-(iii) gates (plan-gate and final-review-gate). Every per-AC digest entry at those gates must populate all four fields — interpreted per each gate's own "Digest at..." section (coverage claims at the plan gate, executed-check output at the final-review gate). An entry that omits any field is treated as incomplete evidence and triggers the failure-mode rule below. (Note: the spec-gate digest carries zero AC rows by design — no checks have run at spec time — and its non-AC content does not invoke this four-field rule.)

## failure-mode

If any machine-checkable AC's evidence cannot be assembled — because a check has not been run, its output is unavailable, a required `file:line` pointer is absent, or the evidence is stale relative to HEAD — the gate renders today's full sign-off prompt. Summary-confirm is never offered on incomplete evidence. This applies regardless of whether QA returned clean or markers are absent; conjunct (iii) failure alone is sufficient to suppress summary-confirm.

## board-swap-rule

When a piece carries the front-matter annotation `review_board_variant: doc-as-code`, the board-composition layer applies the following swap at dispatch time:

- **Omit** the `review-board-blind` seat.
- **Dispatch a second `review-board-edge-case` seat** (in place of the omitted blind seat).
- Seat count is unchanged by the swap (one seat removed, one seat added).

The two edge-case dispatches carry differentiated lens seeds injected into their prompts:

**seed-A (structural / pointer-integrity):** broken cross-references, unresolved `§`/anchor links, stale `file:line` citations, missing `.agent.md` mirror edits, dangling cited IDs.

**seed-B (content / semantic):** cross-doc contradictions, skill-vs-reference rule drift, example/contract mismatch, unhandled prose edge cases.

When the `review_board_variant` annotation is absent, the board composition is today's roster — including the blind seat — unchanged.

This swap applies at two dispatch surfaces: execute Final Review Step 1 (in-pipeline) and the out-of-band `spec-flow:review-board` skill.
