# Learnings — exec-ready/gate-scaling

Verifiability-scaled sign-off gates + review-board cost controls (FR-012). 8 Implement-track phases + 3 Final Review board iterations; shipped spec-flow 5.13.0. Piece dog-fooded its own gate-scaling feature at sign-off.

## Patterns that worked well

- **doc-as-code board variant delivered its ROI.** The two seeded edge-case reviewers each found a must-fix the other didn't: seed-A (structural/pointer-integrity) caught the dangling `T-1` reference in `execute/SKILL.md`; seed-B (content/semantic) caught the SSOT-consumer ordering drift between `reference/gate-scaling.md` and `skills/spec/SKILL.md`. A single un-seeded edge-case reviewer would have had lower coverage across both failure modes.
- **Triage agent settled correctly on both passes.** Iter-2 triage correctly triggered full-board re-dispatch (new signal from bundled should-fix additions; out-of-locus triage file edits). Iter-3 triage correctly settled — all findings addressed, no new signals. No false-settle on unresolved items, no false-trigger on cosmetic-only diffs.
- **Piece dog-fooded its own design.** The gate-scaling piece itself went through the final-review gate with an evidence digest and summary-confirm — the exact flow it was specifying. The `machine_checkable_ratio` advisory field was present (computed from the spec's AC tags) and the three conjuncts all held on current HEAD. This provided a live integration test of the spec's predicate logic before the commit landed.
- **SSOT-first structure across 8 phases.** Phase 1 (reference/gate-scaling.md) defined every term, predicate, and contract once. Phases 2–8 (skill edits, agent edits, template updates, version bump) cited by anchor rather than restating definitions. No intra-piece drift was found at QA because there was nothing to drift — consumers pointed at the SSOT. The one ordering drift found (spec SKILL → SSOT) was a skill that pre-dated the SSOT, not a new divergence.

## Issues QA caught

- **Iter-1 Final Review (5 must-fix):** triage dispatch site in `execute/SKILL.md` lacked structural delimiters; fallback-rate formula in `reference/metrics-artifact.md` used wrong denominator; plan-gate carve-out absent from `evidence-digest-payload` scope note; `review_board_variant` annotation missing from plan front-matter; board-swap rule in `skills/review-board/SKILL.md` not wired. All 5 fixed in iter-1 fix commit.
- **Iter-2 triage → full board (2 must-fix from new signals):** iter-1 fix commit bundled must-fix corrections with should-fix additions (machine_checkable_ratio SSOT field, triage output-format clause). Seed-A found dangling `T-1` reference (SA-MF-1); seed-B found unconditional ratio listing in spec SKILL (SB-EC-1) and mislabeled "executed check evidence" scope in `evidence-digest-payload` (SB-EC-2). Both fixed in iter-2 fix commit (must-fix only; should-fix in separate commit per MF-GS-1 lesson).
- **Iter-3 triage → settled:** all findings addressed; no new signals; triage returned settled. No further full-board dispatch.

## Recommendations for future specs (deferred to improvement-backlog)

- **Separate must-fix and should-fix into distinct fix commits.** Bundling both in one commit exposes should-fix content to triage's new-signal detector, triggering an avoidable full-board re-dispatch. The fix-code guidance should require separate commits when both tiers are present. (MF-GS-1)
- **SSOT-then-consumers review pass for conditional language.** When a piece introduces an SSOT + consuming skills, the plan's `[Verify]` at the SSOT phase should assert that consuming-skill gate-sites match the SSOT's conditional/advisory language — not just that the SSOT itself is present. (MF-GS-2)
- **Coherence linter false-positive suppression.** Pre-existing cross-file step references in `metrics-artifact.md` and a false-positive on `gate-scaling.md:70` cause non-zero linter exit on every run, masking real future violations. A `known-violations` suppression mechanism is needed. (MF-GS-3; see also GS-2 in exec-ready backlog)

## Notes for downstream pieces

The `gate_scaling.spec_gate` and `gate_scaling.plan_gate` blocks are absent from this piece's own `metrics.yaml` — those gates ran before this feature existed. Pre-5.13 pieces should record an explicit comment at the omitted block site. A backfill convention for `reference/metrics-artifact.md §gate_scaling` is in the exec-ready backlog (GS-3).

The `machine_checkable_ratio` advisory field demonstrated the advisory-fields contract for the first time. Future gate extensions adding advisory-only fields should cite `reference/gate-scaling.md#advisory-fields` once that anchor is added (exec-ready backlog GS-4).
