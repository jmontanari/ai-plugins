# Learnings — pi-014-integ-tests (spec-flow 4.12.0)

Integration tests as a first-class pipeline primitive, shipped as prose/agent-instruction edits to spec-flow itself (12 phases + 2 Area-K amendment phases, all Implement-track, structural-grep oracles).

## Patterns that worked well

- **Orchestrator independent oracle re-runs were load-bearing, not ceremonial.** Re-running each phase's `[Verify]` greps myself caught real gaps the implementers' self-reported oracles missed: Phase 1 (the doctrine had `Double-loop` capitalized but the AC grep wanted lowercase `double-loop` — case-sensitive miss) and Phase 10 (a stale `8th member` the plan's narrow T-2 pattern never swept). Both would have shipped silently otherwise.
- **The Opus-QA skip predicate was accurate for a prose piece.** Dispatching Opus only on the orchestration `execute/SKILL.md` phases (5, 6, 10) and skipping the pure agent/doc phases caught every substantive per-phase must-fix (Phase 5 NFR-INT-02 violation, Phase 6 closure-hash schema gap) without wasting Opus on low-risk prose.
- **Dog-fooding the new reviewer on its own piece validated the no-integration path.** `review-board-integration` correctly returned "no integration paths — piece declares none, confirmed," proving the two-axis method degrades cleanly rather than false-flagging a prose piece.
- **Verify-Full's semantic pass caught factual errors greps can't.** Phase 11's grep oracle was green, but Verify-Full found 3 real factual errors in the new `review-board.md` (default lens count). Structural oracles verify presence; semantic verify catches wrongness.

## Issues QA / the board caught

- **The deepest defect was cross-phase and survived all 12 per-phase gates.** The M1/M3 registry hash-origin contradiction (skeleton_sha256 plan-authored in §1e vs runtime-recorded in M3) + missing `registered_in_phase` was invisible to per-phase QA (each phase scoped to its own files; the contradiction spanned Phase 5's registry shape and Phase 6's usage). Only the Final Review edge-case reviewer, holding the whole diff, caught it. → directly motivated **Area K's cross-phase schema-consistency oracle**.
- **Anti-drift sweep patterns don't auto-expand to superseded strings.** Two `8th member` stale ordinals slipped past Phase 12's sweep (its pattern omitted `8th member`). → motivated **Area K's superseded-ordinal sweep rule**.
- **A phase's declared scope can be narrower than its own binding sweep.** Phase 11 touched a 7th file the phase-level sweep covered but the declared scope didn't. → motivated **Area K's Verify-scope-union rule**.
- **A late insertion silently bypassed its own mandatory gate.** The Area-K Step 5.7 union gate was inserted between Step 5 and Step 6, but Step 5's skip-paths still routed "directly to Step 6" — bypassing it on the common clean-Build path. Caught by the amendment-re-entry blind reviewer. A reminder that inserting a step requires re-pointing every inbound route.

## Recommendations for future specs

- **For pieces that thread one schema across many phases, plan a cross-phase consistency check up front** — don't rely on per-phase QA to catch cross-phase contradictions (now enforced by Area K / FR-PROC-01).
- **A primitive shipped as prose is shipped un-exercised.** pi-014 declared no integrations of its own, so the M1–M4 machinery + M3 anti-cheat gate landed without ever running on a real wired path. The first real integration-bearing piece is the true dog-food and will surface the runtime gaps (per-helper closure hashing, polyglot path-dir conventions) the security/edge-case reviewers flagged.
- **Operator-folded scope (Area K) via spec-amend is viable but heavy.** Folding the reflection process-improvements into pi-014 (rather than deferring/forking) re-opened the piece for a full spec-amend → plan-amend → 2 amendment phases → board-re-run cycle. It worked and dog-fooded the very rules it added, but a fork would have kept pi-014's scope cleaner. Weigh immediacy vs scope discipline explicitly.
