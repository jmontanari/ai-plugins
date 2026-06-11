# Deliberation — exec-ready / gate-scaling (FR-012)

## Investigation Summary

Resolved depth: **full**. Decision unit: FR-012 (cost-scaling of human review gates), evaluated as **3 sub-capability clusters**:

- **C1 — Machine-checkable AC tagging.** Extend the per-AC `Independent Test:` sub-line with a `[machine: <named check>]` / `[judgment: <named arbiter>]` tag; qa-spec enforces presence; metrics gains an additive machine-checkable-ratio + tag-counts leaf. Authoring-time-only.
- **C2 — Tiered gate evidence + summary-confirm.** A single shared `reference/gate-scaling.md` defines an evidence-digest preamble, a single-key summary-confirm on a clean branch (else today's full prompt), and three explicit per-gate evidence rules (spec / plan / Final-Review). Clean predicate = three-input AND (QA-clean ∧ zero surviving `[PENDING-DECISION]`/`[NEEDS CLARIFICATION]` ∧ every machine-checkable AC evidenced).
- **C3 — Review-board scaling on doc-as-code.** `review_board_variant` annotation, blind→edge-case seat swap at execute Final Review (seat count stays 8), and a new Opus `review-board-triage` agent at the Step-3 fix loop.

The investigation confirmed: the metrics leaf is additive (schema_version stays 1); existing AC-format consumers are inert to the bracket tag; the not-clean→full-prompt fallback preserves the human gate; the absent-variant path is identical to today. The full set of Phase D lenses (architecture-integrity, scope/simplicity, user-intent, backward-compat, risk) returned verdicts; all five were CONTESTED, and convergence folded the resolvable defects into a revised recommendation, leaving three genuinely operator-decidable questions.

## Viability Analysis

### Cluster C1 — Machine-checkable AC tagging

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| Extend per-AC `Independent Test:` with `[machine:]`/`[judgment:]` tag; qa-spec #17 enforces presence; additive metrics leaf | VIABLE | Smallest surface; rides the existing AC sub-line; metrics leaf additive so schema_version stays 1; bracket tag inert to all current AC-format consumers | Yes — extends existing `Independent Test:` line and templates/spec.md AC format; metrics.yaml `spec:` block | — |
| New separate tag file / sidecar registry of checks | NON-VIABLE | Introduces a second source of truth for per-AC check identity that must be kept in sync with the AC text; no existing consumer to reuse | No | Sidecar drifts from AC text; no existing parser keys on a separate file — net-new sync failure mode for zero gain over the inline tag |

### Cluster C2 — Tiered gate evidence + summary-confirm

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| Single shared `reference/gate-scaling.md`; three per-gate evidence rules as named anchored subsections; clean predicate = three-input AND; not-clean→full prompt | VIABLE | Single source of truth defeats ADR-3 evidence-prose drift; predicate is machine-readable for plan/Final-Review; fallback preserves the human gate (NN-C honored) | Yes — cites existing gate skills (spec/plan/execute) and existing QA-clean + marker scan; reuses today's full-prompt path as the fallback | — |
| Per-skill inline evidence prose (each gate carries its own evidence rules) | NON-VIABLE | Three copies of the evidence contract drift independently; this is the exact ADR-3 failure architecture-integrity flagged | No | Evidence prose duplicated across three skills → divergence → gate semantics fracture; violates single-source ADR-3 |
| Summary-confirm applied uniformly at all three gates resting on per-AC tag honesty | NON-VIABLE (as a uniform default) | At spec time nothing has run; tag honesty is self-certified by the same pipeline LLM that benefits from unlocking the cheap gate; no independent check exists at spec time | Partial | Self-certification keystone: spec-gate one-key confirm would rest on an UNRUN, self-authored tag — inverts US-012. Surviving as **VOQ-1** (operator-decidable). |

### Cluster C3 — Review-board scaling on doc-as-code

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| `review_board_variant: doc-as-code` annotation (a HINT); binding swap decision in execute Step 1; blind→edge-case swap; new Opus `review-board-triage` agent at Step 3 constrained to meta routing | VIABLE | Annotation is authoritative + sufficient for AC-3; binding decision lives in the layer that owns board composition; triage is decoupled from `tdd:` and fails open | Yes — extends execute Final Review board composition + the existing Step-3 fix loop; mirrors agent-file convention | — |
| File-extension diff classifier guard alongside the annotation | NON-VIABLE | No classifier exists to reuse; it creates a new annotation-vs-classifier-disagree failure mode; beyond AC-3 which annotation-only already satisfies | No | Classifier is net-new subsystem and a new contradiction surface for zero AC coverage gain → dropped by convergence (see §Answered by Investigation) |
| Triage agent permitted to render net-new correctness findings | NON-VIABLE | Re-checking a fix for regression IS blind/edge-case work; a triage that emits new correctness findings overlaps and duplicates seated reviewers | No | Ownership overlap with blind/edge-case seats; triage must be constrained to contested-vs-settled meta routing, forbidden from net-new findings |

## Integration Check

Phase C ran (3 clusters). The composable spine and its binding seams hold after convergence, with the following cross-cluster constraints pinned:

- **Tag write before gate read.** C1 writes the machine-checkable tag at authoring time; C2's clean predicate reads it at gate time. Ordering is one-directional and must not be inverted.
- **Single source of truth.** `reference/gate-scaling.md` is the single home for: the three per-gate evidence rules (now as named anchored subsections `#spec-gate` / `#plan-gate` / `#final-review-gate`), the clean predicate, the per-AC digest payload contract, and the board-swap rule. Each skill cites by anchor; no skill carries its own evidence prose. This closes the ADR-3 drift the architecture lens raised.
- **`review_board_variant` defined once, never aliased to `tdd:`.** The variant is a board-composition concept; coupling it to the TDD track would re-introduce the breaker coupling the risk and architecture lenses cleared.
- **All gates + triage are Opus** (NN-P-005); **summary-confirm is ALWAYS a keystroke** (NN-P-001), never auto-advance.
- **Board-swap ownership.** The swap rule (including the variant) must live in `reference/gate-scaling.md`. Whether it is cited by execute only, or also by the out-of-band review-board skill, is an unresolved cross-surface conflict surviving as **VOQ-2** — if the rule is owned by execute only, seat-composition ownership could fracture when review-board runs out of band; if cited by both, the single-source constraint is preserved but scope widens past AC-3's execute vocabulary.

Narrowed composable path set: C1 inline-tag path + C2 single-doc/anchored-rules path + C3 annotation-only/constrained-triage path. The one residual integration tension that convergence could not collapse is the board-swap surface scope (VOQ-2).

## Adversarial Review

All five Phase D lenses returned **CONTESTED**. Each held substantial portions of the Phase C spine and raised specific, resolvable defects (most folded by convergence; three load-bearing questions survive).

| Lens | Verdict | Held | Contested (disposition) |
|------|---------|------|--------------------------|
| architecture-integrity | CONTESTED | C1 tag location + metrics ownership; C3 breaker-decoupling from `tdd:` | (1) ADR-3 drift only defeated if 3 evidence rules are NAMED anchored subsections in `reference/gate-scaling.md` — **folded**. (2) Triage ownership overlap — constrain to meta routing, forbid net-new findings — **folded**. (3) Doc-as-code detection split — annotation is a HINT, binding decision in execute Step 1 — **folded**. (4) Swap rule must live in gate-scaling.md, cited by both surfaces — **survives as VOQ-2**. |
| scope/simplicity | CONTESTED | C1 simplest path; C2 single doc; 3 per-gate rules necessary not creep; all 5 ACs mapped | (1) File-extension classifier guard is creep — **DROP, folded**. (2) Differentiated lens seed beyond literal AC-3 floor — **flagged, survives as VOQ-3**. (3) Open-question answer = execute-only (extending to review-board is creep) — **feeds VOQ-2**. |
| user-intent | CONTESTED | Triage fail-open protects "contested pieces get full attention" | (1) Spec-gate summary-confirm on an UNRUN named check inverts US-012 — **survives as VOQ-1**. (2) "Render an evidence digest" too vague → enumerated per-AC digest payload contract — **folded**. (3) SC-008 measurability → instrument full-gate fallback rate — **folded**. |
| backward-compat | CONTESTED | Metrics leaf additive, schema_version stays 1 (metrics-artifact.md:80); AC-format consumers inert to tag; not-clean→full-prompt preserves gate; absent-variant identical to today | (1) qa-spec #17 "authoring-time-only" FALSE as stated → add explicit delta/age conditioning (fire only on ACs added/modified in current delta; skip Full-mode when zero tagged ACs) — **folded**. (2) Triage insertion must be PINNED inside Step 3's existing iteration so it doesn't change L-counting — **folded**. (3) NN-C-009 version bump all version-bearing files — **folded** (carried into plan). |
| risk | CONTESTED | Doc-as-code classifier-evasion bounded; metrics dependency non-blocking ([METRICS-DEGRADED]); compound clean-gate machine-readable for plan/Final-Review | (1) SELF-CERTIFICATION is keystone risk, UNGUARDED at spec gate — **survives as VOQ-1**. (2) Triage false-negative: scope must include the fix DIFF + third fail-open trigger "fix touches files beyond finding locus → full board" — **folded**. (3) Evidence staleness: digest must assert evidence produced against current HEAD (or re-run on final commit) — **folded**. |

## Recommendation

Ship FR-012 as the three-cluster composable spine **with the following convergence fixes folded in**:

**C1 — Machine-checkable AC tagging.** Extend the per-AC `Independent Test:` sub-line to `Independent Test [machine: <named check>]:` / `Independent Test [judgment: <named arbiter>]:`. qa-spec #17 enforces tag presence and mirrors into `.agent.md`, but with **explicit delta-conditioning: #17 fires only on ACs added or modified in the current authoring delta, and is skipped in Full mode when the spec carries zero tagged ACs (legacy whole-spec signal).** This closes the back-compat regression for legacy untagged specs (NN-C-003). spec Phase 5 step 3a writes an additive machine-checkable-ratio + tag-counts leaf into `metrics.yaml` `spec:` (schema_version stays 1; `[METRICS-ABSENT]` when no tags). Authoring-time-only.

**C2 — Tiered gate evidence + summary-confirm.** A single shared `reference/gate-scaling.md` is the sole source of truth, cited by anchor from spec/plan/execute. It defines, as **named anchored subsections (`#spec-gate`, `#plan-gate`, `#final-review-gate`)**, the three explicit per-gate evidence rules: spec = named-check-string / no-run; plan = AC-Coverage-Matrix covered + `file:line`; Final-Review = executed `[Verify]` / oracle + verify-agent. Skills cite the anchors; no skill carries its own evidence prose (closes ADR-3 drift). The clean predicate is the three-input AND (QA-clean ∧ zero surviving `[PENDING-DECISION]`/`[NEEDS CLARIFICATION]` ∧ every machine-checkable AC evidenced); predicate-false → today's full prompt. The evidence digest carries an **enumerated per-AC minimum payload contract** (per machine-checkable AC: check name + run status + pass/fail count + clickable artifact pointer) — no bare "all clean ✓". At Final Review the digest must **assert evidence was produced against current HEAD (or be re-run on the final commit)** before summary-confirm. Summary-confirm is ALWAYS a keystroke (NN-P-001). **The full-gate fallback rate is instrumented as a metrics leaf** (how often a nominally-clean piece still hits full-gate due to one un-assembled AC), making SC-008's oversight-reduction claim checkable.

> **Deferred to brainstorm (VOQ-1):** whether summary-confirm applies at the **spec gate at all**, and on what basis, is the load-bearing decision. The conservative cut (both risk and user-intent lean toward it) is to restrict true cost-scaling to plan + Final-Review and keep the spec gate full. This recommendation does NOT pre-decide it; tags remain a metrics-only signal at spec time unless the operator chooses otherwise.

**C3 — Review-board scaling on doc-as-code.** `review_board_variant: doc-as-code` annotation **only** — the file-extension classifier guard is **dropped** (annotation is authoritative + sufficient; the classifier was a net-new subsystem and a new disagreement surface). The annotation is a **HINT**; the binding swap decision lives in **execute Final Review Step 1** (the layer that owns board composition). The swap is blind → edge-case at Step 1; seat count stays 8. A new Opus agent `agents/review-board-triage.md` (+ mirror) runs at the Step-3 fix loop, **constrained to a META routing judgment (contested-vs-settled), EXPLICITLY FORBIDDEN from rendering net-new correctness findings**; its scope **includes the fix DIFF**; it has a **third fail-open trigger: "fix touches files beyond the finding's locus → full board"**; it fails open to the full board; and its insertion point is **PINNED inside Step 3's existing iteration so triage-only cycles do not decrement `qa_max_iterations` (L)**. The swap rule (including the variant) lives in `reference/gate-scaling.md`.

**Cross-cutting:** all gates + triage are Opus (NN-P-005); `review_board_variant` is defined once and never aliased to `tdd:`; per NN-C-009 the plan must version-bump every version-bearing file.

VOQ-1, VOQ-2, and VOQ-3 are explicitly deferred to brainstorm; none blocks the spine, but VOQ-1 governs whether the spec gate participates in cost-scaling at all.

## Validated Open Questions

**VOQ-1 — Spec-gate cost-scaling (load-bearing).** Does summary-confirm apply at the **spec gate** at all, and if so on what basis? At spec time nothing has run; the machine-checkable tag is self-authored by the same pipeline LLM that benefits from the cheap gate, qa-spec #17 checks presence not honesty, and the only anti-theater machinery (ac-matrix vague-pointer reject; verify Audit on `file:line`) lives downstream where those pointers don't yet exist — so the spec gate has zero independent check. Operator must choose:
- **Option A (conservative — risk + user-intent lean here):** restrict true cost-scaling to plan + Final-Review only; the spec gate always uses the full prompt.
- **Option B:** spec-gate summary-confirm rests ONLY on QA-clean + zero markers; tags are metrics-only at spec time.
- **Option C:** spec-gate offers summary-confirm + a mandatory "nothing has run yet — you are confirming spec quality, not machine proof" disclosure, AND qa-spec defends each machine-checkable tag by re-deriving the check from the AC text (presence + honesty).

**VOQ-2 — Board-swap surface scope.** Is the blind→edge-case swap rule scoped to **execute Final Review only** (scope lens: AC-3 uses execute-board vocabulary; extending further is creep), or does it **also bind the out-of-band review-board skill** (architecture lens: the swap rule lives in `reference/gate-scaling.md` and must be cited by both surfaces or seat-composition ownership fractures)? Genuine cross-surface tension; operator must pick the ownership boundary.

**VOQ-3 — Differentiated lens seed vs literal AC floor (minor).** For the 2nd edge-case reviewer introduced by the swap, do we use a **differentiated lens seed** (an edge-case swap with a distinct seed so the swap is non-vacuous — technically beyond AC-3's literal text), or trim to the **literal AC floor** ("2nd edge-case reviewer, same seed")? Defensible either way; operator decides whether the differentiated seed is in-scope.

## Answered by Investigation

- **File-extension classifier guard (C3) — RESOLVED: dropped.** Strong 3-lens convergence (scope: creep beyond AC-3; architecture: detection should not split across two layers; risk: bounded but ambiguous). The `review_board_variant: doc-as-code` annotation alone is authoritative and sufficient; the annotation is renamed a HINT and the binding decision moves to execute Step 1. The classifier would have added a net-new subsystem and an annotation-vs-classifier-disagree failure mode for zero AC coverage gain.
- **qa-spec #17 back-compat break — RESOLVED: delta-conditioning added.** #17's "authoring-time-only" claim was false as stated (qa-spec.md has no spec-age conditioning). Fix: #17 fires only on ACs added/modified in the current authoring delta and is skipped in Full mode when the spec carries zero tagged ACs. Closes the legacy-spec gate regression (NN-C-003).
- **ADR-3 evidence-prose drift — RESOLVED: anchored single source.** The three per-gate evidence rules are enumerated as named anchored subsections inside `reference/gate-scaling.md` (`#spec-gate`/`#plan-gate`/`#final-review-gate`), cited by anchor from each skill. No skill carries its own evidence prose.
- **Triage ownership overlap + false-negative — RESOLVED: constrained scope.** `review-board-triage` is constrained to a meta routing judgment (contested-vs-settled), forbidden from net-new correctness findings; its scope includes the fix DIFF; it gains a third fail-open trigger ("fix touches files beyond the finding's locus → full board"); insertion is pinned inside Step 3's existing iteration so triage-only cycles don't decrement L.
- **Vague "evidence digest" + evidence staleness — RESOLVED: enumerated payload + freshness assertion.** Per-AC minimum digest payload contract (check name + run status + pass/fail count + clickable artifact pointer); at Final Review the digest must assert evidence was produced against current HEAD (or be re-run on the final commit).
- **SC-008 measurability — RESOLVED: full-gate fallback rate instrumented** as a metrics leaf, making the oversight-reduction claim checkable.
- **Metrics additivity / AC-format consumer compatibility — CONFIRMED N/A as a break.** Verified additive leaf keeps schema_version 1 (metrics-artifact.md:80); plan AC extraction, ac-matrix, lint-skill-coherence, and Testability all key on AC id/content, inert to the bracket tag. C2 not-clean→full-prompt and C3 absent-variant-path both preserve current behavior exactly.
- **Triage L-counting / version bump — RESOLVED & CARRIED.** Triage pinned inside the counted iteration (precedent: 9th verify-piece-full member sits outside the counted cycle); NN-C-009 version bump of all version-bearing files carried into the plan.
