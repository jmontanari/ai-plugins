# Deliberation — artifact-budgets (PRD exec-ready)

## Investigation Summary

**Resolved depth: lite.** Single-cluster piece. Phase C (cross-cluster synthesis) was SKIPPED — one cluster only, so Integration Check records single-cluster coherence instead of cross-cluster composition.

The piece introduces artifact size budgets as the inverse of FR-002's concreteness floor: the floor prevents under-specification; budgets prevent over-specification (bloat). Investigation confirmed the design tracks FR-014's four ACs one-to-one, reuses the existing concreteness-floor enforcement pattern (#28–#31), and derives budget numbers mechanically from observed corpus percentiles rather than inventing them. Empirical line counts (p75 / observed-max) on disk: spec 302/467; plan total 748/885; plan per-phase 91/197; research 192/287; learnings 30/39. Two-tier model: soft p75 (advisory) + hard observed-max (enforced). Five artifact classes defined; must-fix enforcement applies only to the three with a qa gate (spec, deliberation, plan); research.md and learnings.md are documented-only. Target version 5.12.0.

## Viability Analysis

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| New SSOT `reference/artifact-budgets.md` + additive nested `artifact_budgets:` in `.spec-flow.yaml` | VIABLE | Mirrors existing SSOT-+-config-override pattern; additive nested key is backward-compatible (CR-005/007/008/009; charter-tools md/yaml/json/bash) | Yes — reuses config-override resolution already in orchestrator | — |
| qa-spec criterion #16 + qa-plan criterion #32, must-fix with split/condense guidance | VIABLE | ADD-only must-fix, keystroke flow untouched (NN-P-001); enforcement mirrors concreteness #28–#31 | Yes — extends existing qa criteria block | — |
| Orchestrator skill resolves overrides + computes real line count (`wc -l`) and interpolates "artifact is N lines, budget M"; agent judges over/under | VIABLE | Orchestrator already has shell + resolves config; line-count is a `wc -l` call, no new dependency. Closes R-1 (see Adversarial Review) | Yes — extends existing resolve-and-interpolate step | — |
| Two-tier soft-p75 (advisory) / hard-max (must-fix) | VIABLE | Both numbers derived mechanically from corpus data — simplicity win, not added complexity | Yes — derives from already-collected metrics | — |
| Passive per-piece metrics metadata (3a) | VIABLE | No aggregator change; records budget outcome as metadata only | Yes — extends per-piece metrics.yaml | — |
| Irreducible overage → qa-prd ≤7-AC piece-split, no waiver | VIABLE | No new waiver mechanism; routes to existing piece-split decision | Yes — reuses qa-prd split path | — |

## Integration Check

**Single-cluster coherence (Phase C no-op).** All six paths belong to one cluster — they compose without cross-cluster conflict. The SSOT defines numbers; the orchestrator resolves overrides and computes line counts; the qa criteria consume the interpolated "N lines vs budget M" and judge; metrics records the outcome; qa-prd handles the irreducible-overage escape. Per-phase and total plan budgets are orthogonal (one bloated phase vs sum-over-total) and coexist without interference — both are named in AC2 and both retained. The soft/hard tiers layer cleanly: soft is advisory text, hard is the must-fix trigger; they share one derivation (corpus percentiles) and one interpolation path. No internal contradiction; the design is coherent as a single unit.

## Adversarial Review

**LENS scope/simplicity — HOLDS.** Tracks FR-014's 4 ACs one-to-one. No speculative scope (no waiver, no new script, no new gate). Per-phase AND total plan budgets are genuinely orthogonal and both belong. All 5 classes defined but enforcement is must-fix only on the 3 with a qa gate; research.md + learnings.md documented-only. Two-tier derivation is a simplicity win. Watch-flag (not a contest): deliberation.md is the one genuinely unvalidated number → carried as VOQ-2 + R-3.

**LENS risk — CONTESTED (three findings, all folded into the Recommendation):**

- **R-1 (load-bearing) — inverted failure mode.** If the agent counts lines from interpolated text with no shell, the largest artifact is the one most likely truncated during interpolation → reads SHORTER → silently passes the budget gate. The failure inverts the intent: it fails to fire on the worst offenders. (The concreteness-floor analog is immune because truncation makes it *more* likely to flag a missing element.) **Folded:** the orchestrator skill — which has shell and already resolves config — computes the real count via `wc -l` on the artifact file and interpolates "artifact is N lines, budget M". The agent judges over/under and writes split/condense guidance; it never eyeballs possibly-truncated text. **Resolved → Answered by Investigation.**

- **R-2 (load-bearing) — gate round-trip antagonizes SC-008.** A must-fix that fires on a legitimately-large-but-acceptable artifact adds an operator round-trip, working against SC-008 (median operator interactions per clean piece down ≥50%). **Folded:** only the HARD ceiling (observed-max) is must-fix; the soft p75 is advisory/observe-only. Legitimately-large-but-under-ceiling artifacts do not trigger a must-fix. **Resolved → Answered by Investigation.**

- **R-3 (accept + flag) — deliberation.md is a zero-sample guess.** Landing a guessed number as must-fix is the highest-risk combo. **Folded:** ship deliberation.md's budget as passive/observe-only (recorded, non-blocking) for one cycle; re-bind to must-fix once real deliberation.md samples exist on disk. **Residual decision → VOQ-2** (operator confirms observe-only-first vs must-fix-now).

## Recommendation

Ship artifact size budgets as the inverse of the FR-002 concreteness floor, version 5.12.0, with all three risk mitigations folded in:

1. **SSOT + config:** new `reference/artifact-budgets.md`; additive nested `artifact_budgets:` overrides in `.spec-flow.yaml`. Budget numbers = soft p75 + modest headroom (advisory) and observed-max (hard ceiling), derived mechanically from the corpus.
2. **Orchestrator computes line counts (closes R-1):** the orchestrator skill resolves overrides AND runs `wc -l` on each artifact, interpolating "artifact is N lines, budget M" into the qa prompt. The agent judges over/under and authors split/condense guidance — never counts from possibly-truncated interpolated text. This stays within CR-008 thin-orchestrator (a `wc -l` call + interpolation, same shape as existing config resolution) — confirm via VOQ-4.
3. **Hard-ceiling-only is must-fix (closes R-2):** qa-spec #16 and qa-plan #32 fire as must-fix ONLY when over the hard (observed-max) ceiling. Soft p75 is advisory/observe-only and never triggers a round-trip.
4. **deliberation.md observe-only-first (closes R-3):** deliberation.md's budget ships passive/observe-only for one cycle (recorded, non-blocking), re-binding to must-fix once real samples land. deliberation.md budget anchored by analogy to research.md (~192 lines / 7 sections) until then.
5. **Plan budgets:** keep BOTH per-phase and total (orthogonal, both in AC2).
6. **Metrics:** passive per-piece metadata (3a), no aggregator change.
7. **Irreducible overage:** route to qa-prd ≤7-AC piece-split — no waiver.
8. **spec-preresearch grandfather:** the already-merged 885-line plan is the baseline; the deliberation.md budget binds FORWARD on future producers at the qa-plan gate; AC3 reframed accordingly — confirm via VOQ-1.

Charter: NN-C-003, NN-C-008, NN-P-001 (keystroke untouched, ADD-only must-fix), NN-P-005; CR-005/007/008/009; charter-tools md/yaml/json/bash.

## Validated Open Questions

- **VOQ-1 — spec-preresearch AC3 reframing.** Accept forward-binding (future producers at qa-plan gate) + grandfather of the already-merged 885-line spec-preresearch plan as baseline, with AC3 reframed to match? (vs retroactively flagging the merged plan.)
- **VOQ-2 — deliberation.md enforcement timing.** Ship deliberation.md's budget observe-only for one cycle then re-bind to must-fix once real samples exist (R-3 mitigation), OR bind must-fix now off the research.md-analogy number? Observe-only-first is recommended.
- **VOQ-3 — metrics depth.** Passive per-piece metadata only (3a, recommended), OR add a budget-outcome aggregator across pieces (3b)?
- **VOQ-4 — orchestrator line-count placement.** Confirm the orchestrator computing `wc -l` and interpolating "N lines vs budget M" (R-1 mitigation) is acceptable under CR-008 thin-orchestrator — i.e., line-count-compute is config-resolution-adjacent, not business logic that belongs in an agent.

## Answered by Investigation

- **R-1 inverted-failure (truncation hides bloat)** — RESOLVED. Orchestrator computes `wc -l`; agent judges from a trusted count, not interpolated text.
- **R-2 SC-008 round-trip antagonism** — RESOLVED. Only the hard observed-max ceiling is must-fix; soft p75 is advisory-only.
- **Per-phase vs total plan budget** — RESOLVED (N/A as conflict). Orthogonal axes, both retained per AC2.
- **Budget-number provenance** — RESOLVED for spec/plan/research/learnings. Derived from corpus p75/observed-max, not invented. deliberation.md alone lacks samples → tracked as VOQ-2/R-3.
- **Waiver mechanism** — RESOLVED (N/A). No waiver; irreducible overage routes to qa-prd piece-split.
- **Cross-cluster integration** — N/A. Single cluster; coherence recorded in Integration Check.
- **Charter conformance** — RESOLVED. ADD-only must-fix preserves NN-P-001 keystroke flow; tooling stays md/yaml/json/bash (charter-tools).
