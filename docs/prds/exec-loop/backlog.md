# exec-loop PRD Backlog

Deferred work items scoped to this PRD. Cross-PRD learnings live at `docs/improvement-backlog.md`.
Items here are surfaced during spec brainstorm for each piece and either incorporated, deferred with rationale, or marked obsolete.

---

## Open Questions deferred from PRD creation (2026-06-06)

These were flagged in the PRD's Open Questions section and should be resolved during the relevant piece's spec brainstorm:

- **research.md schema versioning** — free-form markdown with frontmatter vs. versioned schema. Resolve during `research-phase` spec.
- **Flywheel recurrence threshold** — exactly 2 or `.spec-flow.yaml` configurable `flywheel_threshold` key. Resolve during `learn-flywheel` spec. Recommendation: default 2, configurable.
- **decisions.md vs learnings.md** — separate file preferred for clarity (operator reviews decisions before merge, separate from post-mortem learnings). Confirm during `exec-self-resolve` spec.
- **Context budget ceiling** — 80K tokens starting point, configurable? Confirm during `exec-loop` spec.
- **Loop driver delivery** — `loop-driver.md` is a docs/paste-to-use artifact showing how to chain execute calls across planned pieces. Not a new implementation piece. Confirm during `exec-loop` spec that no skill wrapper is needed for initial delivery.
