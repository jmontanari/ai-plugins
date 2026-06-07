# exec-ready PRD Backlog

Deferred work items scoped to this PRD. Cross-PRD learnings live at `docs/improvement-backlog.md`.
Items here are surfaced during spec brainstorm for each piece and either incorporated, deferred with rationale, or marked obsolete.

---

## Open Questions deferred to piece spec brainstorm (2026-06-06)

These are the PRD's Open Questions; resolve each during the relevant piece's spec:

- **Plugin-registry path** — `~/.claude/spec-flow/patterns.yaml` is the proposal; confirm path and update-stability (must survive plugin reinstall, must not collide) during `flywheel` spec.
- **Pattern occurrence granularity** — one occurrence per piece where the pattern appeared, or one per reflection finding? Resolve during `flywheel` spec.
- **Test-data-upfront for non-deterministic phases** — confirm the `[SPIKE]`-then-record fallback is sufficient for integration/real-external phases during `test-data-up` spec.
- **`.spec-flow.yaml` keys** — finalize `flywheel_threshold`, `circuit_breaker.docs`, and `model_policy` shape during `sonnet-coord` / `flywheel` specs.

---

## Deferred from the 2026-06-06 re-evaluation (cut/deferred from the prior exec-loop PRD)

The original `exec-loop` PRD was re-scoped after a capability audit + fresh Boris research. These items were dropped from scope and parked here:

- **Sonnet context-budget / oversized-file routing / summarizer (old FR-006)** — DEFERRED. The original justification ("Sonnet's small window") was superseded by the Opus-1M driver, and the real goal became file-based statelessness (now FR-004/NFR-002). Revisit only if dense plans strain context at the *plan* stage, or if a token ceiling proves necessary in practice. Not a piece today.
- **Execute self-resolve + `decisions.md` (old FR-004)** — CUT. Conflicts with the synchronous-discovery doctrine; an execute-time ambiguity is a plan-incompleteness signal routed to Step 6c or a `[SPIKE]`, not a silent in-execute decision log. Captured as NN-P-002.
- **`loop-driver.md` multi-piece driver + DONE/BLOCKED vocabulary (old FR-005 scraps)** — DROPPED. The execute loop, manifest→merged, and journal resume already ship; only the configurable circuit-breaker survived (folded into `sonnet-coord`). Autonomous multi-piece queue is an explicit non-goal.
- **Cross-machine plugin-pattern correlation** — NON-GOAL. The `~/` plugin registry is per-machine; cross-machine correlation needs a shared remote backend (auth/privacy/weight). Revisit only if multi-machine plugin learning becomes a real need.
