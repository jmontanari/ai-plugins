# Deliberation — piece outcome-acs (PRD exec-ready, FR-018)

## Investigation Summary

**Resolved depth:** `full`.

Phase A confirmed no genuine web unknowns — this is an internal spec-flow-plugin doc-as-code piece governed by existing project convention (charter coding rules, qa-spec criterion catalog, deliberation-lens table, bracket-tag grammar). Research surfaced 4 affected surfaces: `templates/spec.md` (AC grammar + frontmatter schema), `agents/qa-spec.md` plus its co-ship twin `agents/qa-spec.agent.md` (criterion catalog, byte-identity-enforced), `skills/spec/SKILL.md` (brainstorm Phase 2 wiring), and `agents/deliberation-lens.md` (the 5-row lens table).

The piece introduces **outcome/mechanism acceptance-criteria classification** (FR-018): a way to mark an AC as asserting an observable result-property (`[outcome]`) versus an implementation mechanism (`[mechanism]`), plus a piece-level behavior classification (`piece_class:`) that determines whether a behavior-bearing piece is *required* to carry at least one outcome AC. The design was evaluated across 4 decision-unit clusters (data model, elicitation, qa-spec enforcement, metrics/gate scope). Phase B found all clusters viable with a clear recommended path each; Phase C confirmed the four paths compose; Phase D returned 3 HOLDS and 2 CONTESTED (architecture-integrity, risk). Phase E folds both CONTESTED verdicts into the recommendation and surfaces the surviving genuine decisions as VOQ-tagged open questions for brainstorm.

## Viability Analysis

### DU-1 — Data model (keystone): how an outcome/mechanism AC and a piece's behavior class are represented

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| Inline `[outcome]`/`[mechanism]` bracket tag on the `AC-N:` line; `piece_class: behavior-bearing\|non-behavioral` + `behavior_rationale:` frontmatter keys; PRESENCE of `piece_class:` as legacy-vs-new discriminator (absent ⇒ legacy, never retro-failed) | VIABLE | Tag is orthogonal to the existing `[machine:]`/`[judgment:]` Independent-Test sub-line tag; AC-N ID is left untouched so the AC stays ID-addressable (satisfies SC-010 / AC-4 referenceability). Presence-discriminator gives airtight backward-compat without a date/version field. | Yes — reuses the existing bracket-tag grammar on the AC line and the frontmatter schema in `templates/spec.md` | — |
| Separate `### Outcome AC` subsection | NON-VIABLE | Collides with CR-009 heading-anchor rules and splits the AC ID namespace (outcome ACs would not share the `AC-N` sequence), breaking ID-addressability. | No | CR-009 anchor collision + AC-ID namespace split |
| Prose-in-tag (free-text classification inside the bracket) | NON-VIABLE | Not machine-checkable by qa-spec criterion #17, which must match named tokens, not parse prose. | No | #17 requires named-token matching, not prose parsing |
| `charter_snapshot`-date as legacy discriminator | NON-VIABLE | Re-snapshotting a charter would flip a legacy spec to "new" and retro-fail it. | No | Re-snapshot flips legacy→new (retro-failure) |
| Redundant standalone version-marker key | NON-VIABLE | Duplicates the discriminator already carried by `piece_class:` presence; two sources of truth drift. | No | Redundant with `piece_class:` presence |

### DU-2 — Elicitation: how the brainstorm surfaces outcome ACs

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| New always-run mandatory brainstorm block in `reference/brainstorm-procedure.md` (modeled on the C-2 security sub-block; depth-independent PRIMARY hop) cited from `skills/spec/SKILL.md` Phase 2; extend the `user-intent` lens row's QUESTION in `deliberation-lens.md` (table stays exactly 5 rows); brainstorm zero-answer sign-off gate; auto-skip when non-behavioral | VIABLE | Mandatory always-run block guarantees the elicitation fires regardless of resolved depth (lite/off would otherwise skip it). Extending the existing user-intent lens row (not adding a lens) keeps the table at 5 rows. AC-1 literally requires BOTH the lens AND the spec brainstorm to pose the question — both halves are mandated. | Yes — reuses the C-2 mandatory-block pattern and the existing `user-intent` lens row | — |
| Lens-only path (rely solely on the user-intent lens) | NON-VIABLE | `user-intent` is not in the `lite` lens subset and off-depth skips all phases, so lite/off pieces would silently skip elicitation. | No | Silently skips lite/off-depth pieces |
| Add a 6th lens | NON-VIABLE | Lens table is fixed at 5 rows; a 6th lens changes the board cardinality charter-wide. | No | Breaks fixed 5-row lens table |
| Conversing/multi-turn lens | NON-VIABLE | Lenses are single-pass adversarial challengers; a conversing lens violates the lens contract. | No | Violates single-pass lens contract |
| Step-7-only elicitation (post-AC-authoring) | NON-VIABLE | Elicits after ACs are already written, too late to shape them. | No | Fires after AC authoring |
| New spec-local outcome/mechanism taxonomy | NON-VIABLE | Creates a parallel vocabulary divorced from the shared token glossary. | No | Forks the token vocabulary |

### DU-3 — qa-spec enforcement: how an absent-but-required outcome AC is caught

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| Criterion #17 (catalog currently ends at 16), phrased against NAMED TOKENS, as a 3-state predicate (non-behavioral + rationale ⇒ exempt; behavior-bearing / ambiguous-default ⇒ require ≥1 outcome AC); sentinel-exemption on rationale presence (cf. criterion 15); "absent `piece_class` ⇒ skip" (cf. criterion 16); edited IDENTICALLY into BOTH `agents/qa-spec.md` and `agents/qa-spec.agent.md`; `rubric_version` 1→2; wired into Focused re-review (delta-scoped), out of scope in Focused-charter-re-review mode | VIABLE | Appends without renumbering (the only by-number references in-catalog are criteria 8-11, all below 17). Mirrors the existing presence/sentinel predicate shape of criteria 15-16. rubric_version bump asserts PRESENCE-not-value, breaking no pin. Byte-identity across the twin agents is already test-enforced (`tests/e2e/lib/static.sh` AC-10). | Yes — reuses the criterion-15/16 sentinel/skip pattern and the twin-agent byte-identity test | — |
| Free-text semantic judgment ("is this a good outcome AC?") | NON-VIABLE | qa-spec is read-only and structural; semantic oracle-quality grading belongs to the downstream FR-020 ground-truth lens. | No | Overloads read-only structural qa-spec with semantic judgment |
| Date/version discriminator for piece class | NON-VIABLE | Same re-snapshot flip failure as DU-1's rejected path. | No | Re-snapshot / version-bump flips classification |
| Re-derive piece-class outside the Focused delta | NON-VIABLE | Focused re-review is delta-scoped; re-deriving class outside the delta breaks the focused-mode contract. | No | Violates delta-scoped Focused re-review |

### DU-4 — Metrics / gate scope

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| DEFER ALL (outcome/mechanism metric counts, spec-gate predicate change, SC-010 measurement hooks) | VIABLE | Metric counts are a passive leaf with no consumer until the outcome campaign — YAGNI. This piece's SC-010 obligation is satisfied by ID-addressable outcome ACs (delivered by DU-1), not by a gate change. | Yes — leaves existing gate untouched | — |
| Change the spec-gate predicate to require an outcome AC | NON-VIABLE | ADR-2 and `gate-scaling.md#spec-gate` define the spec-gate as the conjunct (i)∧(ii) only; #17 already rides existing "QA clean" conjunct (i), so no predicate change is needed or permitted. | No | ADR-2 / gate-scaling.md fix the spec-gate to (i)∧(ii) |

## Integration Check

Phase C verdict: **COMPOSABLE.** All four seams HOLD:

1. **Token agreement (producer/consumer).** The `[outcome]`/`[mechanism]` tokens authored by the brainstorm + `templates/spec.md` (producer) are exactly the named tokens matched by qa-spec #17 (consumer). They agree by construction.
2. **Single behavior-bearing definition.** `piece_class: behavior-bearing|non-behavioral` is the one definition consumed by both the brainstorm auto-skip and the #17 3-state predicate.
3. **Two enforcement halves are non-redundant.** The i-D brainstorm block is an INPUT gate ("the outcome question was never *asked/answered*" — caught at sign-off, depth-independent); #17 is an OUTPUT gate ("the answer never *became a tagged AC*" — caught at QA). Deleting either drops a distinct FR-018 acceptance criterion.
4. **DU-4 defer keeps the piece at FR-018's 5 ACs.** No scope creep into metrics/gate.

Phase C flagged two residuals carried into Phase D: (a) the token glossary should be single-sourced; (b) the proposed reliance on `spec-flow-doctrine.md` L179 for the "ambiguous" branch needs scrutiny. Both were challenged in Phase D (see below) and are now folded into VOQ-2 and VOQ-1 respectively.

## Adversarial Review

Phase D dispatched 5 lenses. Result: **3 HOLDS, 2 CONTESTED.**

- **`scope/simplicity` — HOLDS.** Both enforcement halves are required (i-D ↔ AC-1 sign-off; #17 ↔ AC-3 tagged-AC; deleting either drops an AC). The always-run mandatory block is the correct weight — a plain C-3 sub-area carries no mandatory/sign-off-block semantics. The lens extension is mandated by AC-1's literal conjunction ("the user-intent lens AND the spec brainstorm both pose"). DU-4 defer is correct YAGNI (AC-4 needs only ID-referenceability, delivered by DU-1; SC-010 is a linked metric, not an AC). *Soft notes:* (1) the dedicated `behavior_rationale:` key may duplicate the existing C-2 N/A-rationale surfacing channel — confirm not redundant; (2) backward-compat rests entirely on `piece_class:`-presence robustness.

- **`user-intent` — HOLDS.** The outcome AC is consumable by the existing `review-board-ground-truth` seat, which already hunts for "stated expected results." *Soft residual:* #17's structural presence-check cannot distinguish a real result-property oracle from a vacuous one ("must never crash"); US-018 fulfillment depends on the brainstorm eliciting oracle CONTENT and the downstream FR-020 ground-truth lens catching dead-knob oracles. Oracle-quality grading is correctly layered onto the consuming campaign gate, not overloaded onto read-only qa-spec.

- **`backward-compat` — HOLDS.** The discriminator is airtight: the charter-drift path rewrites only `charter_snapshot` and never injects `piece_class`; #17 is out of scope in Focused-charter mode. The `rubric_version` bump asserts PRESENCE not value (no pin broken, no tooling consumes it, no mandatory gold-set re-run contract exists). #17 appends without renumbering (the only by-number references are criteria 8-11, below 17). MINOR version bump is correct (5.16.0 → 5.17.0). *Residual (non-blocking, implementation-fidelity):* a plan-level invariant must hold — the spec skill authors `piece_class` ONLY on greenfield Phase 3; drift/amend must NOT back-fill it into legacy specs.

- **`architecture-integrity` — CONTESTED.** (d) Elevating `spec-flow-doctrine.md` L179 — titled "# TDD Doctrine", sitting under "## TDD Is Opt-In", a *phase*-granularity TDD-track default with NO criteria, owned by the plan layer — into a *spec*-layer WHOLE-PIECE gating discriminator is a cross-layer module-ownership + granularity mismatch. A piece legitimately mixes TDD and Implement phases, so the "ambiguous" branch needs a crisp *piece*-level boundary that the borrowed phase-level term lacks. (c, compounding) No single reference doc owns the `[outcome]`/`[mechanism]` + `piece_class:` token glossary — it is spread across 3 sites, and since #17 is "phrased against named tokens," that risks silent token drift. *Resolution direction:* introduce one reference doc (e.g. `reference/behavior-classification.md`) that defines behavior-bearing vs non-behavioral at PIECE granularity *with actual criteria* AND owns the token glossary, cited by `templates/spec.md` + both qa-spec files + `brainstorm-procedure.md`; `doctrine.md` L179 stays the phase-level TDD default.

- **`risk` — CONTESTED.** (a, PRIMARY) The gate is SELF-ATTESTED: #17 treats rationale PRESENCE as clean (structural, like criterion 15), but "this piece is non-behavioral" is a claim about the system that #17 cannot adjudicate. A behavior-bearing piece mislabeled `non-behavioral: "doc-only change"` sails through with zero outcome ACs — re-creating the exact FR-018 failure class one level up. A cheap cross-check is left on the table: the codebase already splits behavior-bearing vs config/glue at plan time (doctrine.md L179 + plan `tdd:` front-matter). *Fix options:* (i) a downstream cross-check binding `piece_class: non-behavioral` to the plan-time TDD/Implement track choice, flagging divergence as must-fix; OR (ii) explicitly scope-acknowledge self-attestation-with-audit-trail and that downstream FR-020/ground-truth (not this piece) catches mislabel escapes. (b) The single discriminator does double duty (legacy-vs-new AND present-vs-ambiguous): an ambiguous NEW piece whose author OMITS `piece_class` is indistinguishable from a legacy spec, reads exempt, opposite of "default behavior-bearing" — resolved only if the spec skill ALWAYS writes `piece_class` on new specs (ambiguity resolved to behavior-bearing AT AUTHORING, written into the key, never left absent). (c) #17 tag-matching robustness (case-sensitivity / exact-literal) is unspecified — a mis-spelled `[Outcome]` could false-fire (fail-safe) or, with loose matching, false-pass (fail-open); criterion 12 specifies exact matching precisely because token matching is fragile. (d) `rubric_version` 1→2 + byte-identity (static.sh AC-10) is a confirmed execution-time landmine (fail-safe — editing only one twin trips the test); surface as an explicit plan constraint. (e) Bootstrap: the outcome-acs spec is itself authored under the OLD skill, so it is "legacy" by construction — no deadlock; open dogfooding question is whether it should carry its own `piece_class` + outcome ACs since it IS a behavior-bearing (gate-behavior-changing) piece.

## Recommendation

Ship FR-018 as the four composable paths from Phase B, with the following refinements folded in from the two CONTESTED verdicts. The refinements do NOT change scope (still 5 ACs, DU-4 deferred); they (a) relocate the "ambiguous" definition off the wrong module, (b) single-source the token glossary, and (c) close the self-attestation hole with an explicit, authoring-time invariant.

**Data model (DU-1, refined).** Inline `[outcome]`/`[mechanism]` bracket tag on the `AC-N:` line (orthogonal to `[machine:]`/`[judgment:]`; AC-N ID untouched ⇒ ID-addressable). Frontmatter keys `piece_class: behavior-bearing|non-behavioral` + `behavior_rationale:`. PRESENCE of `piece_class:` is the legacy-vs-new discriminator — but this only holds if the spec skill **ALWAYS writes `piece_class` on every new spec** (ambiguity resolved to `behavior-bearing` AT AUTHORING). Absent ⇒ legacy, never retro-failed; never-absent-on-new ⇒ no ambiguous-reads-as-exempt hole (folds risk-b). Drift/amend must never back-fill `piece_class` into legacy specs (folds backward-compat residual).

**Single source of truth (folds architecture-integrity c+d).** Introduce one new reference doc, `reference/behavior-classification.md`, that (1) defines behavior-bearing vs non-behavioral at **piece granularity with actual criteria** (NOT borrowed from the phase-level `doctrine.md` L179 TDD default), and (2) owns the canonical `[outcome]`/`[mechanism]` + `piece_class:` token glossary. It is cited by `templates/spec.md`, both qa-spec files, and `brainstorm-procedure.md`. `doctrine.md` L179 stays the phase-level TDD-track default, unmodified — no cross-layer elevation.

**Elicitation (DU-2).** New always-run mandatory block in `reference/brainstorm-procedure.md` (C-2-style, depth-independent PRIMARY hop) cited from `skills/spec/SKILL.md` Phase 2; extend the `user-intent` lens row QUESTION (table stays 5 rows); brainstorm zero-answer sign-off gate; auto-skip when `piece_class: non-behavioral`.

**Enforcement (DU-3).** Criterion #17, phrased against the named tokens defined in `reference/behavior-classification.md`, as the 3-state predicate (non-behavioral + rationale ⇒ exempt; behavior-bearing / ambiguous-default ⇒ require ≥1 outcome AC; absent `piece_class` ⇒ skip). Edited byte-identically into both qa-spec twins; `rubric_version` 1→2; wired into Focused re-review (delta-scoped), out of scope in Focused-charter mode. The exact-literal tag-matching policy and the self-attestation-vs-cross-check decision are the two open design points (VOQ-3, VOQ-1).

**Scope (DU-4).** DEFER ALL metrics/gate work. This piece's SC-010 obligation = ID-addressable outcome ACs, delivered by DU-1. Oracle-quality grading is explicitly layered onto the downstream FR-020 ground-truth gate (VOQ-4).

## Validated Open Questions

These survived adversarial review unresolved and are the genuine decisions for brainstorm to resolve. Each cites its originating verdict.

**VOQ-1 — Behavior-classification definition + anti-mislabel mechanism.** (From `architecture-integrity` d, `risk` a+b.) Confirm: (1) introduce `reference/behavior-classification.md` defining behavior-bearing vs non-behavioral at PIECE granularity with concrete criteria (not the phase-level doctrine.md L179 term)? (2) Close the self-attestation hole — option (i) a downstream cross-check binding `piece_class: non-behavioral` to the plan-time TDD/Implement track choice and flagging divergence as must-fix, OR option (ii) explicitly scope-acknowledge self-attestation-with-audit-trail and rely on downstream FR-020/ground-truth to catch mislabel escapes? (3) Confirm the spec skill ALWAYS writes `piece_class` on new specs (so absent ⇒ legacy holds with no ambiguous-reads-as-exempt gap).

**VOQ-2 — Token-glossary single source.** (From `architecture-integrity` c.) Confirm `reference/behavior-classification.md` is the single owner of the `[outcome]`/`[mechanism]` + `piece_class:` token glossary, cited by `templates/spec.md` + both qa-spec files + `brainstorm-procedure.md` — preventing silent token drift given #17 matches named tokens. (If VOQ-1(1) lands the same doc, VOQ-2 confirms its glossary-ownership scope.)

**VOQ-3 — #17 tag-matching robustness.** (From `risk` c.) Decide the exact tag-matching policy for #17: case-sensitivity and exact-literal vs loose matching. Exact-literal is fail-safe (a mis-spelled `[Outcome]` false-fires) and mirrors criterion 12's precedent; loose matching risks fail-open false-passes. Specify the chosen rule so #17 is unambiguous.

**VOQ-4 — Vacuous-outcome-AC quality gap.** (From `user-intent` soft residual.) Confirm that oracle-quality grading (distinguishing a real result-property oracle from a vacuous "must never crash") is explicitly OUT OF SCOPE for this piece and layered onto the downstream FR-020 ground-truth gate — and that the spec records this layering so a reviewer doesn't expect #17 to grade oracle content.

**VOQ-5 — Dogfooding: does THIS spec carry its own `piece_class` + outcome ACs?** (From `risk` e.) The outcome-acs spec is "legacy" by construction (authored under the old skill) so there is no bootstrap deadlock — but it IS a behavior-bearing (gate-behavior-changing) piece. Decide whether it should voluntarily carry its own `piece_class: behavior-bearing` + outcome ACs as a dogfooding demonstration, or stay legacy-exempt.

## Answered by Investigation

Dimensions deliberation resolved or confirmed N/A — brainstorm need not re-ask these.

- **Data-model representation (DU-1) — RESOLVED.** Inline bracket tag on the `AC-N:` line + frontmatter `piece_class:`/`behavior_rationale:` keys; AC-N ID untouched (ID-addressable). Subsection, prose-in-tag, charter_snapshot-date, and redundant version-marker paths eliminated with concrete blockers.
- **Legacy backward-compat discriminator — RESOLVED.** PRESENCE of `piece_class:` (absent ⇒ legacy, never retro-failed). `backward-compat` lens confirmed airtight (charter-drift rewrites only `charter_snapshot`; #17 out of scope in Focused-charter mode; rubric bump asserts presence-not-value). The ambiguous-reads-as-exempt edge is handled by the always-write-on-new invariant (now VOQ-1(3) for confirmation, not re-derivation).
- **Elicitation mechanism (DU-2) — RESOLVED.** Always-run mandatory block + user-intent lens-row extension (5-row table preserved). Lens-only, 6th-lens, conversing-lens, step-7-only, and new-taxonomy paths eliminated with concrete blockers.
- **qa-spec enforcement shape (DU-3) — RESOLVED.** Criterion #17 as a 3-state named-token predicate, byte-identical across both twins, `rubric_version` 1→2, delta-scoped Focused-mode wiring. Free-text-judgment, date/version-discriminator, and re-derive-outside-delta paths eliminated.
- **Metrics / gate scope (DU-4) — RESOLVED (defer).** All metrics counts, spec-gate predicate change, and SC-010 measurement hooks deferred to the outcome campaign. Spec-gate predicate change is NON-VIABLE under ADR-2 + gate-scaling.md#spec-gate (conjunct (i)∧(ii) only); #17 rides existing "QA clean" conjunct (i). This piece's SC-010 obligation = ID-addressable outcome ACs (DU-1).
- **Web/external unknowns — N/A.** Phase A confirmed no genuine web unknowns; internal doc-as-code convention piece.
- **Enforcement-halves redundancy — RESOLVED (non-redundant).** i-D brainstorm = INPUT gate at sign-off (depth-independent); #17 = OUTPUT gate at QA. Deleting either drops a distinct AC (Phase C seam 3, confirmed by `scope/simplicity` HOLDS).
- **Version-bump level — RESOLVED.** MINOR (5.16.0 → 5.17.0); `rubric_version` 1→2 asserts presence-not-value, breaks no pin (`backward-compat` HOLDS).
- **`behavior_rationale:` key redundancy — CARRIED (soft, non-blocking).** `scope/simplicity` soft-noted the dedicated key may duplicate the existing C-2 N/A-rationale surfacing channel; confirm during plan/authoring that it is not redundant. Not a brainstorm blocker.
- **Implementation-fidelity carries (non-blocking, for the plan):** (1) the spec skill authors `piece_class` ONLY on greenfield Phase 3 — drift/amend must NOT back-fill it into legacy specs; (2) `rubric_version` 1→2 + byte-identity (`tests/e2e/lib/static.sh` AC-10) is a confirmed lockstep landmine — both qa-spec twins must be edited identically in the same change; surface as an explicit plan constraint.
