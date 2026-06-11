---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: gate-scaling

**PRD Sections:** FR-012, SC-008, G-6
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** metrics (merged)

## Goal

Make the cost of a human sign-off scale with how much a machine can verify — without ever removing the gate. Every acceptance criterion is tagged at spec time as **machine-checkable** (a named grep/script/test decides) or **judgment-required** (a named human decides). When a gate's clean predicate holds, the gate renders an evidence digest and offers a single summary-confirm keystroke; anything less gets today's full review prompt. NN-P-001 is preserved in full: a keystroke is always required, nothing auto-advances. Two review-cost controls ship alongside: a `doc-as-code` board variant (swap the low-yield blind reviewer for a differentiated 2nd edge-case reviewer) and a single-Opus triage pre-filter on Final Review fix iterations (full board re-runs only for contested or new findings). The verifiability tag-ratio and the full-gate fallback rate flow into the metrics artifact so SC-008 (operator interactions per clean piece) is measurable.

This spec was authored through the full deliberation protocol (`deliberation.md`, depth=full); all five adversarial lenses returned CONTESTED and convergence folded eight defect classes. Three operator-decidable questions (VOQ-1/2/3) were resolved at brainstorm — recorded under Technical Approach.

## In Scope

- A per-AC verifiability tag carried on the existing `Independent Test:` line in `templates/spec.md`; a new `qa-spec` criterion (#17) enforcing tag presence, delta-conditioned so it never retroactively flags legacy untagged specs.
- A new single-source reference doc `reference/gate-scaling.md` defining the clean-gate predicate, three per-gate evidence rules (anchored subsections), the per-AC evidence-digest payload contract, the Final-Review freshness assertion, and the board-swap rule — cited by anchor from every consuming skill.
- Tiered evidence-digest sign-off wiring at the three gates: spec (Phase 5), plan (Phase 4), execute Final Review (Step 4).
- Additive `metrics.yaml` leaves: per-piece machine-checkable AC ratio + tag counts, and a full-gate fallback rate.
- A `review_board_variant: doc-as-code` annotation that swaps the blind reviewer for a differentiated 2nd edge-case reviewer, wired at **both** execute Final Review Step 1 and the out-of-band `review-board` skill.
- A new Opus agent `agents/review-board-triage.md` (+ `.agent.md` mirror) inserted inside the Step-3 fix loop as a meta-router.

## Out of Scope / Non-Goals

- **AB-1 — aggregate `budget_compliance` reporting in `scripts/metrics-aggregate`.** Deferred (stays in `docs/prds/exec-ready/backlog.md`); a future metrics-aggregate enhancement, not this piece. This piece writes per-piece metrics leaves only; it does not touch the aggregation script.
- **Retroactive tagging of already-merged specs.** Enforcement is authoring-time-only; #17 never converts a shipped untagged spec into a blocking finding (would violate NN-C-003).
- **A file-extension doc-as-code diff classifier.** Dropped during deliberation as scope creep beyond AC-3 and a net-new disagreement surface; the `review_board_variant` annotation is authoritative and sufficient.
- **Changing the circuit-breaker default values** (`qa_max_iterations` is owned by `sonnet-coord`; this piece only pins where triage sits relative to the counter).
- **Token micro-budgeting and cross-machine correlation** (PRD non-goals).

## Requirements

### Functional Requirements

- **FR-001 — Per-AC verifiability tag + qa-spec enforcement.** `templates/spec.md` carries a per-AC verifiability tag on the `Independent Test:` line (`Independent Test [machine: <named check>]:` or `Independent Test [judgment: <named arbiter>]:`, non-empty value). A new `qa-spec` criterion #17 makes an untagged or empty-valued AC must-fix, **delta-conditioned**: it fires only on ACs added or modified in the current authoring delta, and is skipped in Full mode when the spec carries zero tagged ACs (legacy whole-spec signal). The criterion is mirrored into `qa-spec.agent.md`.
- **FR-002 — Verifiability metrics leaves.** `spec/SKILL.md` Phase 5 step 3a computes and upserts an additive leaf under `metrics.yaml` `spec:` recording the machine-checkable / judgment tag counts and the machine-checkable ratio; `schema_version` stays 1; `[METRICS-ABSENT]` when the spec carries no tags. A second additive leaf records the full-gate fallback rate (how often a nominally-clean gate still fell to the full prompt), making SC-008 checkable. `[METRICS-DEGRADED]` never blocks.
- **FR-003 — Single-source `reference/gate-scaling.md`.** One reference doc is the sole home for: the clean-gate predicate; the three per-gate evidence rules as named anchored subsections (`#spec-gate`, `#plan-gate`, `#final-review-gate`); the per-AC evidence-digest payload contract; the Final-Review current-HEAD freshness assertion; and the board-swap rule. Every consuming skill cites by anchor; no skill restates the evidence prose (closes ADR-3 drift).
- **FR-004 — Tiered evidence-digest sign-off gates.** Each of the three gates renders an evidence-digest preamble and offers a single-key summary-confirm **only** when its clean predicate holds; otherwise today's full review prompt runs unchanged. A keystroke is always required on both branches (NN-P-001). Per-gate clean predicate: **spec** = QA-clean ∧ zero surviving `[PENDING-DECISION]`/`[NEEDS CLARIFICATION]` (tags are metrics-only at spec time and are not a gate input — VOQ-1 Option B); **plan** = the spec predicate plus every machine-checkable AC evidenced via an AC-Coverage-Matrix `covered` row with a concrete `file:line`; **Final Review** = the plan predicate plus executed `[Verify]`/oracle output validated by the verify agent, asserted against current HEAD. If any machine-checkable AC's evidence cannot be assembled, the gate falls back to the full prompt; summary-confirm is never offered on incomplete evidence.
- **FR-005 — `review_board_variant: doc-as-code` swap.** An optional per-piece annotation (a HINT) that, when present, causes the binding board-composition decision to omit the blind reviewer and add a second edge-case reviewer; seat count stays 8. The two edge-case seats receive **differentiated lens seeds** — one on structural / pointer-integrity boundaries, one on content / semantic boundaries (VOQ-3). The swap is wired at **both** execute Final Review Step 1 and the out-of-band `review-board` skill (VOQ-2). Absent → today's 8-seat board, identical at both surfaces.
- **FR-006 — `review-board-triage` agent.** A new Opus agent (`agents/review-board-triage.md` + `.agent.md` mirror) is dispatched inside the existing Step-3 fix-loop iteration. It re-checks only the just-fixed findings and inspects the fix diff, rendering a **meta routing verdict** (contested-vs-settled) and is explicitly forbidden from emitting net-new correctness findings. The full board re-dispatches only on one of three fail-open triggers: triage contests that a fix resolves its finding, triage signals a new finding, or the fix touches files beyond the finding's locus. Triage fails open to the full board on ambiguity or BLOCKED. A triage-only cycle does not decrement `qa_max_iterations` (L); only a full-board re-dispatch does.

### Non-Functional Requirements

- **NFR-001 — Backward compatibility (NN-C-003).** Every absent-path is byte-identical to pre-piece behavior: no tag → today's spec authoring; no `review_board_variant` → today's 8-seat board; no triage wiring → today's fix loop; additive metrics leaves keep `schema_version` at 1. New config/annotation keys are optional with documented defaults.
- **NFR-002 — Opus for all new adversarial dispatch (NN-P-005).** The triage agent and any new board seat dispatch on Opus; no path silently downgrades an adversarial gate to a cheaper model.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-001 (version/marketplace sync): the piece bumps `plugins/spec-flow/.claude-plugin/plugin.json` and the matching root `marketplace.json` entry in the same change.
- NN-C-003 (backward compatibility): enforcement is authoring-time-only; all absent-paths are identical to today; config keys and metrics leaves are additive-optional (see NFR-001).
- NN-C-004 (bare agent name): `review-board-triage` frontmatter `name:` is the bare local name.
- NN-C-008 (self-contained agent prompts): the triage prompt carries all context it needs — the just-fixed findings, the fix diff, and the recorded prior deduped board must-fix set — and assumes no conversation history.
- NN-C-009 (version bump all version-bearing files): the change bumps every version-bearing file for spec-flow with a CHANGELOG entry.

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-001 (human gate never removed): summary-confirm is always an explicit keystroke; not-clean → today's full prompt; no gate path auto-advances. This is the central invariant of the piece.
- NN-P-005 (thinking on Opus, no silent upgrade): all new adversarial gates (triage, swapped board seats) run on Opus; the variant is never aliased to `tdd:`.

### Coding Rules Honored

- CR-007 (config keys documented inline): `review_board_variant` is documented in `templates/pipeline-config.yaml` with valid values and default-when-absent behavior.
- CR-008 (thin-orchestrator / narrow-executor): the clean-gate predicate and evidence rules live in `reference/gate-scaling.md`; skills cite by anchor; the triage agent is a narrow executor.
- CR-001 (agent frontmatter schema): the triage agent carries `name` + `description` YAML frontmatter.

## Acceptance Criteria

AC-1: Given the spec template, When an AC block is authored, Then its `Independent Test:` line must carry a `[machine: <check>]` or `[judgment: <arbiter>]` tag with a non-empty value.
  Independent Test [machine: every AC block in `templates/spec.md` has an `Independent Test` line containing `[machine:` or `[judgment:` followed by non-empty text]

AC-2: Given `qa-spec`, When it reviews a spec, Then criterion #17 enforces tag presence and is delta-conditioned (fires only on current-delta ACs; skipped in Full mode when the spec has zero tagged ACs), mirrored into `qa-spec.agent.md`.
  Independent Test [machine: grep `agents/qa-spec.md` and `agents/qa-spec.agent.md` for criterion #17 and the delta-conditioning + zero-tag-skip clauses in both files]

AC-3: Given a newly added untagged AC versus a legacy all-untagged spec re-run in Full mode, When #17 evaluates, Then the new AC is must-fix and the legacy spec is not flagged.
  Independent Test [judgment: reviewer confirms #17's two-branch conditioning covers both scenarios as written]

AC-4: Given `reference/metrics-artifact.md`, When the verifiability leaf is added, Then it documents machine/judgment tag counts and a machine-checkable ratio under `spec:`, and `schema_version` remains 1.
  Independent Test [machine: grep `metrics-artifact.md` for the tag-count + ratio leaf; assert no `schema_version` increment was added]

AC-5: Given `spec/SKILL.md` Phase 5 step 3a, When a spec is finalized, Then the ratio leaf is upserted; a spec with no tags emits `[METRICS-ABSENT]`.
  Independent Test [machine: grep `spec/SKILL.md` Phase 5 step 3a for the ratio-leaf upsert and the `[METRICS-ABSENT]` path]

AC-6: Given `reference/metrics-artifact.md`, When the fallback-rate leaf is added, Then it records how often a nominally-clean gate fell to the full prompt (count and/or rate).
  Independent Test [machine: grep `metrics-artifact.md` for the full-gate fallback-rate leaf definition]

AC-7: Given the codebase, When `reference/gate-scaling.md` is created, Then it contains the named subsections `#spec-gate`, `#plan-gate`, `#final-review-gate`, the clean-predicate, the digest-payload contract, and the board-swap rule.
  Independent Test [machine: grep `reference/gate-scaling.md` for all six required headings/anchors]

AC-8: Given the consuming skills, When they reference the evidence rules, Then `spec`, `plan`, `execute`, and `review-board` SKILL.md cite `reference/gate-scaling.md` by anchor and none restates the per-gate evidence prose.
  Independent Test [machine: grep the four skills for the `gate-scaling.md` anchored citation; assert the per-gate evidence-rule prose appears only in the reference doc]

AC-9: Given each of spec Phase 5, plan Phase 4, and execute Final Review Step 4, When a gate runs, Then it has a clean-branch (digest + single-key confirm) and an else-branch (today's full prompt), with a keystroke required on both.
  Independent Test [machine: grep the three gate sites for the clean-branch, the full-prompt fallback branch, and an explicit operator keystroke on each path]

AC-10: Given `reference/gate-scaling.md#spec-gate`, When the spec-gate predicate is defined, Then it is QA-clean ∧ zero surviving `[PENDING-DECISION]`/`[NEEDS CLARIFICATION]`, and it explicitly states tags are metrics-only at spec time and not a gate input (VOQ-1 Option B).
  Independent Test [machine: grep `#spec-gate` for the QA-clean + zero-markers predicate and the "tags are metrics-only / not a gate input" statement]

AC-11: Given the plan and Final-Review evidence rules, When defined, Then `#plan-gate` evidence = AC-Coverage-Matrix `covered` + concrete `file:line`, and `#final-review-gate` evidence = executed `[Verify]`/oracle + verify-agent, asserted against current HEAD.
  Independent Test [machine: grep `#plan-gate` and `#final-review-gate` for their evidence sources and the current-HEAD freshness clause]

AC-12: Given the digest-payload contract, When defined, Then it enumerates, per machine-checkable AC: check name, run status, pass/fail count, and an artifact pointer (no bare "all clean ✓").
  Independent Test [machine: grep the digest-payload subsection for the four required per-AC fields]

AC-13: Given a machine-checkable AC whose evidence cannot be assembled, When the gate evaluates, Then it renders the full prompt and never offers summary-confirm on incomplete evidence.
  Independent Test [machine: grep `reference/gate-scaling.md` for the predicate-false → full-prompt fallback rule covering the un-assemblable-evidence case]

AC-14: Given any of the three gates, When the clean predicate holds, Then no path auto-advances — an operator keystroke is required (NN-P-001).
  Independent Test [judgment: reviewer confirms no gate path in the three skills advances without an operator keystroke on the clean branch]

AC-15: Given a piece annotated `review_board_variant: doc-as-code`, When the board is composed at execute Final Review Step 1 or in the `review-board` skill, Then the blind seat is omitted and a 2nd edge-case seat is added (seat count stays 8); absent → blind retained.
  Independent Test [machine: grep `skills/execute/SKILL.md` Final Review Step 1 and `skills/review-board/SKILL.md` for the variant read, the conditional blind→edge-case swap, and the seat-count invariant]

AC-16: Given the swap fires, When the two edge-case seats are dispatched, Then they carry differentiated lens seeds (structural/pointer-integrity vs content/semantic) named in the board-swap subsection.
  Independent Test [machine: grep `reference/gate-scaling.md` board-swap subsection for the two differentiated lens-seed labels and grep the dispatch sites for seed injection]

AC-17: Given no `review_board_variant` annotation, When the board is composed at either surface, Then composition is identical to today (8 seats including blind).
  Independent Test [judgment: reviewer diffs the absent-variant dispatch at both surfaces against current `master` and confirms no change]

AC-18: Given the codebase, When the triage agent is added, Then `agents/review-board-triage.md` and `agents/review-board-triage.agent.md` exist with frontmatter `name: review-board-triage` (bare) and `model: opus`.
  Independent Test [machine: ls both files; grep frontmatter for the bare `name` and `model: opus`]

AC-19: Given the triage agent prompt, When authored, Then it constrains output to a meta routing verdict, forbids net-new correctness findings, scopes input to the just-fixed findings + the fix diff, and names the three fail-open triggers (contested fix, new-finding signal, fix touches files beyond the finding locus).
  Independent Test [machine: grep the triage agent for the meta-routing-only constraint, the forbidden-net-new clause, the fix-diff scope, and the three triggers]

AC-20: Given execute Final Review Step 3, When triage is wired, Then the triage dispatch sits inside the existing fix-loop iteration and `qa_max_iterations` (L) decrements only on a full-board re-dispatch, never on a triage-only cycle.
  Independent Test [machine: grep `skills/execute/SKILL.md` Step 3 for the in-iteration triage insertion and the L-decrement-only-on-full-board rule]

AC-21: Given triage unwired/off, When the Step-3 fix loop runs, Then the full board re-dispatches exactly as today.
  Independent Test [judgment: reviewer confirms the no-triage path matches current Step-3 behavior]

AC-22: Given the change, When committed, Then spec-flow's version is bumped in `plugin.json` and the root `marketplace.json` entry, with a CHANGELOG entry (NN-C-001/009).
  Independent Test [machine: compare the `plugin.json` version to the `marketplace.json` spec-flow entry for equality; grep `CHANGELOG.md` for the new version heading]

## Technical Approach

**Composable spine (3 clusters, one piece).** C1 tagging writes the verifiability tag at authoring time; C2's gate predicate reads it downstream; C1 metrics records the ratio. C3 board controls are independent of gate rendering. Binding seams: the tag is written before any gate reads it; `review_board_variant` is defined once and never aliased to `tdd:`; `reference/gate-scaling.md` is the single source cited by anchor; all new gates and triage are Opus; summary-confirm is always a keystroke.

**Per-gate predicate ladder (VOQ-1 = Option B).** The clean predicate strengthens left-to-right: spec = `QA-clean ∧ zero-markers` (tags do **not** gate at spec time — they are recorded for metrics only, and a dishonest machine tag self-corrects downstream because no evidence can be assembled for it); plan adds `every machine-checkable AC evidenced (matrix covered + file:line)`; Final Review adds `executed Verify/oracle validated against current HEAD`. This keeps the spec gate in cost-scaling per AC-2's literal text while closing the self-certification risk both the risk and user-intent lenses raised: the spec-gate confirm rests only on two independently machine-verifiable facts, never on an unrun self-authored tag.

**Board swap (VOQ-2 = both surfaces; VOQ-3 = differentiated seeds).** The blind reviewer is the documented low-yield seat on doc-as-code diffs (pi-011 retro: blind 0/6 must-fixes, edge-case 6/6). When `review_board_variant: doc-as-code` is set, the binding composition step omits blind and adds a 2nd edge-case with a distinct lens seed so the swap adds coverage rather than producing dedup-collapsed duplicates. The swap rule lives in `reference/gate-scaling.md` and is wired at both execute Final Review and the out-of-band `review-board` skill so the same diff gets identical composition wherever the board runs.

**Triage meta-router.** A single Opus pass (Cascaded Selective Evaluation / Trust-or-Escalate pattern) re-checks fixed findings before any full-board re-dispatch. It is a router, not a reviewer: it cannot emit net-new correctness findings (that would duplicate the blind/edge-case seats); it can only route to the full board on the three conservative fail-open triggers. Pinned inside the Step-3 iteration so it never consumes the operator-configured `qa_max_iterations` budget.

## Testing Strategy

- This is a doc-as-code piece (markdown skills, agents, templates, reference docs, YAML config). "Machine-checkable" ACs are grep/bash assertions over the committed artifacts; "judgment-required" ACs are reviewer inspections of prose-encoded conditional logic.
- **Per-artifact greps** for every machine AC (template tag presence, qa-spec #17 clauses, reference-doc anchors, gate-site branches, metrics leaves, agent frontmatter, version sync).
- **Branch-enumeration** focus for the conditional logic: #17 delta-conditioning (new vs legacy), the per-gate predicate ladder, the absent-variant / absent-triage identity paths, and the three triage fail-open triggers.
- **Edge cases:** zero-tag legacy spec re-run; un-assemblable evidence → full-prompt fallback; a fix touching files beyond the finding locus → full board; `[METRICS-ABSENT]` / `[METRICS-DEGRADED]` non-blocking paths.

## Integration Coverage

- Integration: `reference/gate-scaling.md`→`spec`/`plan`/`execute`/`review-board` SKILL.md — inside:{reference doc + four consuming skills}; doubled externals: none (internal cite-by-anchor wiring); AC-8; verified by grep that the rule is single-sourced.
- Integration: execute Final Review Step 3 orchestrator→`review-board-triage` agent — inside:{execute orchestrator + triage agent dispatch}; doubled externals: none (internal subagent dispatch); AC-19, AC-20.
- Integration: `review_board_variant` annotation→board composition at execute Step 1 and `review-board` skill — inside:{annotation reader + two composition sites}; doubled externals: none; AC-15, AC-17.
- No external services or APIs are in scope; all wiring is internal skill↔reference citation and orchestrator↔agent dispatch.

## Open Questions

- None. VOQ-1 (spec-gate basis → Option B), VOQ-2 (swap scope → both surfaces), and VOQ-3 (differentiated lens seed) were resolved at brainstorm; see `deliberation.md` §Validated Open Questions and §Recommendation. No `[NEEDS CLARIFICATION]` or `[PENDING-DECISION]` markers survive.
